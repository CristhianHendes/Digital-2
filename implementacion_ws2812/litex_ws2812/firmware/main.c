#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <irq.h>
#include <uart.h>
#include <generated/csr.h>

#include "img_corazon_grande.h"
#include "img_corazon_chico.h"

// Cambiar a 0 para modo estatico (solo el corazon grande, fijo).
#ifndef WS2812_ANIMATE
#define WS2812_ANIMATE 1
#endif

#define WS2812_N_LEDS 64  // 8x8

static void my_busy_wait(unsigned int ms)
{
    timer0_en_write(0);
    timer0_reload_write(0);
    timer0_load_write(CONFIG_CLOCK_FREQUENCY/1000*ms);
    timer0_en_write(1);
    timer0_update_value_write(1);
    while(timer0_value_read()) timer0_update_value_write(1);
}

// Manda por DMA la imagen (ya construida en tiempo de compilacion en
// img_corazon_grande.h / img_corazon_chico.h) hacia el periferico
// WS2812. Siguiendo el mismo esquema de la seccion 3.4.2/3.4.3 del
// libro (DMA parametrizado por base+length): en vez de reconstruir un
// buffer en cada envio, el CPU solo cambia la direccion base del DMA
// para apuntar al arreglo const de la imagen deseada. El periferico
// (ctrl_ws_arr con init=1) ya esta refrescando en loop autonomo, asi
// que en cuanto el DMA termine de escribir, la matriz muestra la
// imagen nueva sin mas intervencion.
static void ws2812_send_frame(const uint32_t *frame)
{
    while (disp0_loader_busy_read()); // espera a que el loader este libre

    // El WishboneDMAReader solo reinicia su FSM en la transicion 0->1
    // de "enable"; si se deja en 1 entre envios, la segunda
    // transferencia (y las siguientes) nunca arrancan.
    disp0_dma_enable_write(0);

    disp0_dma_base_write((uint32_t)(uintptr_t) frame);
    disp0_dma_length_write(WS2812_N_LEDS * sizeof(uint32_t));
    disp0_dma_loop_write(0);
    disp0_dma_enable_write(1);

    disp0_loader_start_write(1);
}

int main(void)
{
    uart_init();

    printf("\nWS2812 8x8 matrix demo (LiteX)\n");

    // rst_cmd en 0: el datapath transmite datos de color normalmente
    // (ver ctrl_ws.v / nota en ws2812_matrix_top_anim.v del proyecto
    // standalone sobre por que este bit no debe quedar en 1 mientras
    // se envian pixeles).
    disp0_rst_cmd_write(0);

    // init=1: arranca el refresco autonomo continuo (equivalente a
    // init_m=1 permanente en el top standalone). El hardware sigue
    // refrescando solo mientras este bit este en 1.
    disp0_init_write(1);

    ws2812_send_frame(img_corazon_grande);

#if WS2812_ANIMATE
    printf("Modo animado: alternando corazon grande/chico.\n");
    while (1) {
        my_busy_wait(500);
        ws2812_send_frame(img_corazon_chico);
        my_busy_wait(500);
        ws2812_send_frame(img_corazon_grande);
    }
#else
    printf("Modo estatico: corazon grande fijo.\n");
    while (1) {
        // El hardware sigue refrescando solo; el CPU no necesita
        // hacer nada mas para mantener la imagen en pantalla.
    }
#endif

    return 0;
}
