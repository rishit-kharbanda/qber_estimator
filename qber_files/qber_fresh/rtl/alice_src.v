// alice_src.v - Alice's source: one random bit and basis per photon (RNG1).
// Part 1 (Rishit). INTERFACES.md sections 0 and 1.
//
//   On every ce edge: out_valid <= run. If run = 1, RNG1 steps and the photon is
//   out_bit = r[0], out_basis = r[1] (basis 0 = +, 1 = x).
//   Outputs are registers that change only on ce edges; a consumer samples
//   them with ce (each photon is seen exactly once).
//   start: loads the seed and empties the stage (not ce-gated).
`timescale 1ns / 1ps
`default_nettype none

module alice_src #(
    parameter [63:0] ZERO_SUB = 64'h9E3779B97F4A7C15
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        run,
    input  wire        start,
    input  wire [63:0] seed,
    output reg         out_valid,
    output reg         out_bit,
    output reg         out_basis
);
    /* verilator lint_off UNUSEDSIGNAL */
    wire [63:0] r;                 // only r[1:0] are used
    /* verilator lint_on UNUSEDSIGNAL */

    rng64 #(.ZERO_SUB(ZERO_SUB)) u_rng (
        .clk(clk), .rst(rst), .load(start), .seed(seed),
        .step(ce & run), .rnd(r));

    always @(posedge clk) begin
        if (rst || start) begin
            out_valid <= 1'b0;
            out_bit   <= 1'b0;
            out_basis <= 1'b0;
        end else if (ce) begin
            out_valid <= run;
            if (run) begin
                out_bit   <= r[0];
                out_basis <= r[1];
            end
        end
    end
endmodule

`default_nettype wire
