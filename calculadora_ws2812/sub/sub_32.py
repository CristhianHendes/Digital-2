from migen import *
from litex.soc.interconnect.csr import *
import os
src_dir = os.path.dirname(os.path.abspath(__file__))


class Sub32(Module, AutoCSR):
    def __init__(self, platform):

        self._A    = CSRStorage(32, description="Minuendo A (32 bits)")
        self._B    = CSRStorage(32, description="Sustraendo B (32 bits)")
        self._diff = CSRStatus(32, description="Resta A-B (32 bits, complemento a 2)")

        # Restador combinacional en Verilog puro (sub_32.v); Migen solo
        # conecta sus puertos a los registros CSR.
        self.specials += Instance("sub_32",
            i_A    = self._A.storage,
            i_B    = self._B.storage,
            o_diff = self._diff.status,
        )

        platform.add_source(os.path.join(src_dir, "sub_32.v"))


'''
mem_write 0xf0000000 400
mem_write 0xf0000004 200
mem_read  0xf0000008

'''
