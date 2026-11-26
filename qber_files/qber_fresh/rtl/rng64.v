// rng64.v - xorshift64 generator (shifts 13, 7, 17), one step per clock when step = 1.
// Part 1 (Rishit). INTERFACES.md section 0.
//
//   rnd  = xorshift64(state), combinational. It is the random value the user
//          consumes in a cycle where it asserts step; on that edge state <= rnd.
//          So the k-th value used after a load is xorshift64^k(seed), as in
//          model/qkd_model.py (Rng64.next()).
//   load = 1: state <= seed, or ZERO_SUB if seed = 0 (xorshift sticks at 0).
//          load wins over step.
//   rst  : state <= ZERO_SUB (never 0).
// The caller qualifies step with ce, so the generator only advances on ce edges.
`timescale 1ns / 1ps
`default_nettype none

module rng64 #(
    parameter [63:0] ZERO_SUB = 64'h9E3779B97F4A7C15
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        load,
    input  wire [63:0] seed,
    input  wire        step,
    output wire [63:0] rnd
);
    reg  [63:0] state;
    wire [63:0] x1 = state ^ (state << 13);
    wire [63:0] x2 = x1 ^ (x1 >> 7);
    assign      rnd = x2 ^ (x2 << 17);

    always @(posedge clk) begin
        if (rst)
            state <= ZERO_SUB;
        else if (load)
            state <= (seed == 64'd0) ? ZERO_SUB : seed;
        else if (step)
            state <= rnd;
    end
endmodule

`default_nettype wire
