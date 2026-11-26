//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
//Date        : Thu Nov 26 16:06:03 2026
//Host        : DESKTOP-I81MTO3 running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    btns_tri_i,
    jd,
    kypd_tri_io,
    led,
    oled_iic_scl_io,
    oled_iic_sda_io,
    sws_tri_i);
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  input [4:0]btns_tri_i;
  output [7:0]jd;
  inout [7:0]kypd_tri_io;
  output [7:0]led;
  inout oled_iic_scl_io;
  inout oled_iic_sda_io;
  input [7:0]sws_tri_i;

  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire [4:0]btns_tri_i;
  wire [7:0]jd;
  wire [0:0]kypd_tri_i_0;
  wire [1:1]kypd_tri_i_1;
  wire [2:2]kypd_tri_i_2;
  wire [3:3]kypd_tri_i_3;
  wire [4:4]kypd_tri_i_4;
  wire [5:5]kypd_tri_i_5;
  wire [6:6]kypd_tri_i_6;
  wire [7:7]kypd_tri_i_7;
  wire [0:0]kypd_tri_io_0;
  wire [1:1]kypd_tri_io_1;
  wire [2:2]kypd_tri_io_2;
  wire [3:3]kypd_tri_io_3;
  wire [4:4]kypd_tri_io_4;
  wire [5:5]kypd_tri_io_5;
  wire [6:6]kypd_tri_io_6;
  wire [7:7]kypd_tri_io_7;
  wire [0:0]kypd_tri_o_0;
  wire [1:1]kypd_tri_o_1;
  wire [2:2]kypd_tri_o_2;
  wire [3:3]kypd_tri_o_3;
  wire [4:4]kypd_tri_o_4;
  wire [5:5]kypd_tri_o_5;
  wire [6:6]kypd_tri_o_6;
  wire [7:7]kypd_tri_o_7;
  wire [0:0]kypd_tri_t_0;
  wire [1:1]kypd_tri_t_1;
  wire [2:2]kypd_tri_t_2;
  wire [3:3]kypd_tri_t_3;
  wire [4:4]kypd_tri_t_4;
  wire [5:5]kypd_tri_t_5;
  wire [6:6]kypd_tri_t_6;
  wire [7:7]kypd_tri_t_7;
  wire [7:0]led;
  wire oled_iic_scl_i;
  wire oled_iic_scl_io;
  wire oled_iic_scl_o;
  wire oled_iic_scl_t;
  wire oled_iic_sda_i;
  wire oled_iic_sda_io;
  wire oled_iic_sda_o;
  wire oled_iic_sda_t;
  wire [7:0]sws_tri_i;

  design_1 design_1_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .btns_tri_i(btns_tri_i),
        .jd(jd),
        .kypd_tri_i({kypd_tri_i_7,kypd_tri_i_6,kypd_tri_i_5,kypd_tri_i_4,kypd_tri_i_3,kypd_tri_i_2,kypd_tri_i_1,kypd_tri_i_0}),
        .kypd_tri_o({kypd_tri_o_7,kypd_tri_o_6,kypd_tri_o_5,kypd_tri_o_4,kypd_tri_o_3,kypd_tri_o_2,kypd_tri_o_1,kypd_tri_o_0}),
        .kypd_tri_t({kypd_tri_t_7,kypd_tri_t_6,kypd_tri_t_5,kypd_tri_t_4,kypd_tri_t_3,kypd_tri_t_2,kypd_tri_t_1,kypd_tri_t_0}),
        .led(led),
        .oled_iic_scl_i(oled_iic_scl_i),
        .oled_iic_scl_o(oled_iic_scl_o),
        .oled_iic_scl_t(oled_iic_scl_t),
        .oled_iic_sda_i(oled_iic_sda_i),
        .oled_iic_sda_o(oled_iic_sda_o),
        .oled_iic_sda_t(oled_iic_sda_t),
        .sws_tri_i(sws_tri_i));
  IOBUF kypd_tri_iobuf_0
       (.I(kypd_tri_o_0),
        .IO(kypd_tri_io[0]),
        .O(kypd_tri_i_0),
        .T(kypd_tri_t_0));
  IOBUF kypd_tri_iobuf_1
       (.I(kypd_tri_o_1),
        .IO(kypd_tri_io[1]),
        .O(kypd_tri_i_1),
        .T(kypd_tri_t_1));
  IOBUF kypd_tri_iobuf_2
       (.I(kypd_tri_o_2),
        .IO(kypd_tri_io[2]),
        .O(kypd_tri_i_2),
        .T(kypd_tri_t_2));
  IOBUF kypd_tri_iobuf_3
       (.I(kypd_tri_o_3),
        .IO(kypd_tri_io[3]),
        .O(kypd_tri_i_3),
        .T(kypd_tri_t_3));
  IOBUF kypd_tri_iobuf_4
       (.I(kypd_tri_o_4),
        .IO(kypd_tri_io[4]),
        .O(kypd_tri_i_4),
        .T(kypd_tri_t_4));
  IOBUF kypd_tri_iobuf_5
       (.I(kypd_tri_o_5),
        .IO(kypd_tri_io[5]),
        .O(kypd_tri_i_5),
        .T(kypd_tri_t_5));
  IOBUF kypd_tri_iobuf_6
       (.I(kypd_tri_o_6),
        .IO(kypd_tri_io[6]),
        .O(kypd_tri_i_6),
        .T(kypd_tri_t_6));
  IOBUF kypd_tri_iobuf_7
       (.I(kypd_tri_o_7),
        .IO(kypd_tri_io[7]),
        .O(kypd_tri_i_7),
        .T(kypd_tri_t_7));
  IOBUF oled_iic_scl_iobuf
       (.I(oled_iic_scl_o),
        .IO(oled_iic_scl_io),
        .O(oled_iic_scl_i),
        .T(oled_iic_scl_t));
  IOBUF oled_iic_sda_iobuf
       (.I(oled_iic_sda_o),
        .IO(oled_iic_sda_io),
        .O(oled_iic_sda_i),
        .T(oled_iic_sda_t));
endmodule
