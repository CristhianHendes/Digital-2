from migen import *
from litex.soc.interconnect.csr import *
import os
src_dir = os.path.dirname(os.path.abspath(__file__))


class Add32(Module, AutoCSR):
    def __init__(self, platform):

        self._A   = CSRStorage(32, description="Operando A (32 bits)")
        self._B   = CSRStorage(32, description="Operando B (32 bits)")
        self._sum = CSRStatus(32, description="Suma A+B (32 bits)")

       
        self.specials += Instance("add_32",
            i_A   = self._A.storage,
            i_B   = self._B.storage,
            o_sum = self._sum.status,
        )

        platform.add_source(os.path.join(src_dir, "add_32.v"))


'''
mem_write 0xf0000000 200
mem_write 0xf0000004 400
mem_read  0xf0000008

'''
