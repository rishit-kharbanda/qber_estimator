// a_sift.v - Alice's side of basis sifting (Part 1).
// INTERFACES.md sections 0 and 1; docs/pe_top_timing.md section 3.1.
//
// On the ce edge where pe_top takes a photon (edge e+3 for a photon Alice made
// on edge e), Alice receives Bob's basis over the public channel (message 1)
// and registers keep = (her basis == Bob's basis). keep is message 2 back to
// Bob; on the next ce edge both sides append the bit to their current block.
// Outputs are registers that change only on ce edges.
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
    input  wire bob_basis,     // message 1 (public channel): Bob's basis for this photon
    output reg  s_valid,       // a photon was taken on the last ce edge
    output reg  s_keep,        // message 2: bases matched (valid with s_valid)
    output reg  s_a_bit        // Alice's bit of that photon
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
