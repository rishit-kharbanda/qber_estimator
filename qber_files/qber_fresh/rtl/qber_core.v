// qber_core.v - FPGA core top level (Part 2 integration):
//               ce_gen + link_top + pe_top (Part 1) + dec_top + perf_mon + dbg_pins (Part 2)
//
// v1.3: parameter FAST_FILL and the pe_top -> ce_gen wire `testing`
// (part1/INTERFACES_change_proposal.md section 9), internal to the core.
// v1.2: ce_gen and link_top port lists confirmed by Part 1 (rtl/ce_gen.v,
// rtl/link_top.v). pe_top: confirmed plus cnt_disclosed, cnt_key_out, pe_err
// (part1/INTERFACES_change_proposal.md section 1), passed straight through to
// axi_regs as DISCLOSED (0x190), KEY_OUT (0x198) and STATUS[7]
// (part4/INTERFACES_change_proposal.md section 3).
//
// axi_regs.v (Part 4) drives the configuration inputs and reads the outputs.
// Counters are 64-bit buses; axi_regs splits them into LO/HI and latches HI
// when LO is read (INTERFACES.md section 0).
//
// All Part 1 modules are in rtl/ (pe_top and its sub-blocks drafted in the
// Part 2 chat to Part 1's specification; Rishit to review).
// Signals between the parts follow INTERFACES.md sections 1-4; the extra ones
// (run, ph_proc, pl_drop, ctrl_stop, PHOTONS_PROC, latency, led_sprt_done) are
// listed in part2/INTERFACES_change_proposal.md.
`timescale 1ns / 1ps
`default_nettype none

module qber_core #(
    parameter FAST_FILL = 1,    // slow/step modes: fill at full rate, slow only the disclosure
    parameter PC_DELAY  = 0     // public-channel register stages each way (pe_top)
) (
    input  wire               clk,
    input  wire               rst,
    // ---- CTRL (0x000) ----
    input  wire               ctrl_start,      // [0] pulse
    input  wire               ctrl_soft_rst,   // [1] pulse
    input  wire        [1:0]  ctrl_mode,       // [3:2]
    input  wire               ctrl_step,       // [4] pulse
    input  wire               ctrl_curtail_en, // [5]
    input  wire               ctrl_test_all,   // [6]
    input  wire               ctrl_stop,       // proposed [8] pulse
    // ---- configuration ----
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
    input  wire        [63:0] seed0,           // RNG1 Alice
    input  wire        [63:0] seed1,           // RNG2 Eve
    input  wire        [63:0] seed2,           // RNG3 noise
    input  wire        [63:0] seed3,           // RNG4 Bob
    input  wire        [63:0] seed4,           // RNG5 sampler
    // ---- STATUS (0x004) ----
    output wire               st_busy,
    output wire               st_done,
    output wire               st_last_sprt_abort,
    output wire               st_last_fix_abort,
    output wire               st_last_trunc,
    output wire               st_pl_drop_flag,
    output wire               st_pe_err,       // proposed STATUS[7] (Part 1)
    // ---- counters (0x100 ...) ----
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
    output wire        [63:0] cnt_photons_proc, // proposed 0x178
    output wire        [63:0] cnt_disclosed,    // proposed 0x190 (Part 1): bits revealed on the public channel
    output wire        [63:0] cnt_key_out,      // proposed 0x198 (Part 1): bits released as key
    // ---- live values (0x180, 0x184) and proposed latency (0x188, 0x18C) ----
    output wire signed [15:0] live_score,
    output wire        [31:0] live_n,           // {n_fix, n_sprt}
    output wire        [31:0] lat_last,
    output wire        [31:0] lat_max,
    // ---- photon tap to photon_packer (section 2) ----
    output wire               tap_ce,
    output wire               tap_ph_valid,
    output wire               tap_a_bit,
    output wire               tap_a_basis,
    output wire               tap_b_bit,
    output wire               tap_b_basis,
    // ---- led_meter (section 4b) ----
    output wire               led_blk_done,
    output wire               led_sprt_abort,
    output wire               led_sprt_done,    // proposed addition
    // ---- Pmod JD (section 4c) ----
    output wire        [7:0]  jd
);

    // One reset for the whole core: hard reset or CTRL.soft_rst
    reg srst;
    always @(posedge clk) srst <= rst | ctrl_soft_rst;

    wire ce, run, testing;

    // section 1 photon stream
    wire ph_valid, a_bit, a_basis, b_bit, b_basis;
    // section 3 pe_top -> dec_top
    wire        t_valid, t_err, blk_start, blk_info_valid, sift_valid, sift_err;
    wire [12:0] blk_sifted, blk_true_err;
    // section 4 dec_top -> pe_top
    wire        blk_done, sprt_abort, fix_abort;
    wire [15:0] n_sprt, n_fix;
    // proposed Part 1 -> perf_mon
    wire        ph_proc;
    wire [3:0]  pl_drop;
    // engine debug
    wire sprt_done, sprt_trunc, fix_done, seq_err, rate_toggle;
    wire [12:0] last_blk_sifted, last_blk_true_err;

    // ---------------- Part 1 ----------------
    // ce = 1 in run mode, a pulse every RATE_DIV cycles when RATE_DIV > 1,
    // every SLOW_DIV cycles in slow mode, one per step in step mode, none in mode 11.
    // With FAST_FILL, slow and step modes run at full rate while no block is under test.
    ce_gen #(.FAST_FILL(FAST_FILL)) u_ce (
        .clk(clk), .rst(srst), .mode(ctrl_mode), .step(ctrl_step),
        .rate_div(rate_div), .slow_div(slow_div), .testing(testing), .ce(ce));

    // Generates photons only while run = 1; seeds load on start.
    link_top u_link (
        .clk(clk), .rst(srst), .ce(ce), .run(run), .start(ctrl_start),
        .p_noise(p_noise), .f_eve(f_eve),
        .seed_alice(seed0), .seed_eve(seed1), .seed_noise(seed2), .seed_bob(seed3),
        .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis),
        .b_bit(b_bit), .b_basis(b_basis));

    // Starts a new block test only while run = 1.
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

    // ---------------- Part 2 ----------------
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

    // ---------------- outputs ----------------
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
