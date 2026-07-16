from litex.build.generic_platform import *
from litex.build.efinix.platform import EfinixPlatform
from litex.build.efinix import EfinixProgrammer
# IOs ----------------------------------------------------------------------------------------------
_io = [
    # Clk
    ("clk33", 0, Pins("75"), IOStandard("3.3_V_LVTTL_/_LVCMOS")),

    # Serial
    ("serial", 0,
        Subsignal("tx", Pins("144")), # 27 on H4 Must be changed in next HW version to 144
        Subsignal("rx", Pins("142")), # 28 on H4 Must be changed in next HW version to 142
        IOStandard("3.3_V_LVTTL_/_LVCMOS") , Misc("WEAK_PULLUP")
    ),
    # Leds
    ("user_led", 0, Pins("20"), IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("DRIVE_STRENGTH=3")),
    ("user_led", 1, Pins("76"), IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("DRIVE_STRENGTH=3")),
    # Buttons
    ("user_btn_n", 0, Pins("74"), IOStandard("3.3_V_LVTTL_/_LVCMOS"), Misc("WEAK_PULLUP")),

    # SPIFlash
#    ("spiflash", 0,
#        Subsignal("cs_n", Pins("31")),
#        Subsignal("clk",  Pins("30")),
#        Subsignal("mosi", Pins("29")),
#        Subsignal("miso", Pins("28")),
#        IOStandard("3.3_V_LVTTL_/_LVCMOS")
#s    ),

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
        IOStandard("3.3_V_LVTTL_/_LVCMOS"),
     ),

    ("sadc", 0, 
        Subsignal("osc"    ,   Pins("6")),
        Subsignal("data_out" , Pins("4 3 141 140 139 138 137 136 135 134 132 131 ")),
    ),

]



_bank_info = [
]

# Connectors ---------------------------------------------------------------------------------------

_connectors = [
    ("J11", #   1  3  5  7  9  11 13 15 17 19 21  23  25 3.3V
             "  -- 76 78 80 82 84 87 90 93 98 100 102 105  ",
             #  2  4  6  8  10 12 14 16 18 20 22  24  26  GND
             "  - 77 79 81 83 86 89 92 97 99 101 103 106 "),
    ("J12", #GND 3 5   7   9   11  13  15  17  19 
             " - - 116 118 123 131 134 136 138 140",
            #3.3 4   6   8   10  12  14  16  18  20 
             " 75 115 117 119 124 132 135 137 139 141 "),
]

# Platform -----------------------------------------------------------------------------------------

class Platform(EfinixPlatform):
    default_clk_name   = "clk33"
    default_clk_freq   = 33.333e6
    default_clk_period = 1e9/33.333e6

    def __init__(self, toolchain="efinity"):
        EfinixPlatform.__init__(self, "T20Q144C3", _io, _connectors, iobank_info=_bank_info, toolchain=toolchain)

    def create_programmer(self):
        return EfinixProgrammer()

    def do_finalize(self, fragment):
        EfinixPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk33", loose=True), 1e9/33.333e6)
