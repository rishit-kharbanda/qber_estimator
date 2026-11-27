`timescale 1ns / 1ps
`default_nettype none

module qber_core #(
    parameter FAST_FILL = 1,
    parameter PC_DELAY  = 0
) (
    input  wire               clk,
    input  wire               rst,

    input  wire               ctrl_start,
    input  wire               ctrl_soft_rst,
    input  wire        [1:0]  ctrl_mode,
    input  wire               ctrl_step,
    input  wire               ctrl_curtail_en,
    input  wire               ctrl_test_all,
    input  wire               ctrl_stop,

    input  wire        [15:0] p_noise,
    input  wire        [15:0] f_eve,
    input  wire        [31:0] rate_div,
    input  wire        [31:0] slow_div,
    input  wire        [12:0] block_size,
    input  wire        [31:0] num_blocks,
    input  wire signed [15:0] sprt_inc_err,
    input  wire signed [15:0] sprt_inc_ok,
    input  wire signed [15:0] sprt_thr_a,
    input  wire signed [15:0] sprt_thr_b,
    input  wire        [15:0] sprt_nmax,
    input  wire        [15:0] fix_n,
    input  wire        [15:0] fix_c,
    input  wire        [63:0] seed0,
    input  wire        [63:0] seed1,
    input  wire        [63:0] seed2,
    input  wire        [63:0] seed3,
    input  wire        [63:0] seed4,

    output wire               st_busy,
    output wire               st_done,
    output wire               st_last_sprt_abort,
    output wire               st_last_fix_abort,
    output wire               st_last_trunc,
    output wire               st_pl_drop_flag,
    output wire               st_pe_err,

    output wire        [63:0] cnt_cycles,
    output wire        [63:0] cnt_photons_in,
    output wire        [63:0] cnt_pl_dropped,
    output wire        [63:0] cnt_sifted,
    output wire        [63:0] cnt_sifted_errs,
    output wire        [63:0] cnt_blocks_done,
    output wire        [63:0] cnt_sum_n_sprt,
    output wire        [63:0] cnt_sum_n_fix,
    output wire        [63:0] cnt_abort_sprt,
    output wire        [63:0] cnt_abort_fix,
    output wire        [63:0] cnt_trunc_sprt,
    output wire        [63:0] cnt_key_sprt,
    output wire        [63:0] cnt_key_fix,
    output wire        [63:0] cnt_photons_proc,
    output wire        [63:0] cnt_disclosed,
    output wire        [63:0] cnt_key_out,

    output wire signed [15:0] live_score,
    output wire        [31:0] live_n,
    output wire        [31:0] lat_last,
    output wire        [31:0] lat_max,

    output wire               tap_ce,
    output wire               tap_ph_valid,
    output wire               tap_a_bit,
    output wire               tap_a_basis,
    output wire               tap_b_bit,
    output wire               tap_b_basis,

    output wire               led_blk_done,
    output wire               led_sprt_abort,
    output wire               led_sprt_done,

    output wire        [7:0]  jd
);

    reg srst;
    always @(posedge clk) srst <= rst | ctrl_soft_rst;

    wire ce, run, testing;

    wire ph_valid, a_bit, a_basis, b_bit, b_basis;

    wire        t_valid, t_err, blk_start, blk_info_valid, sift_valid, sift_err;
    wire [12:0] blk_sifted, blk_true_err;

    wire        blk_done, sprt_abort, fix_abort;
    wire [15:0] n_sprt, n_fix;

    wire        ph_proc;
    wire [3:0]  pl_drop;

    wire sprt_done, sprt_trunc, fix_done, seq_err, rate_toggle;
    wire [12:0] last_blk_sifted, last_blk_true_err;

    ce_gen #(.FAST_FILL(FAST_FILL)) u_ce (
        .clk(clk), .rst(srst), .mode(ctrl_mode), .step(ctrl_step),
        .rate_div(rate_div), .slow_div(slow_div), .testing(testing), .ce(ce));

    link_top u_link (
        .clk(clk), .rst(srst), .ce(ce), .run(run), .start(ctrl_start),
        .p_noise(p_noise), .f_eve(f_eve),
        .seed_alice(seed0), .seed_eve(seed1), .seed_noise(seed2), .seed_bob(seed3),
        .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis),
        .b_bit(b_bit), .b_basis(b_basis));

    pe_top #(.PC_DELAY(PC_DELAY)) u_pe (
        .clk(clk), .rst(srst), .ce(ce), .run(run), .start(ctrl_start),
        .block_size(block_size), .test_all(ctrl_test_all),
        .sprt_nmax(sprt_nmax), .fix_n(fix_n), .seed_samp(seed4),
        .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis),
        .b_bit(b_bit), .b_basis(b_basis),
        .t_valid(t_valid), .t_err(t_err), .blk_start(blk_start),
        .blk_sifted(blk_sifted), .blk_true_err(blk_true_err), .blk_info_valid(blk_info_valid),
        .sift_valid(sift_valid), .sift_err(sift_err),
        .blk_done(blk_done), .sprt_abort(sprt_abort), .fix_abort(fix_abort),
        .n_sprt(n_sprt), .n_fix(n_fix),
        .ph_proc(ph_proc), .pl_drop(pl_drop),
        .cnt_disclosed(cnt_disclosed), .cnt_key_out(cnt_key_out), .pe_err(st_pe_err),
        .testing(testing));

    dec_top u_dec (
        .clk(clk), .rst(srst), .ce(ce),
        .start(ctrl_start), .stop(ctrl_stop), .curtail_en(ctrl_curtail_en),
        .num_blocks(num_blocks),
        .sprt_inc_err(sprt_inc_err), .sprt_inc_ok(sprt_inc_ok),
        .sprt_thr_a(sprt_thr_a), .sprt_thr_b(sprt_thr_b), .sprt_nmax(sprt_nmax),
        .fix_n(fix_n), .fix_c(fix_c),
        .t_valid(t_valid), .t_err(t_err), .blk_start(blk_start),
        .blk_sifted(blk_sifted), .blk_true_err(blk_true_err), .blk_info_valid(blk_info_valid),
        .sift_valid(sift_valid), .sift_err(sift_err),
        .blk_done(blk_done), .sprt_abort(sprt_abort), .fix_abort(fix_abort),
        .n_sprt(n_sprt), .n_fix(n_fix),
        .live_score(live_score), .sprt_done(sprt_done), .sprt_trunc(sprt_trunc),
        .fix_done(fix_done),
        .busy(run), .run_done(st_done),
        .last_sprt_abort(st_last_sprt_abort), .last_fix_abort(st_last_fix_abort),
        .last_trunc(st_last_trunc), .seq_err(seq_err),
        .cnt_sifted(cnt_sifted), .cnt_sifted_errs(cnt_sifted_errs),
        .cnt_blocks_done(cnt_blocks_done),
        .cnt_sum_n_sprt(cnt_sum_n_sprt), .cnt_sum_n_fix(cnt_sum_n_fix),
        .cnt_abort_sprt(cnt_abort_sprt), .cnt_abort_fix(cnt_abort_fix),
        .cnt_trunc_sprt(cnt_trunc_sprt), .cnt_key_sprt(cnt_key_sprt), .cnt_key_fix(cnt_key_fix),
        .last_blk_sifted(last_blk_sifted), .last_blk_true_err(last_blk_true_err));

    perf_mon #(.ND(4), .RT_LOG2(20)) u_perf (
        .clk(clk), .rst(srst), .clr(ctrl_start), .ce(ce), .busy(run),
        .ph_valid(ph_valid), .ph_proc(ph_proc), .drop(pl_drop),
        .blk_start(blk_start), .blk_done(blk_done),
        .cycles(cnt_cycles), .photons_in(cnt_photons_in), .photons_proc(cnt_photons_proc),
        .pl_dropped(cnt_pl_dropped), .pl_drop_flag(st_pl_drop_flag),
        .rate_toggle(rate_toggle), .lat_last(lat_last), .lat_max(lat_max));

    dbg_pins u_dbg (
        .clk(clk), .rst(srst), .ce(ce), .t_valid(t_valid), .t_err(t_err),
        .sprt_done(sprt_done), .sprt_abort(sprt_abort), .fix_done(fix_done),
        .blk_done(blk_done), .rate_toggle(rate_toggle), .jd(jd));

    assign st_busy       = run;
    assign live_n        = {n_fix, n_sprt};
    assign tap_ce        = ce;
    assign tap_ph_valid  = ph_valid;
    assign tap_a_bit     = a_bit;
    assign tap_a_basis   = a_basis;
    assign tap_b_bit     = b_bit;
    assign tap_b_basis   = b_basis;
    assign led_blk_done  = blk_done;
    assign led_sprt_abort = sprt_abort;
    assign led_sprt_done = sprt_done;

endmodule

`default_nettype wire
