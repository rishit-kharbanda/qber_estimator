`timescale 1ns / 1ps

`ifndef USE_QBER_CORE
`define USE_QBER_CORE
`endif
`ifndef QBER_CORE_PE_CNT
`define QBER_CORE_PE_CNT
`endif

`default_nettype none

module qber_pl (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:m_axis, ASSOCIATED_RESET aresetn, FREQ_HZ 100000000" *)
    input  wire        aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,

    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    output wire [7:0]  led,
    output wire [7:0]  dbg
);

    wire        rst;
    wire        start, stop, step;
    wire [1:0]  mode;
    wire        curtail_en, test_all, stream_en;
    wire [15:0] p_noise, f_eve;
    wire [31:0] rate_div, slow_div, num_blocks;
    wire [12:0] block_size;
    wire [15:0] inc_err, inc_ok, thr_a, thr_b, nmax, fix_n, fix_c, stream_pkt;
    wire [319:0] seeds;

    wire        busy, done, last_sprt_abort, last_fix_abort, last_trunc, pl_drop_flag, pe_err;
    wire        ce, ph_valid, a_bit, a_basis, b_bit, b_basis;
    wire [15:0] live_score;
    wire [31:0] live_n, lat_last, lat_max;
    wire [63:0] c_cycles, c_photons_in, c_pl_dropped, c_sifted, c_sifted_errs,
                c_blocks_done, c_sum_n_sprt, c_sum_n_fix, c_abort_sprt, c_abort_fix,
                c_trunc_sprt, c_key_sprt, c_key_fix, c_photons_proc, c_disclosed, c_key_out;

    wire [63:0] c_stream_sent, c_stream_dropped;
    wire        stream_drop_flag;

`ifdef USE_QBER_CORE
    localparam [31:0] VERSION = 32'h8000_0300;
`else
    localparam [31:0] VERSION = 32'h0000_0300;
