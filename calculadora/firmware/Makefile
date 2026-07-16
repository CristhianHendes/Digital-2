BUILD_DIR=../build/colorlight_i5/
SERIAL?=/dev/ttyACM0

COMMONFLAGS += -DUART_POLLING 

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak
OBJECTS= crt0.o isr.o helpers.o main.o uart.o


define compile
$(CC) -c $(CFLAGS) $(1) $< -o $@
endef



all: firmware.bin
# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)
%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@
	@if [ -d /srv/tftp ]; then \
		cp firmware.bin /srv/tftp/boot.bin; \
	else \
		echo "Aviso: /srv/tftp no existe, se omite la copia de boot.bin"; \
	fi
firmware.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-Wl,--start-group $(LIBS:lib%=-l%) -Wl,--end-group
	chmod -x $@

#	@riscv64-unknown-elf-objdump  -h -S $< > firmware.lst
main.o: main.c
	$(compile)
crt0.o: $(CPU_DIRECTORY)/crt0.S
	$(assemble)
%.o: %.c
	$(compile)
%.o: %.S
	$(assemble)
litex_term: firmware.bin
	@ls ${SERIAL} || (echo "\n\nNo se encuentra ${SERIAL} conectado, verifique conexión o cambie el valor de SERIAL=${SERIAL} por un puerto serial existente\n\n"; exit 123;)
	litex_term ${SERIAL} --kernel firmware.bin
clean:
	$(RM) $(OBJECTS) $(OBJECTS:.o=.d) firmware.elf firmware.bin .*~ *~ *lst
.PHONY: all main.o clean load
