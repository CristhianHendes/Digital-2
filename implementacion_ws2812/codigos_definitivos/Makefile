# =============================================================
# Makefile - sintetiza un top para Colorlight i9 v7.2
# (Yosys + nextpnr-ecp5 + ecppack, sin pasar por LiteX)
#
# TOP elige que version mandar a la FPGA (yosys descarta los
# modulos no usados por el top elegido, asi que da igual pasar
# siempre todas las fuentes):
#   make bit                            -> estatico (corazon.hex)
#   make bit TOP=ws2812_matrix_top_anim -> animado (corazon <-> corazon_pequeno)
TOP    ?= ws2812_matrix_top
SOURCES = ctrl_ws.v count_ws.v comp_ws.v mux_ws.v ws2812.v \
          ctrl_wsled.v count_wsled.v lsr_wsled.v ws2812_led.v \
          ctrl_ws_arr.v count_addr.v comp_ws_arr.v \
          led_mem.v ws2812_led_array.v ws2812_matrix_top.v \
          led_mem_mux.v ws2812_led_array_anim.v ws2812_matrix_top_anim.v
LPF     = ws2812_matrix.lpf

.PHONY: all synth pnr bit clean

all: bit

synth: $(TOP).json

$(TOP).json: $(SOURCES)
	yosys -p "read_verilog $(SOURCES); synth_ecp5 -top $(TOP) -json $(TOP).json"

pnr: $(TOP)_pnr.config

$(TOP)_pnr.config: $(TOP).json $(LPF)
	nextpnr-ecp5 --json $(TOP).json --lpf $(LPF) --textcfg $(TOP)_pnr.config \
	    --45k --package CABGA381 --speed 6 --timing-allow-fail --seed 1

bit: $(TOP).bit

$(TOP).bit: $(TOP)_pnr.config
	ecppack --bootaddr 0 $(TOP)_pnr.config --svf $(TOP).svf --bit $(TOP).bit

clean:
	rm -f $(TOP).json $(TOP)_pnr.config $(TOP).svf $(TOP).bit $(TOP).rpt
