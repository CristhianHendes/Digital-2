#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <uart.h>
#include <generated/csr.h>

#include "font5x7.h"

// ----------------------------------------------------------------------
// Calculadora con pantalla WS2812 (8x8).
//
// Maquina de estados.
//
//   READ_A -> READ_OP -> READ_B -> COMPUTE -> SHOW_RESULT -> READ_A ...
//
// Mientras se escribe A, el operador y B: cada caracter recibido por
// UART se dibuja de inmediato en la matriz y queda fijo hasta que
// llegue el siguiente caracter (sin timeout). Al terminar B con Enter,
// se calcula el resultado con el core aritmetico correspondiente
// (add0/sub0/mult0/div0, ya vendorizados de calculadora/), se arma el
// texto completo de la expresion (ej. "9+2=11") y se desplaza por la
// pantalla de derecha a izquierda (scroll).
// ----------------------------------------------------------------------

#define WS2812_N_LEDS 64  // 8x8
#define COLOR_ON  0x00FF0000u  // rojo, mismo formato 0x00RRGGBB de las imagenes estaticas
#define COLOR_OFF 0x00000000u

static uint32_t frame_buf[WS2812_N_LEDS];

// El firmware de LiteX no linkea una libc completa (no hay atoi/snprintf
// disponibles, como ya evidenciaba calculadora/firmware/main.c con su
// propio str_to_int) asi que estas conversiones se hacen a mano.
static int str_to_int(const char *buf)
{
    int result = 0;
    int sign = 1;

    if (*buf == '-') {
        sign = -1;
        buf++;
    }
    while (*buf >= '0' && *buf <= '9') {
        result = result * 10 + (*buf - '0');
        buf++;
    }
    return sign * result;
}

// Escribe value en decimal (con signo) en buf, terminado en '\0'.
// Devuelve la cantidad de caracteres escritos (sin contar el '\0').
static int int_to_str(char *buf, int value)
{
    char tmp[12];
    int i = 0, len = 0;
    unsigned int uval;

    if (value < 0) {
        buf[len++] = '-';
        uval = (unsigned int)(-(value + 1)) + 1u; // evita overflow en INT_MIN
    } else {
        uval = (unsigned int)value;
    }

    do {
        tmp[i++] = '0' + (uval % 10);
        uval /= 10;
    } while (uval != 0);

    while (i > 0)
        buf[len++] = tmp[--i];

    buf[len] = '\0';
    return len;
}

static void my_busy_wait(unsigned int ms)
{
    timer0_en_write(0);
    timer0_reload_write(0);
    timer0_load_write(CONFIG_CLOCK_FREQUENCY/1000*ms);
    timer0_en_write(1);
    timer0_update_value_write(1);
    while(timer0_value_read()) timer0_update_value_write(1);
}

// Manda frame_buf por DMA al periferico WS2812 (mismo esquema de
// implementacion_ws2812/litex_ws2812/firmware/main.c: base+length
// apuntando a un buffer ya armado, en vez de escribir LED por LED).
static void ws2812_send_frame(const uint32_t *frame)
{
    while (disp0_loader_busy_read());

    // El WishboneDMAReader solo reinicia su FSM en la transicion 0->1
    // de "enable"; hay que forzarlo a 0 antes de cada envio.
    disp0_dma_enable_write(0);

    disp0_dma_base_write((uint32_t)(uintptr_t) frame);
    disp0_dma_length_write(WS2812_N_LEDS * sizeof(uint32_t));
    disp0_dma_loop_write(0);
    disp0_dma_enable_write(1);

    disp0_loader_start_write(1);
}

// ----------------------------------------------------------------------
// Render de un solo caracter (5x7) centrado en la matriz 8x8: columnas
// 1-5 y filas 0-6 (columna 0, columna 6-7 y fila 7 quedan apagadas,
// como margen).
// ----------------------------------------------------------------------
static void render_char(char ch)
{
    const font_glyph_t *g = font_lookup(ch);

    for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
            int on = 0;
            if (row < FONT_ROWS && col >= 1 && col <= FONT_COLS) {
                on = (g->col[col - 1] >> row) & 1;
            }
            frame_buf[row * 8 + col] = on ? COLOR_ON : COLOR_OFF;
        }
    }
    ws2812_send_frame(frame_buf);
}

static void render_blank(void)
{
    for (int i = 0; i < WS2812_N_LEDS; i++)
        frame_buf[i] = COLOR_OFF;
    ws2812_send_frame(frame_buf);
}

// ----------------------------------------------------------------------
// Canvas ancho para el scroll de la expresion completa: una columna
// (8 bits, bit0=fila superior..bit6=fila inferior) por cada columna de
// cada caracter, con 1 columna de espacio entre caracteres.
// ----------------------------------------------------------------------
#define GLYPH_STRIDE   (FONT_COLS + 1)   // 5 columnas de glifo + 1 de espacio
#define MAX_EXPR_CHARS 40
#define MAX_CANVAS_COLS (MAX_EXPR_CHARS * GLYPH_STRIDE)

