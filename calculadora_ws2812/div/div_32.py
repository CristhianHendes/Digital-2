from migen import *
from litex.soc.interconnect.csr import *
import os
src_dir = os.path.dirname(os.path.abspath(__file__))


class Div32(Module, AutoCSR):
    def __init__(self, platform):

        self._A    = CSRStorage(32, description="Dividendo (32 bits)")
        self._B    = CSRStorage(32, description="Divisor (32 bits)")
        self._init = CSRStorage( 1, description="Pulso de inicio")

        self._q    = CSRStatus(32, description="Cociente (32 bits)")
        self._r    = CSRStatus(32, description="Residuo (32 bits)")
        self._done = CSRStatus( 1, description="1 cuando terminó")


        self.specials += Instance("div_32",
            i_clk  = ClockSignal("sys"),
            i_rst  = ResetSignal("sys"),
            i_init = self._init.storage,
            i_A    = self._A.storage,
            i_B    = self._B.storage,
            o_q    = self._q.status,
            o_r    = self._r.status,
            o_done = self._done.status,
        )

        for src in ["divisor_reg.v", "qr_reg.v", "sub_cmp33.v", "control_div.v", "div_32.v"]:
            platform.add_source(os.path.join(src_dir, src))


'''
mem_write 0xf0000000 200
mem_write 0xf0000004 3
mem_write 0xf0000008 1
mem_write 0xf0000008 0
mem_read  0xf000000C
mem_read  0xf0000010

'''
