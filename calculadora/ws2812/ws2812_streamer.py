from migen import *
from litex.soc.interconnect.csr import *
from litex.soc.interconnect import stream

import os
src_dir = os.path.dirname(os.path.abspath(__file__))


class WS2812StreamLoader(Module, AutoCSR):
    def __init__(self, n_leds=256):
        self.sink = sink = stream.Endpoint([("data", 32)])
        self.start = CSRStorage(1)
        self.done  = CSRStatus(1)
        self.busy  = CSRStatus(1)

        self.w_data    = Signal(24)
        self.w_address = Signal(max=n_leds)
        self.we        = Signal()

        addr     = Signal(max=n_leds)
        loading  = Signal(reset=0)
        draining = Signal(reset=0)
        done     = Signal(reset=0)
        busy     = Signal(reset=0)
        active   = Signal()

        self.comb += [
            active.eq(loading | draining),
            busy.eq(active),

            self.busy.status.eq(busy),
            self.done.status.eq(done),

            # Backpressure toward DMA Reader.
            # While loading, accepted words are written to the WS2812 RAM.
            # After the last LED word has been written, keep accepting/draining
            # any remaining DMA words until sink.last so the DMA can complete.
            sink.ready.eq(busy),
        ]

        self.sync += [
            # Register the write port signals. The Verilog LED memory writes on
            # negedge clk, so combinatorial addr/data from a posedge-updated
            # stream handshake would otherwise be observed half a cycle later
            # and shift writes by one address. Holding these outputs registered
            # gives ws2812_periph.mem0 stable write signals for the negedge.
            self.we.eq(0),
            If(self.start.re,
                addr.eq(0),
                loading.eq(1),
                draining.eq(0),
                done.eq(0),
                self.w_address.eq(0),
                self.w_data.eq(0)
            ).Elif(loading,
                If(sink.valid & sink.ready,
                    # One 32-bit DMA word per LED: 0x00RRGGBB.
                    # WishboneDMAReader presents 0x00RRGGBB from SRAM as
                    # 0xBBGGRR00 on the stream. Restore RGB before writing
                    # the WS2812 RAM.
                    self.w_data.eq(Cat(
                        sink.data[24:32],  # B -> bits [7:0]
                        sink.data[16:24],  # G -> bits [15:8]
                        sink.data[8:16],   # R -> bits [23:16]
                    )),
                    self.w_address.eq(addr),
                    self.we.eq(1),
                    If(addr == (n_leds - 1),
                        addr.eq(0),
                        loading.eq(0),
                        done.eq(1),
                        If(sink.last,
                            draining.eq(0)
                        ).Else(
                            draining.eq(1)
                        )
                    ).Else(
                        addr.eq(addr + 1)
                    )
                )
            ).Elif(draining,
                If(sink.valid & sink.ready,
                    If(sink.last,
                        draining.eq(0)
                    )
                )
            )
        ]



class WS2812(Module, AutoCSR):
    def __init__(self, platform, data, n_leds=256):
        # Existing WS2812 control/status CSR
        self.init    = CSRStorage(1)
        self.rst_cmd = CSRStorage(1)
        self.done    = CSRStatus(1)
        self.dout    = data.dout

        # DMA stream loader
        self.submodules.loader = WS2812StreamLoader(n_leds=n_leds)
        self.sink = self.loader.sink

        # Explicit connection:
        #   DMA stream -> WS2812StreamLoader -> ws2812_periph memory write port
        self.specials += Instance("ws2812_periph",
            i_clk       = ClockSignal("sys"),
            i_reset     = ResetSignal("sys"),
            i_init_m    = self.init.storage,
            i_rst_cmd   = self.rst_cmd.storage,

            # These three signals replace CSR w_data/w_address/we_a.
            i_we_a      = self.loader.we,
            i_w_data    = self.loader.w_data,
            i_w_address = self.loader.w_address,

            o_done      = self.done.status,
            o_dout      = self.dout,
        )

        for src in ["ctrl_wsled.v", "ws2812.v", "comp_ws_arr.v", "count_wsled.v",
                    "ws2812_led_array.v", "ctrl_ws.v", "comp_ws.v", "count_ws.v", "lsr_wsled.v",
                    "ws2812_led.v", "ws2812_periph.v", "count_addr.v", "ctrl_ws_arr.v",
                    "led_mem_dual.v", "mux_ws.v"]:
            platform.add_source(os.path.join(src_dir, src))
