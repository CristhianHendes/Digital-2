#include <stdio.h>
#include <string.h>
#include <irq.h>
#include <uart.h>
#include <console.h>
#include <generated/csr.h>
void my_busy_wait(unsigned int ms)
{
	timer0_en_write(0);
	timer0_reload_write(0);
	timer0_load_write(CONFIG_CLOCK_FREQUENCY/1000*ms);
	timer0_en_write(1);
	timer0_update_value_write(1);
	while(timer0_value_read()) timer0_update_value_write(1);
}

static int str_to_int(const char *buf)
{
    int result = 0;
    int sign = 1;

    if(*buf == '-') {
        sign = -1;
        buf++;
    } else if(*buf == '+') {
        buf++;
    }
    while(*buf >= '0' && *buf <= '9') {
        result = result * 10 + (*buf - '0');
        buf++;
    }
    return sign * result;
}

static int read_int(void)
{
    char buf[16];
    int i = 0;
    char c;

    while(1) {
        c = uart_read();
        if(c == '\r' || c == '\n') {
            buf[i] = '\0';
            printf("\n");
            break;
        }
        if(c == 8 || c == 127) {   /* backspace */
            if(i > 0) {
                i--;
                printf("\b \b");
            }
            continue;
        }
        if(i < 15) {
            buf[i++] = c;
            printf("%c", c);        /* eco */
        }
    }
    return str_to_int(buf);
}

static char read_op(void)
{
    char c;

    while(1) {
        c = uart_read();
        if(c == '+' || c == '-' || c == '*' || c == '/') {
            printf("%c\n", c);
            return c;
        }
        /* ignora cualquier otro caracter (espacios, saltos de linea, etc.) */
    }
}

int main(void)
{
	int a, b, result;
	char op;

	printf("Calculadora con perifericos HW (+, -, *, /)\n");
	while(1) {
        printf("Ingrese A: ");
        a = read_int();
        printf("Ingrese operacion (+,-,*,/): ");
        op = read_op();
        printf("Ingrese B: ");
        b = read_int();

        switch(op) {
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
            while(mult0_done_read() == 0);
            result = mult0_pp_read();
            break;
        case '/':
            if(b == 0) {
                printf("Error: division por cero\n\n");
                continue;
            }
            div0__A_write(a);
            div0__B_write(b);
            div0_init_write(1);
            div0_init_write(0);
            while(div0_done_read() == 0);
            result = div0__q_read();
            break;
        default:
            result = 0;
            break;
        }

        printf("A = %d, B = %d, A %c B = %d\n\n", a, b, op, result);
	}
	return 0;
}


