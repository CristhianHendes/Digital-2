// This file is Copyright (c) 2017 Florent Kermarrec <florent@enjoy-digital.fr>

// SPDX-License-Identifier: BSD-Source-Code

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include <libbase/console.h>
#include <libbase/crc.h>

#include "readline.h"
#include "helpers.h"
//#include "init.h"

extern unsigned int _ftext, _edata_rom;

#define NUMBER_OF_BYTES_ON_A_LINE 16
void dump_bytes(unsigned int *ptr, int count, unsigned long addr)
{
	uint32_t *dptr = (uint32_t *)ptr;
	char data[NUMBER_OF_BYTES_ON_A_LINE];
	int line_bytes = 0, i = 0;


	fputs("Memory dump:", stdout);
	while (count > 0) {
		line_bytes =
			(count > NUMBER_OF_BYTES_ON_A_LINE)?
				NUMBER_OF_BYTES_ON_A_LINE : count;
		for (i = 0; i < line_bytes; i+=4){
			*((uint32_t*)&data[i]) = *(dptr++);
		}


		printf("\n0x%08lx  ", addr);
		for (i = 0; i < line_bytes; i++)
			printf("%02x ", (unsigned char)data[i]);

		for (; i < NUMBER_OF_BYTES_ON_A_LINE; i++)
			printf("   ");

		printf(" ");

		for (i = 0; i<line_bytes; i++) {
			if ((data[i] < 0x20) || (data[i] > 0x7e))
				printf(".");
			else
				printf("%c", data[i]);
		}

		for (; i < NUMBER_OF_BYTES_ON_A_LINE; i++)
			printf(" ");

		count -= line_bytes;
		addr += line_bytes;
	}
	printf("\n");
}

