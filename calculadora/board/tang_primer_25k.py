#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2021 Miodrag Milanovic <mmicko@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

from litex.build.generic_platform import *
from litex.build.gowin.platform import GowinPlatform
from litex.build.gowin.programmer import GowinProgrammer

# IOs ----------------------------------------------------------------------------------------------

_io = [
    # Clk
    ("clk50", 0, Pins("E2"), IOStandard("LVCMOS33")),

    # Serial
    ("serial", 0,
        Subsignal("tx", Pins("C3")), # 27 on H4 Must be changed in next HW version to 144
        Subsignal("rx", Pins("B3")), # 28 on H4 Must be changed in next HW version to 142
        IOStandard("LVCMOS33")
    ),

    # Leds
    ("user_led", 0, Pins("E8"), IOStandard("LVCMOS33")),


    # Buttons
    ("user_btn", 0, Pins("H10"), IOStandard("LVCMOS33")),
    ("user_btn", 1, Pins("H11"), IOStandard("LVCMOS33")),
'''

    # Switches
    ("user_sw", 0, Pins("78"),  IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("WEAK_PULLUP")),
    ("user_sw", 1, Pins("79"),  IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("WEAK_PULLUP")),
    ("user_sw", 2, Pins("80"),  IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("WEAK_PULLUP")),

    # SPIFlash
#    ("spiflash", 0,
#        Subsignal("cs_n", Pins("31")),
#        Subsignal("clk",  Pins("30")),
#        Subsignal("mosi", Pins("29")),
#        Subsignal("miso", Pins("28")),
#        IOStandard("3.3_V_LVTTL_/_LVCMOS")
#s    ),

    # SPIRAM
#    ("spiflash", 0,
#        Subsignal("cs_n", Pins("111"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#        Subsignal("clk",  Pins("113"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#        Subsignal("mosi", Pins("112"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#        Subsignal("miso", Pins("110"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#        Subsignal("wp",   Pins("109"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#        Subsignal("hold", Pins("114"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
#    ),
    ("spiram4x", 0,
        Subsignal("cs_n", Pins("111"),             IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("SLEWRATE=SLOW")),
        Subsignal("clk",  Pins("113"),             IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("SLEWRATE=SLOW")),
        Subsignal("dq",   Pins("112 110 109 114"), IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("SLEWRATE=SLOW")),
    ),

    # RMII Ethernet
    ("eth_clocks", 0,
        Subsignal("ref_clk", Pins("70")),
        IOStandard("3.3_V_LVTTL_/_LVCMOS"),
    ),
    ("eth", 0,
        Subsignal("rst_n",   Pins("66")),
        Subsignal("rx_data", Pins("72 71")),
        Subsignal("crs_dv",  Pins("59")),
        Subsignal("tx_en",   Pins("67")),
        Subsignal("tx_data", Pins("69 68")),
        Subsignal("mdc",     Pins("65")),
        Subsignal("mdio",    Pins("61")),
        Subsignal("rx_er",   Pins("58")),
        #Subsignal("int_n",   Pins("CARD1:")),
        IOStandard("3.3_V_LVTTL_/_LVCMOS")
     ),
     
    # HyperRAM
    ("hyperram", 0,
        Subsignal("dq", Pins("112 113 117 114 115 109 110 111"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
        Subsignal("rwds", Pins("116"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
        Subsignal("cs_n", Pins("123"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
        Subsignal("rst_n", Pins("124"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
        Subsignal("clk", Pins("119"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),
        #Subsignal("clk_n", Pins("118"), IOStandard("DIFF_3.3_V_LVTTL")),
        Misc("SLEW=FAST"),
    ),
'''
]


# Connectors ---------------------------------------------------------------------------------------

_connectors = [

]

# Platform -----------------------------------------------------------------------------------------

class Platform(GowinPlatform):
    default_clk_name   = "clk50"
    default_clk_period = 1e9/50e6

    def __init__(self, toolchain="gowin"):
        GowinPlatform.__init__(self, "GW5A-LV25MG121NC1/I0", _io, _connectors, toolchain=toolchain, devicename="GW5A-25A")
        self.toolchain.options["use_mspi_as_gpio"]  = 1 # spi flash
        self.toolchain.options["use_i2c_as_gpio"]   = 1 # SDRAM / J3
        self.toolchain.options["use_ready_as_gpio"] = 1 # led
        self.toolchain.options["use_done_as_gpio"]  = 1 # led
        self.toolchain.options["use_cpu_as_gpio"]   = 1 # clk
        self.toolchain.options["rw_check_on_ram"]   = 1
        
    def create_programmer(self):
        return OpenFPGALoader(cable="ft2232")

    def do_finalize(self, fragment):
        GowinPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk50", loose=True), 1e9/50e6)
        
