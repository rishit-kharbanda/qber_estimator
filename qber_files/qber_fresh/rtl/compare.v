// compare.v - Alice compares Bob's disclosed bit with her own (Part 1).
// docs/pe_top_timing.md section 3.3; INTERFACES.md section 3 (t_valid, t_err).
//
// Edge R+1: Alice reads her own word at the requested position (her memory's
//   address is the request she registered on edge R) and holds the bit select.
// When Bob's bit arrives (message 4; edge R+2 with PC_DELAY = 0) she registers
//   t_valid = 1 and t_err = a XOR b for exactly one ce edge.
// fire = the ce edge on which that happens (pe_top's stop-and-wait FSM uses it).
`timescale 1ns / 1ps
`default_nettype none

module compare (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire        req_valid,    // Alice's request (message 3) registered on edge R
    input  wire [4:0]  req_sel,      // bit position within the word
    input  wire [31:0] a_word,       // Alice's key word at the requested position
    input  wire        m4_valid,     // message 4
    input  wire        m4_bit,
    output reg         t_valid,
    output reg         t_err,
    output wire        fire
);
    reg       hold;
    reg [4:0] sel;

    assign fire = ce & hold & m4_valid;

    always @(posedge clk) begin
        if (rst || start) begin
            hold <= 1'b0; sel <= 5'd0; t_valid <= 1'b0; t_err <= 1'b0;
        end else if (ce) begin
            t_valid <= 1'b0;
            if (req_valid) begin
                hold <= 1'b1;
                sel  <= req_sel;
            end
            if (hold && m4_valid) begin
                t_valid <= 1'b1;
                t_err   <= a_word[sel] ^ m4_bit;
                hold    <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
