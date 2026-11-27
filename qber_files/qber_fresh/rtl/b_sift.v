`timescale 1ns / 1ps
`default_nettype none

module b_sift (
    input  wire clk,
    input  wire rst,
    input  wire ce,
    input  wire start,
    input  wire ph_valid,
    input  wire b_bit,
    input  wire b_basis,
    output wire msg1_basis,
    output reg  s_valid,
    output reg  s_b_bit
);
    assign msg1_basis = b_basis;

    always @(posedge clk) begin
        if (rst || start) begin
            s_valid <= 1'b0;
            s_b_bit <= 1'b0;
        end else if (ce) begin
            s_valid <= ph_valid;
            if (ph_valid) s_b_bit <= b_bit;
        end
    end
endmodule

`default_nettype wire
