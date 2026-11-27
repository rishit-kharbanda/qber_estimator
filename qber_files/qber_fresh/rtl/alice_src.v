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

    wire [63:0] r;

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
