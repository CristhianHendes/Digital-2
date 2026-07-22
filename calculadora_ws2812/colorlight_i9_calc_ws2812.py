#!/usr/bin/env python3

#
# LiteX SoC on Colorlight i9 (v7.2): Calculadora con pantalla WS2812.
#
# Union de dos proyectos ya existentes en este repositorio:
#  - calculadora/colorlight_i5.py: cores mult/div/add/sub (CSR).
#  - implementacion_ws2812/litex_ws2812: periferico WS2812 (DMA + CSR),
#    version ya corregida (color GRB, timing real del reloj del SoC,
#    direccionamiento N_LEDS). Ver notas en ws2812/ws2812_streamer.py
#    y ws2812/ws2812_periph.v para el detalle de cada fix.
#
# El firmware (firmware/main.c) es el que orquesta todo: lee caracteres
# por UART, dispara el core aritmetico correspondiente via sus CSR, y
# dibuja en la matriz 8x8 (caracter individual mientras se escribe,
# scroll de la operacion completa al mostrar el resultado).
#

from migen import *

from litex.gen import *
from litex.build.io import DDROutput
from board import colorlight_i5

from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.cores.led import LedChaser
from litex.soc.interconnect.csr import *
from litedram.modules import M12L64322A # Compatible con EM638325-6H.
from litedram.phy import GENSDRPHY, HalfRateGENSDRPHY

# DMA / WS2812 -------------------------------------------------------------------------------------
from litex.soc.cores.dma import WishboneDMAReader
from litex.soc.interconnect import wishbone

