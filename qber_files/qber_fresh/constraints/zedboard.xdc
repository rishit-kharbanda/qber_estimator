## constraints/zedboard.xdc - ZedBoard (XC7Z020-CLG484-1) pin constraints (Part 4).
## Clock and DDR/MIO come from the PS7 block; only PL I/O is listed here.
## Pin names follow Digilent's ZedBoard master XDC.

## ---------------------------------------------------------------- user LEDs (bank 33)
## Driven by led_meter (Part 3) in the full design, by the stub in bring-up.
set_property -dict { PACKAGE_PIN T22  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN T21  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U22  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN U21  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN V22  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN W22  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

## ---------------------------------------------------------------- Pmod JD: debug pins (section 4c)
## From Part 2's constraints/part2_jd.xdc (qber_core_final); bank 13, 3.3 V.
## Port "jd" = qber_pl_0/dbg made external by build.tcl.
##   full design:  jd[0] ce, [1] t_valid, [2] t_err, [3] sprt_done,
##                 [4] sprt_abort, [5] fix_done, [6] blk_done, [7] rate_toggle
##                 (rate_toggle frequency = processed photons/s / 2^21; 47.7 Hz at 100 M/s)
##   bring-up:     jd[0] ce, jd[1] ph_valid, others 0
## Check JD1..JD10 against the board silkscreen before probing.
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {jd[0]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports {jd[1]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {jd[2]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {jd[3]}]
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports {jd[4]}]
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports {jd[5]}]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33} [get_ports {jd[6]}]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports {jd[7]}]
## oscilloscope only: no external timing requirement
set_false_path -to [get_ports {jd[*]}]

## Pmod JA (keypad), JB (I2C OLED), switches and buttons: in constraints/ui_pmods.xdc.
