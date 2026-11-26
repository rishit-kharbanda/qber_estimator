// dec_top.v - decision core (Part 2): SPRT + fixed engine + session control + stats
//
// Interfaces (INTERFACES.md):
//   section 3  inputs from pe_top   (t_valid, t_err, blk_start, blk_info, sift oracle)
//   section 4  outputs to pe_top    (blk_done, sprt_abort, fix_abort, n_sprt, n_fix)
//   section 4b outputs to led_meter (live_score, blk_done, sprt_abort)
//   section 5  counters and status for axi_regs
// Both engines see exactly the same disclosed bits and clear on blk_start.
// blk_done is a one-ce-cycle pulse, one ce-cycle after the bit that completes
// the second decision. Bits that arrive after an engine decided are ignored,
// so n_sprt / n_fix are the authoritative per-method disclosure counts.
`timescale 1ns / 1ps
`default_nettype none

module dec_top (
    input  wire               clk,
    input  wire               rst,          // rst | CTRL.soft_rst
    input  wire               ce,
    // control (axi_regs)
    input  wire               start,        // CTRL.start pulse
    input  wire               stop,         // proposed CTRL.stop pulse
    input  wire               curtail_en,   // CTRL.curtail_en
    input  wire        [31:0] num_blocks,
    input  wire signed [15:0] sprt_inc_err,
    input  wire signed [15:0] sprt_inc_ok,
    input  wire signed [15:0] sprt_thr_a,
    input  wire signed [15:0] sprt_thr_b,
    input  wire        [15:0] sprt_nmax,
    input  wire        [15:0] fix_n,
    input  wire        [15:0] fix_c,
    // from pe_top (section 3)
    input  wire               t_valid,
    input  wire               t_err,
    input  wire               blk_start,
    input  wire        [12:0] blk_sifted,
    input  wire        [12:0] blk_true_err,
    input  wire               blk_info_valid,
    input  wire               sift_valid,
    input  wire               sift_err,
    // to pe_top (section 4)
    output wire               blk_done,
    output wire               sprt_abort,
    output wire               fix_abort,
    output wire        [15:0] n_sprt,
    output wire        [15:0] n_fix,
    // to led_meter (section 4b) and debug
    output wire signed [15:0] live_score,
    output wire               sprt_done,
    output wire               sprt_trunc,
    output wire               fix_done,
    // run state (STATUS) and proposed run signal to Part 1
    output wire               busy,
    output wire               run_done,
    output wire               last_sprt_abort,
    output wire               last_fix_abort,
    output wire               last_trunc,
    output wire               seq_err,
    // counters (section 5)
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
    output wire        [12:0] last_blk_sifted,
    output wire        [12:0] last_blk_true_err
);

    wire signed [17:0] score;
    wire        [15:0] fix_e;
    wire        [31:0] blocks_run;
    wire               in_block;

    sprt_engine #(.SW(18)) u_sprt (
        .clk(clk), .rst(rst), .ce(ce), .clr(blk_start),
        .in_valid(t_valid), .err(t_err),
        .inc_err(sprt_inc_err), .inc_ok(sprt_inc_ok),
        .thr_a(sprt_thr_a), .thr_b(sprt_thr_b), .nmax(sprt_nmax),
        .done(sprt_done), .abort(sprt_abort), .trunc(sprt_trunc),
        .n(n_sprt), .score(score), .live_score(live_score));

    fixed_engine u_fix (
        .clk(clk), .rst(rst), .ce(ce), .clr(blk_start),
        .in_valid(t_valid), .err(t_err), .curtail(curtail_en),
        .fix_n(fix_n), .fix_c(fix_c),
        .done(fix_done), .abort(fix_abort), .n(n_fix), .e(fix_e));

    session_ctrl u_ctrl (
        .clk(clk), .rst(rst), .ce(ce), .start(start), .stop(stop),
        .num_blocks(num_blocks), .blk_start(blk_start),
        .sprt_done(sprt_done), .sprt_abort(sprt_abort), .sprt_trunc(sprt_trunc),
        .fix_done(fix_done), .fix_abort(fix_abort),
        .blk_done(blk_done), .busy(busy), .done(run_done), .in_block(in_block),
        .blocks_run(blocks_run),
        .last_sprt_abort(last_sprt_abort), .last_fix_abort(last_fix_abort),
        .last_trunc(last_trunc), .seq_err(seq_err));

    stats u_stats (
        .clk(clk), .rst(rst), .clr(start), .ce(ce), .busy(busy),
        .sift_valid(sift_valid), .sift_err(sift_err),
        .blk_start(blk_start), .blk_info_valid(blk_info_valid), .blk_sifted(blk_sifted), .blk_true_err(blk_true_err),
        .blk_done(blk_done), .sprt_abort(sprt_abort), .sprt_trunc(sprt_trunc),
        .fix_abort(fix_abort), .n_sprt(n_sprt), .n_fix(n_fix),
        .sifted(cnt_sifted), .sifted_errs(cnt_sifted_errs), .blocks_done(cnt_blocks_done),
        .sum_n_sprt(cnt_sum_n_sprt), .sum_n_fix(cnt_sum_n_fix),
        .abort_sprt(cnt_abort_sprt), .abort_fix(cnt_abort_fix), .trunc_sprt(cnt_trunc_sprt),
        .key_sprt(cnt_key_sprt), .key_fix(cnt_key_fix),
        .last_blk_sifted(last_blk_sifted), .last_blk_true_err(last_blk_true_err));

    // ILA probes: Vivado keeps these nets through synthesis; add them with
    // "Set Up Debug" after synthesis, or with create_debug_core in Tcl.
    (* mark_debug = "true" *) wire        dbg_ce        = ce;
    (* mark_debug = "true" *) wire        dbg_t_valid   = t_valid;
    (* mark_debug = "true" *) wire        dbg_t_err     = t_err;
    (* mark_debug = "true" *) wire        dbg_blk_start = blk_start;
    (* mark_debug = "true" *) wire        dbg_blk_done  = blk_done;
    (* mark_debug = "true" *) wire        dbg_sprt_done = sprt_done;
    (* mark_debug = "true" *) wire        dbg_fix_done  = fix_done;
    (* mark_debug = "true" *) wire [17:0] dbg_score     = score;
    (* mark_debug = "true" *) wire [15:0] dbg_n_sprt    = n_sprt;
    (* mark_debug = "true" *) wire [15:0] dbg_n_fix     = n_fix;
    (* mark_debug = "true" *) wire [15:0] dbg_fix_e     = fix_e;

endmodule

`default_nettype wire
