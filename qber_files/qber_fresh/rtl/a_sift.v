`timescale 1ns / 1ps
`default_nettype none

module a_sift (
    input  wire clk,
    input  wire rst,
    input  wire ce,
    input  wire start,
    input  wire ph_valid,
    input  wire a_bit,
    input  wire a_basis,
    input  wire bob_basis,
    output reg  s_valid,
    output reg  s_keep,
    output reg  s_a_bit
);
    always @(posedge clk) begin
        if (rst || start) begin
            s_valid <= 1'b0;
            s_keep  <= 1'b0;
            s_a_bit <= 1'b0;
        end else if (ce) begin
            s_valid <= ph_valid;
            if (ph_valid) begin
                s_keep  <= (a_basis == bob_basis);
                s_a_bit <= a_bit;
            end
        end
    end
endmodule

`default_nettype wire
