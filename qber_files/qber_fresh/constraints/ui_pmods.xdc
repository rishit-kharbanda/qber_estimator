## ===========================================================================
## constraints/ui_pmods.xdc  -  Part 3 (User Interface) pins, ZedBoard
## Pin numbers from the ZedBoard master XDC. Added by build.tcl -ui (Part 4);
## the LED pins are in constraints/zedboard.xdc.
## Fresh build (26 Nov): keypad on JA, 4-pin I2C OLED on JB, J18 (VADJ) = 1.8 V.
## ===========================================================================

## ---- Pmod KYPD on JA (bank 13, 3.3 V): bits 0-3 columns, 4-7 rows ----
set_property PACKAGE_PIN Y11  [get_ports {kypd_tri_io[0]}]   ;# JA1  COL4: A B C D
set_property PACKAGE_PIN AA11 [get_ports {kypd_tri_io[1]}]   ;# JA2  COL3: 3 6 9 E
set_property PACKAGE_PIN Y10  [get_ports {kypd_tri_io[2]}]   ;# JA3  COL2: 2 5 8 F
set_property PACKAGE_PIN AA9  [get_ports {kypd_tri_io[3]}]   ;# JA4  COL1: 1 4 7 0
set_property PACKAGE_PIN AB11 [get_ports {kypd_tri_io[4]}]   ;# JA7  ROW4: 0 F E D
set_property PACKAGE_PIN AB10 [get_ports {kypd_tri_io[5]}]   ;# JA8  ROW3: 7 8 9 C
set_property PACKAGE_PIN AB9  [get_ports {kypd_tri_io[6]}]   ;# JA9  ROW2: 4 5 6 B
set_property PACKAGE_PIN AA8  [get_ports {kypd_tri_io[7]}]   ;# JA10 ROW1: 1 2 3 A
set_property IOSTANDARD LVCMOS33 [get_ports {kypd_tri_io[*]}]
set_property PULLUP true         [get_ports {kypd_tri_io[*]}]

## ---- 128x64 I2C OLED on JB (bank 13, 3.3 V) ----
## OLED SCL -> JB pin 1, SDA -> JB pin 2, GND -> JB pin 5, VCC -> JB pin 6 (3.3 V, never 5 V)
set_property PACKAGE_PIN W12 [get_ports oled_iic_scl_io]     ;# JB1 -> SCL
set_property PACKAGE_PIN W11 [get_ports oled_iic_sda_io]     ;# JB2 -> SDA
set_property IOSTANDARD LVCMOS33 [get_ports {oled_iic_scl_io oled_iic_sda_io}]
set_property PULLUP true         [get_ports {oled_iic_scl_io oled_iic_sda_io}]

## ---- LEDs LD0..LD7: in constraints/zedboard.xdc (led_meter sits inside qber_pl) ----

## ---- Switches (bank 35) and buttons (bank 34) ----
## These banks run at VADJ (jumper J18), set to 1.8 V. Match the IOSTANDARD below:
##   J18 = 1.8V -> LVCMOS18     2.5V -> LVCMOS25     3.3V -> LVCMOS33
set_property PACKAGE_PIN F22 [get_ports {sws_tri_i[0]}]
set_property PACKAGE_PIN G22 [get_ports {sws_tri_i[1]}]
set_property PACKAGE_PIN H22 [get_ports {sws_tri_i[2]}]
set_property PACKAGE_PIN F21 [get_ports {sws_tri_i[3]}]
set_property PACKAGE_PIN H19 [get_ports {sws_tri_i[4]}]
set_property PACKAGE_PIN H18 [get_ports {sws_tri_i[5]}]
set_property PACKAGE_PIN H17 [get_ports {sws_tri_i[6]}]
set_property PACKAGE_PIN M15 [get_ports {sws_tri_i[7]}]
set_property PACKAGE_PIN P16 [get_ports {btns_tri_i[0]}]     ;# BTNC
set_property PACKAGE_PIN R16 [get_ports {btns_tri_i[1]}]     ;# BTND
set_property PACKAGE_PIN N15 [get_ports {btns_tri_i[2]}]     ;# BTNL
set_property PACKAGE_PIN R18 [get_ports {btns_tri_i[3]}]     ;# BTNR
set_property PACKAGE_PIN T18 [get_ports {btns_tri_i[4]}]     ;# BTNU
set_property IOSTANDARD LVCMOS18 [get_ports {sws_tri_i[*] btns_tri_i[*]}]
