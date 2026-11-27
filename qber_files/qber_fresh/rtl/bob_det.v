`timescale 1ns / 1ps
`default_nettype none

module bob_det #(
    parameter [63:0] ZERO_SUB = 64'hD6E8FEB86659FD93
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire [63:0] seed,
    input  wire        in_valid,
    input  wire        in_bit,
    input  wire        in_basis,
    output reg         out_valid,
    output reg         b_bit,
    output reg         b_basis
);

    wire [63:0] r4;

    rng64 #(.ZERO_SUB(ZERO_SUB)) u_rng (
        .clk(clk), .rst(rst), .load(start), .seed(seed),
        .step(ce & in_valid), .rnd(r4));

    always @(posedge clk) begin
        if (rst || start) begin
            out_valid <= 1'b0;
            b_bit     <= 1'b0;
            b_basis   <= 1'b0;
        end else if (ce) begin
            out_valid <= in_valid;
            if (in_valid) begin
                b_basis <= r4[0];
                b_bit   <= (r4[0] == in_basis) ? in_bit : r4[1];
            end
        end
    end
endmodule

`default_nettype wire
