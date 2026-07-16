from migen import *
from litex.soc.interconnect.csr import *


class Add32(Module, AutoCSR):
    def __init__(self):

        self._A   = CSRStorage(32, description="Operando A (32 bits)")
        self._B   = CSRStorage(32, description="Operando B (32 bits)")
        self._sum = CSRStatus(32, description="Suma A+B (32 bits)")

        self.comb += self._sum.status.eq(self._A.storage + self._B.storage)


'''
mem_write 0xf0000000 200
mem_write 0xf0000004 400
mem_read  0xf0000008

'''
