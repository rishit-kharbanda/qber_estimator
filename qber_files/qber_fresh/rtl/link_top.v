// link_top.v - emulated BB84 link: alice_src -> quantum_channel -> bob_det.
// Part 1 (Rishit). Output = INTERFACES.md section 1 photon stream (also the
// section 2 tap for photon_packer).
//
// Pipeline: 3 ce-stages. The photon Alice makes on ce edge e is on the outputs
// after ce edge e+2 and is consumed by pe_top (and the packer) on edge e+3.
// Each generator steps once per photon it handles, so the content of photon k
// does not depend on ce timing: it is photon k of model/qkd_model.py.
//
// Contract:
//   * Outputs change only on ce edges; consumers sample with ce & ph_valid.
//   * run = 0 stops Alice; photons already in the pipe still come out.
//   * start (pulse, not ce-gated) loads the four seeds and empties the pipe.
//   * p_noise / f_eve are used live, so they may change during a run
//     (e.g. switching Eve on mid-stream).
// Port list = the one assumed in part2/rtl/qber_core.v.
`timescale 1ns / 1ps
`default_nettype none

module link_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        run,
    input  wire        start,
    input  wire [15:0] p_noise,
    input  wire [15:0] f_eve,
    input  wire [63:0] seed_alice,
    input  wire [63:0] seed_eve,
    input  wire [63:0] seed_noise,
    input  wire [63:0] seed_bob,
    output wire        ph_valid,
    output reg         a_bit,
    output reg         a_basis,
    output wire        b_bit,
    output wire        b_basis
);
    // stage 1: Alice
    wire s1_valid, s1_bit, s1_basis;
    alice_src u_alice (
        .clk(clk), .rst(rst), .ce(ce), .run(run), .start(start), .seed(seed_alice),
        .out_valid(s1_valid), .out_bit(s1_bit), .out_basis(s1_basis));

    // stage 2: channel (Eve, noise); Alice's bits ride alongside
    // s2_eve, s2_noise, s2_e_* are debug nets only (ILA, testbench)
    /* verilator lint_off UNUSEDSIGNAL */
    (* mark_debug = "true" *) wire s2_eve, s2_noise;
    wire s2_e_basis, s2_e_bit;
    /* verilator lint_on UNUSEDSIGNAL */
    wire s2_valid, s2_bit, s2_basis;
    reg  s2_a_bit, s2_a_basis;
    quantum_channel u_ch (
        .clk(clk), .rst(rst), .ce(ce), .start(start),
        .seed_eve(seed_eve), .seed_noise(seed_noise), .p_noise(p_noise), .f_eve(f_eve),
        .in_valid(s1_valid), .in_bit(s1_bit), .in_basis(s1_basis),
        .out_valid(s2_valid), .out_bit(s2_bit), .out_basis(s2_basis),
        .eve_hit(s2_eve), .noise_hit(s2_noise), .e_basis(s2_e_basis), .e_bit(s2_e_bit));

    // stage 3: Bob
    bob_det u_bob (
        .clk(clk), .rst(rst), .ce(ce), .start(start), .seed(seed_bob),
        .in_valid(s2_valid), .in_bit(s2_bit), .in_basis(s2_basis),
        .out_valid(ph_valid), .b_bit(b_bit), .b_basis(b_basis));

    always @(posedge clk) begin
        if (rst || start) begin
            s2_a_bit <= 1'b0; s2_a_basis <= 1'b0;
            a_bit    <= 1'b0; a_basis    <= 1'b0;
        end else if (ce) begin
            if (s1_valid) begin s2_a_bit <= s1_bit;   s2_a_basis <= s1_basis;   end
            if (s2_valid) begin a_bit    <= s2_a_bit; a_basis    <= s2_a_basis; end
        end
    end
endmodule

`default_nettype wire
