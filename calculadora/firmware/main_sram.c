#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <irq.h>
#include <uart.h>
#include <console.h>
#include <generated/csr.h>
#include <libbase/i2c.h>
#include "helpers.h"
#include "sample.h"
#include <stdint.h>


#define slave_addr 0x60
/*
i2c_write 0x60 0x04 1 0x07
i2c_write 0x60 0x05 1 0x2B
i2c_write 0x60 0x07 1 0xFC
i2c_write 0x60 0x0D 1 0x20
i2c_write 0x60 0x14 1 0x01
*/
unsigned char buf[255];
unsigned char buf_w;
//1/60 = 0.016666667
//0.016666667÷128
//0.000130208  
// 0.000130208 / (1/33333333) = 4340

void my_busy_wait(unsigned int ms)
{

	timer0_en_write(0);
	timer0_reload_write(0);
	timer0_load_write(CONFIG_CLOCK_FREQUENCY/1000*ms);
	timer0_en_write(1);
	timer0_update_value_write(1);
	while(timer0_value_read()) timer0_update_value_write(1);
}

/*
  write_ad7606c_reg(0x6F, 0x00);     // read ID Status to enter to register mode 
  write_ad7606c_reg(0x02, 0x18);     // Enable 8 bit serial 
*/
void init_adc(void){
	adc0_rstrb_write(1);
	adc0_spi_tx_data_write(0x0218);
	while( !(adc0_done_tx_read() & 1) );
	adc0_rstrb_write(0);
	adc0_rstrb_write(1);
	adc0_spi_tx_data_write(0x0218);
	while( !(adc0_done_tx_read() & 1) );
 	adc0_rstrb_write(0);
	adc0_sample_counter_write(542);
}

//"i2c_write <slaveaddr7bit> <addr> <addr_size> [<data>, ...]
//bool i2c_write(unsigned char slave_addr, unsigned int addr, const unsigned char *data, unsigned int len, unsigned int addr_size);

void set_power_supply(void){
	buf_w = 0x07;
	i2c_write( slave_addr, 0x04, &buf_w, 1, 1 );
	i2c_read( slave_addr, 0x04, buf, 1, 1, 1);
	dump_bytes((unsigned int *) buf, 1, 1);
	buf_w = 0x2B;
	i2c_write( slave_addr, 0x05, &buf_w, 1, 1 );
	i2c_read( slave_addr, 0x05, buf, 1, 1, 1);
	dump_bytes((unsigned int *) buf, 1, 1);
	buf_w = 0xFC;
	i2c_write( slave_addr, 0x07, &buf_w, 1, 1 );
	i2c_read( slave_addr, 0x07, buf, 1, 1, 1);
	dump_bytes((unsigned int *) buf, 1, 1);
	buf_w = 0x20;
	i2c_write( slave_addr, 0x0D, &buf_w, 1, 1 );
	i2c_read( slave_addr, 0x0D, buf, 1, 1, 1);
	dump_bytes((unsigned int *) buf, 1, 1);
	buf_w = 0x01;
	i2c_write( slave_addr, 0x14, &buf_w, 1, 1 );
	i2c_read( slave_addr, 0x14, buf, 1, 1, 1);
	dump_bytes((unsigned int *) buf, 1, 1);

}

//short voltages [3700];

void write_memory_32(uint32_t address, uint32_t value) {
    *(volatile uint32_t *)address = value;
}


uint32_t read_memory_32(uint32_t address) {
    return *(volatile uint32_t *)address;
}


void read_samples(void){
	int i,j, address;
	uint32_t data;

	adc0_st_capture_write(1);
	adc0_st_capture_write(0);
    while( !(adc0_done_capture_read() & 1 )  )


	adc0_re_b_write(1);
    address = 0;
	for(j=0; j < 2048; j++){
		for(i = 0; i < 8; i ++){
		  adc0_adr_b_write(address);
		  if(i==2){
		    data=adc0_dat_b_read();
			write_memory_32( ( 0x40500000  + j*4 ) , (  data ) );
		  }
		  address ++;
		}
	}
	adc0_re_b_write(0);
	adc0_st_capture_write(1);

	printf("\e[1m !!!Voltage 0 !!!!:\e[0m\n");
	for(i = 0; i < 2048; i ++){

		printf("%d\n",( read_memory_32(0x40500000 + i*4) & 0xFFFF) );
	}	
}

void send_data_to_UDP(void){
	unsigned short i;

/*
# Configure DMA
wb.regs.dma_upload_dma_reader_enable.write(0)
wb.regs.dma_upload_dma_reader_base.write(0x40000000)
wb.regs.dma_upload_dma_reader_length.write(260)
wb.regs.dma_upload_dma_reader_enable.write(1)
wb.regs.dma_upload_dma_reader_enable.write(0)
*/


}


int main(void)
{
	uart_init();
	printf("Running capture demo. \n");
	pwm_enable_write(1);
	pwm_period_write(1024*40);
	set_power_supply();
	init_adc();
	init_adc();
	read_samples();
	send_data_to_UDP();

}