from mult import mult_32
from div import div_32
from add import add_32
from sub import sub_32
from ws2812 import ws2812_streamer

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq, use_internal_osc=False, sdram_rate="1:1"):
        self.rst    = Signal()
        self.cd_sys = ClockDomain()
        if sdram_rate == "1:2":
            self.cd_sys2x    = ClockDomain()
            self.cd_sys2x_ps = ClockDomain()
        else:
            self.cd_sys_ps = ClockDomain()

        # # #

        # Clk / Rst
        if not use_internal_osc:
            clk = platform.request("clk25")
            clk_freq = 25e6
        else:
            clk = Signal()
            div = 5
            self.specials += Instance("OSCG",
                p_DIV = div,
                o_OSC = clk
            )
            clk_freq = 310e6/div

        rst_n = platform.request("cpu_reset_n")

        # PLL
        self.pll = pll = ECP5PLL()
        self.comb += pll.reset.eq(~rst_n | self.rst)
        pll.register_clkin(clk, clk_freq)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        if sdram_rate == "1:2":
            pll.create_clkout(self.cd_sys2x,    2*sys_clk_freq)
            pll.create_clkout(self.cd_sys2x_ps, 2*sys_clk_freq, phase=180)
        else:
            pll.create_clkout(self.cd_sys_ps, sys_clk_freq, phase=180)

        # SDRAM clock
        sdram_clk = ClockSignal("sys2x_ps" if sdram_rate == "1:2" else "sys_ps")
        self.specials += DDROutput(1, 0, platform.request("sdram_clock"), sdram_clk)

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, board="i9", revision="7.2", toolchain="trellis", sys_clk_freq=60e6,
        with_led_chaser   = True,
        use_internal_osc  = False,
        sdram_rate        = "1:1",
        ws2812_n_leds     = 64,
        **kwargs):
        board = board.lower()
        assert board in ["i5", "i9"]
        platform = colorlight_i5.Platform(board=board, revision=revision, toolchain=toolchain)

        # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform, sys_clk_freq,
            use_internal_osc = use_internal_osc,
            sdram_rate       = sdram_rate,
        )

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, int(sys_clk_freq), ident = "LiteX Calculadora+WS2812 on Colorlight " + board.upper(), **kwargs)

        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            ledn = platform.request_all("user_led_n")
            self.leds = LedChaser(pads=ledn, sys_clk_freq=sys_clk_freq)

        # CALCULADORA --------------------------------------------------------------------------------
        # Cuatro cores independientes, cada uno con sus propios CSR
        # (ver calculadora/{mult,div,add,sub}/*.py para el detalle):
        #   mult0: mult0__A, mult0__B, mult0_init, mult0_pp,   mult0_done
        #   div0:  div0__A,  div0__B,  div0_init,  div0_q, div0_r, div0_done
        #   add0:  add0__A,  add0__B,  add0_sum    (combinacional, sin init/done)
        #   sub0:  sub0__A,  sub0__B,  sub0_diff   (combinacional, sin init/done)
        self.submodules.mult0 = mult_32.Mult32(platform)
        self.submodules.div0  = div_32.Div32(platform)
        self.submodules.add0  = add_32.Add32(platform)
        self.submodules.sub0  = sub_32.Sub32(platform)

        # LED MATRIX (WS2812) -----------------------------------------------------------------------
        self.submodules.disp0 = ws2812_streamer.WS2812(
            platform,
            platform.request("led_matrix", 0),
            n_leds=ws2812_n_leds,
            sys_clk_freq=sys_clk_freq,
        )

        ws2812_dma_bus = wishbone.Interface(
            data_width = self.bus.data_width,
            adr_width  = self.bus.get_address_width(standard="wishbone"),
            addressing = "word",
        )
        self.submodules.disp0_dma = WishboneDMAReader(ws2812_dma_bus, with_csr=True)
        self.bus.add_master("disp0_dma", master=ws2812_dma_bus)

        self.comb += self.disp0_dma.source.connect(self.disp0.sink)

        # SPI Flash --------------------------------------------------------------------------------
        if board == "i5":
            from litespi.modules import GD25Q16 as SpiFlashModule
        if board == "i9":
            from litespi.modules import W25Q64 as SpiFlashModule

        from litespi.opcodes import SpiNorFlashOpCodes as Codes
        self.add_spi_flash(mode="1x", module=SpiFlashModule(Codes.READ_1_1_1))

        # SDR SDRAM --------------------------------------------------------------------------------
        if not self.integrated_main_ram_size:
            sdrphy_cls = HalfRateGENSDRPHY if sdram_rate == "1:2" else GENSDRPHY
            self.sdrphy = sdrphy_cls(platform.request("sdram"))
            self.add_sdram("sdram",
                phy           = self.sdrphy,
                module        = M12L64322A(sys_clk_freq, sdram_rate),
                l2_cache_size = kwargs.get("l2_size", 8192)
            )

# Build --------------------------------------------------------------------------------------------

def main():
    from litex.build.parser import LiteXArgumentParser
    parser = LiteXArgumentParser(platform=colorlight_i5.Platform, description="LiteX Calculadora+WS2812 on Colorlight i9.")
    parser.add_target_argument("--board",            default="i9",             help="Board type (i5 o i9).")
    parser.add_target_argument("--revision",         default="7.2",            help="Board revision.")
    parser.add_target_argument("--sys-clk-freq",     default=60e6, type=float, help="System clock frequency.")
    parser.add_target_argument("--use-internal-osc", action="store_true",      help="Use internal oscillator.")
    parser.add_target_argument("--sdram-rate",       default="1:1",            help="SDRAM Rate (1:1 o 1:2).")
    parser.add_target_argument("--ws2812-n-leds",    default=64, type=int,     help="Numero de LEDs de la matriz (8x8 = 64).")
    args = parser.parse_args()

    soc = BaseSoC(board=args.board, revision=args.revision,
        toolchain         = args.toolchain,
        sys_clk_freq      = args.sys_clk_freq,
        use_internal_osc  = args.use_internal_osc,
        sdram_rate        = args.sdram_rate,
        ws2812_n_leds     = args.ws2812_n_leds,
        **parser.soc_argdict
    )

    builder = Builder(soc, **parser.builder_argdict)
    if args.build:
        builder.build(**parser.toolchain_argdict)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
