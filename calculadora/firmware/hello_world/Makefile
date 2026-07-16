# *************************************************
# IMPORTANTE PARA PODER COMPILAR ESTE EJEMPLO:
# En el aechivo:litex/litex/soc/software/common.mak
# cambiar de:
# ifeq ($(LTO), 1)
# COMMONFLAGS += -flto
# endif
# a:
# COMMONFLAGS += -flto
# *************************************************

BUILD_DIR=../../build/ecb_t8_t113/
include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak
OBJECTS = 	crt0.o main.o
SERIAL ?= /dev/ttyUSB1

all: hello_world.bin
%.bin: %.elf %.lst
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

%.lst: %.elf
	$(TARGET_PREFIX)objdump -h -S $< > $@
	cp $@ firmware.lst

vpath %.a $(PACKAGES:%=../%)


hello_world.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) -T linker.ld -N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-Wl,--whole-archive \
		-Wl,--gc-sections \
		-Wl,-Map,$@.map \
		$(LIBS:lib%=-l%)
	chmod -x $@

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)


VPATH = $(BIOS_DIRECTORY):$(BIOS_DIRECTORY)/cmds:$(CPU_DIRECTORY)

%.o: %.c
	$(compile)
%.o: %.S
	$(assemble)
litex_term: hello_world.bin
	@ls ${SERIAL} || (echo "\n\nNo se encuentra ${SERIAL} conectado, verifique conexión o cambie el valor de SERIAL=${SERIAL} por un puerto serial existente\n\n"; exit 123;)
	litex_term ${SERIAL} --kernel hello_world.bin

clean:
	$(RM) $(OBJECTS) *.elf *.bin .*~ *~ *.map *.d *.lst *.o
#.PHONY: clean
