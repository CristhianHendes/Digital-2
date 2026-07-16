from migen import *
from litex.soc.interconnect.csr import *


class Sub32(Module, AutoCSR):
    def __init__(self):

        self._A    = CSRStorage(32, description="Minuendo A (32 bits)")
        self._B    = CSRStorage(32, description="Sustraendo B (32 bits)")
        self._diff = CSRStatus(32, description="Resta A-B (32 bits, complemento a 2)")

        self.comb += self._diff.status.eq(self._A.storage - self._B.storage)


'''
mem_write 0xf0000000 400
mem_write 0xf0000004 200
mem_read  0xf0000008

'''
