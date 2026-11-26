// b_sift.v - Bob's side of basis sifting (Part 1).
// docs/pe_top_timing.md section 3.1.
//
// Bob announces his basis for each photon on the public channel (message 1,
// combinational, taken by Alice on edge e+3) and keeps his measured bit. On
// edge e+4 he appends it to his block if Alice's message 2 says keep (the
// append itself is done by pe_top's fill logic, shared by both sides because
// both follow the same keep sequence).
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
    output wire msg1_basis,    // message 1: Bob's basis for the photon now on the input
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
