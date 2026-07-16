from migen import *
from migen.genlib.divider import Divider
from litex.soc.interconnect.csr import *


class Div32(Module, AutoCSR):
    def __init__(self):

        self._A    = CSRStorage(32, description="Dividendo (32 bits)")
        self._B    = CSRStorage(32, description="Divisor (32 bits)")
        self._init = CSRStorage( 1, description="Pulso de inicio")

        self._q    = CSRStatus(32, description="Cociente (32 bits)")
        self._r    = CSRStatus(32, description="Residuo (32 bits)")
        self._done = CSRStatus( 1, description="1 cuando terminó")

        self.submodules.divider = divider = Divider(32)

        init_d = Signal()
        start  = Signal()
        self.sync += init_d.eq(self._init.storage)
        self.comb += start.eq(self._init.storage & ~init_d)

        self.comb += [
            divider.start_i.eq(start),
            divider.dividend_i.eq(self._A.storage),
            divider.divisor_i.eq(self._B.storage),
            self._q.status.eq(divider.quotient_o),
            self._r.status.eq(divider.remainder_o),
            self._done.status.eq(divider.ready_o),
        ]


'''
mem_write 0xf0000000 200
mem_write 0xf0000004 3
mem_write 0xf0000008 1
mem_write 0xf0000008 0
mem_read  0xf000000C
mem_read  0xf0000010

'''