`endif

    axi_regs #(.ADDR_W(12), .N_CNT(20), .VERSION_VALUE(VERSION)) u_regs (
        .s_axi_aclk(aclk), .s_axi_aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .rst_core(rst), .cfg_start(start), .cfg_step(step), .cfg_stop(stop),
        .cfg_mode(mode), .cfg_curtail_en(curtail_en), .cfg_test_all(test_all), .cfg_stream_en(stream_en),
        .cfg_p_noise(p_noise), .cfg_f_eve(f_eve), .cfg_rate_div(rate_div), .cfg_slow_div(slow_div),
        .cfg_block_size(block_size), .cfg_num_blocks(num_blocks),
        .cfg_sprt_inc_err(inc_err), .cfg_sprt_inc_ok(inc_ok), .cfg_sprt_thr_a(thr_a), .cfg_sprt_thr_b(thr_b),
        .cfg_sprt_nmax(nmax), .cfg_fix_n(fix_n), .cfg_fix_c(fix_c), .cfg_stream_pkt(stream_pkt),
        .cfg_seeds(seeds),
        .status_in({pe_err, stream_drop_flag, pl_drop_flag, last_trunc, last_fix_abort,
                    last_sprt_abort, done, busy}),

        .cnt_in({c_key_out, c_disclosed, 64'd0, 64'd0,
                 c_photons_proc, c_stream_dropped, c_stream_sent, c_key_fix, c_key_sprt,
                 c_trunc_sprt, c_abort_fix, c_abort_sprt, c_sum_n_fix, c_sum_n_sprt,
                 c_blocks_done, c_sifted_errs, c_sifted, c_pl_dropped, c_photons_in, c_cycles}),
        .live_score(live_score), .live_n(live_n), .lat_last(lat_last), .lat_max(lat_max)
    );

`ifdef USE_QBER_CORE

    wire led_blk_done, led_sprt_abort, led_sprt_done;

    qber_core u_core (
        .clk(aclk), .rst(rst),
        .ctrl_start(start), .ctrl_soft_rst(1'b0), .ctrl_mode(mode), .ctrl_step(step),
        .ctrl_curtail_en(curtail_en), .ctrl_test_all(test_all), .ctrl_stop(stop),
        .p_noise(p_noise), .f_eve(f_eve), .rate_div(rate_div), .slow_div(slow_div),
        .block_size(block_size), .num_blocks(num_blocks),
        .sprt_inc_err(inc_err), .sprt_inc_ok(inc_ok), .sprt_thr_a(thr_a), .sprt_thr_b(thr_b),
        .sprt_nmax(nmax), .fix_n(fix_n), .fix_c(fix_c),
        .seed0(seeds[63:0]), .seed1(seeds[127:64]), .seed2(seeds[191:128]),
        .seed3(seeds[255:192]), .seed4(seeds[319:256]),
        .st_busy(busy), .st_done(done), .st_last_sprt_abort(last_sprt_abort),
        .st_last_fix_abort(last_fix_abort), .st_last_trunc(last_trunc), .st_pl_drop_flag(pl_drop_flag),
        .cnt_cycles(c_cycles), .cnt_photons_in(c_photons_in), .cnt_pl_dropped(c_pl_dropped),
        .cnt_sifted(c_sifted), .cnt_sifted_errs(c_sifted_errs), .cnt_blocks_done(c_blocks_done),
        .cnt_sum_n_sprt(c_sum_n_sprt), .cnt_sum_n_fix(c_sum_n_fix), .cnt_abort_sprt(c_abort_sprt),
        .cnt_abort_fix(c_abort_fix), .cnt_trunc_sprt(c_trunc_sprt), .cnt_key_sprt(c_key_sprt),
        .cnt_key_fix(c_key_fix), .cnt_photons_proc(c_photons_proc),
`ifdef QBER_CORE_PE_CNT
        .cnt_disclosed(c_disclosed), .cnt_key_out(c_key_out), .st_pe_err(pe_err),
`endif
        .live_score(live_score), .live_n(live_n), .lat_last(lat_last), .lat_max(lat_max),
        .tap_ce(ce), .tap_ph_valid(ph_valid), .tap_a_bit(a_bit), .tap_a_basis(a_basis),
        .tap_b_bit(b_bit), .tap_b_basis(b_basis),
        .led_blk_done(led_blk_done), .led_sprt_abort(led_sprt_abort), .led_sprt_done(led_sprt_done),
        .jd(dbg)
    );
`ifndef QBER_CORE_PE_CNT
    assign c_disclosed = 64'd0;
    assign c_key_out   = 64'd0;
    assign pe_err      = 1'b0;
`endif

    led_meter u_led (
        .clk(aclk), .rst(rst),
        .live_score(live_score), .thr_a(thr_a), .thr_b(thr_b),
        .blk_done(led_blk_done), .sprt_abort(led_sprt_abort),
        .led(led)
    );
`else

    core_stub u_core (
        .clk(aclk), .rst(rst), .start(start), .stop(stop), .step(step), .mode(mode),
        .rate_div(rate_div), .slow_div(slow_div),
        .busy(busy), .done(done), .ce(ce),
        .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis), .b_bit(b_bit), .b_basis(b_basis),
        .cycles(c_cycles), .photons_in(c_photons_in)
    );
    assign {last_sprt_abort, last_fix_abort, last_trunc, pl_drop_flag, pe_err} = 5'd0;
    assign live_score = 16'd0;
    assign {live_n, lat_last, lat_max} = 96'd0;
    assign {c_pl_dropped, c_sifted, c_sifted_errs, c_blocks_done, c_sum_n_sprt, c_sum_n_fix,
            c_abort_sprt, c_abort_fix, c_trunc_sprt, c_key_sprt, c_key_fix,
            c_disclosed, c_key_out} = {13{64'd0}};
    assign c_photons_proc = c_photons_in;

    reg [26:0] hb;
    always @(posedge aclk) hb <= rst ? 27'd0 : hb + 27'd1;
    assign led = {hb[26], 5'd0, stream_drop_flag, busy};
    assign dbg = {6'd0, ph_valid, ce};
`endif

    reg       busy_q, en_q, draining;
    reg [2:0] drain_cnt;
    wire      drain_end = draining & ce & (drain_cnt == 3'd3);
    always @(posedge aclk) begin
        if (rst) begin
            busy_q <= 1'b0; en_q <= 1'b0; draining <= 1'b0; drain_cnt <= 3'd0;
        end else begin
            busy_q <= busy;
            en_q   <= stream_en;
            if (start | busy) begin
                draining <= 1'b0;
            end else if (busy_q & ~busy) begin
                draining <= 1'b1; drain_cnt <= 3'd0;
            end else if (draining & ce) begin
                drain_cnt <= drain_cnt + 3'd1;
                if (drain_end) draining <= 1'b0;
            end
        end
    end
    wire flush = drain_end | (en_q & ~stream_en);

    photon_packer u_pack (
        .clk(aclk), .rst(rst), .en(stream_en), .clear(start), .flush(flush), .pkt_len(stream_pkt),
        .ce(ce), .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis), .b_bit(b_bit), .b_basis(b_basis),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast),
        .words_sent(c_stream_sent), .words_dropped(c_stream_dropped), .drop_flag(stream_drop_flag)
    );

endmodule

`default_nettype wire
