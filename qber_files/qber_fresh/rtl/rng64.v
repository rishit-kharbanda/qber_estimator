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