static uint8_t canvas[MAX_CANVAS_COLS];
static int     canvas_len;

static void canvas_build(const char *text)
{
    canvas_len = 0;
    for (const char *p = text; *p != '\0' && canvas_len + GLYPH_STRIDE <= MAX_CANVAS_COLS; p++) {
        const font_glyph_t *g = font_lookup(*p);
        for (int c = 0; c < FONT_COLS; c++)
            canvas[canvas_len++] = g->col[c];
        canvas[canvas_len++] = 0x00; // columna de espacio entre caracteres
    }
}

// Dibuja las 8 columnas de pantalla [offset, offset+7] tomadas del
// canvas (fuera de rango = apagado), y las manda por DMA.
static void render_canvas_window(int offset)
{
    for (int j = 0; j < 8; j++) {
        int c = offset + j;
        uint8_t colbits = (c >= 0 && c < canvas_len) ? canvas[c] : 0x00;
        for (int row = 0; row < 8; row++) {
            int on = (row < FONT_ROWS) ? ((colbits >> row) & 1) : 0;
            frame_buf[row * 8 + j] = on ? COLOR_ON : COLOR_OFF;
        }
    }
    ws2812_send_frame(frame_buf);
}

// Desplaza el canvas completo de derecha a izquierda: el texto entra
// por la columna derecha de la pantalla y sale por la izquierda.
static void scroll_canvas(unsigned int ms_per_step)
{
    for (int offset = -8; offset <= canvas_len; offset++) {
        render_canvas_window(offset);
        my_busy_wait(ms_per_step);
    }
}

// ----------------------------------------------------------------------
// Lectura de un operando por UART, renderizando cada caracter (incluido
// el signo '-' inicial) en la matriz apenas llega, y soportando
// backspace (re-renderiza el caracter anterior, o pantalla en blanco si
// el buffer queda vacio).
// ----------------------------------------------------------------------
static void read_number(char *buf, int maxlen)
{
    int i = 0;

    while (1) {
        char c = uart_read();

        if (c == '\r' || c == '\n') {
            buf[i] = '\0';
            printf("\n");
            return;
        }
        if (c == 8 || c == 127) { // backspace
            if (i > 0) {
                i--;
                printf("\b \b");
                if (i > 0)
                    render_char(buf[i - 1]);
                else
                    render_blank();
            }
            continue;
        }
        if ((c == '-' && i == 0) || (c >= '0' && c <= '9')) {
            if (i < maxlen - 1) {
                buf[i++] = c;
                printf("%c", c);
                render_char(c);
            }
        }
        // cualquier otro caracter se ignora
    }
}

static char read_op(void)
{
    while (1) {
        char c = uart_read();
        if (c == '+' || c == '-' || c == '*' || c == '/') {
            printf("%c\n", c);
            render_char(c);
            return c;
        }
    }
}

int main(void)
{
    char buf_a[16], buf_b[16];
    char expr[48];
    int a, b, result;
    char op;

    uart_init();

    printf("\nCalculadora con pantalla WS2812 (LiteX)\n");

    disp0_rst_cmd_write(0);
    disp0_init_write(1); // arranca el refresco autonomo continuo de la matriz
    render_blank();

    while (1) {
        printf("Ingrese A: ");
        read_number(buf_a, sizeof(buf_a));
        a = str_to_int(buf_a);

        printf("Ingrese operacion (+,-,*,/): ");
        op = read_op();

        printf("Ingrese B: ");
        read_number(buf_b, sizeof(buf_b));
        b = str_to_int(buf_b);

        switch (op) {
        case '+':
            add0__A_write(a);
            add0__B_write(b);
            result = add0_sum_read();
            break;
        case '-':
            sub0__A_write(a);
            sub0__B_write(b);
            result = sub0_diff_read();
            break;
        case '*':
            mult0__A_write(a);
            mult0__B_write(b);
            mult0_init_write(1);
            mult0_init_write(0);
            while (mult0_done_read() == 0);
            result = mult0_pp_read();
            break;
        case '/':
            if (b == 0) {
                printf("Error: division por cero\n\n");
                render_blank();
                continue;
            }
            div0__A_write(a);
            div0__B_write(b);
            div0_init_write(1);
            div0_init_write(0);
            while (div0_done_read() == 0);
            result = div0__q_read();
            break;
        default:
            result = 0;
            break;
        }

        printf("A = %d, B = %d, A %c B = %d\n\n", a, b, op, result);

        {
            int len = 0;
            len += int_to_str(expr + len, a);
            expr[len++] = op;
            len += int_to_str(expr + len, b);
            expr[len++] = '=';
            len += int_to_str(expr + len, result);
            expr[len] = '\0';
        }
        canvas_build(expr);
        scroll_canvas(120);
        render_blank();
    }

    return 0;
}
