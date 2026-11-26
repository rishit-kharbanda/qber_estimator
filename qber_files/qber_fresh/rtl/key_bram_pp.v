// key_bram_pp.v - ping-pong block memory for one side (Part 1).
// docs/pe_top_timing.md section 2.
//
// Two buffers x 128 words x 32 bits (BLOCK_SIZE <= 4096 sifted bits each);
// address = {buffer, word}. Bit i of word w is sifted position 32w + i.
//   Port A (fill):  writes one packed word; with DISC = 1 it also clears the
//                   disclosed marks of that word, so a buffer needs no
//                   clearing pass before it is refilled.
//   Port B (test / release): synchronous read when rd_en; with DISC = 1 the
//                   disclosed-mark word is read from the same address and can
//                   be written back (read-modify-write on two ce edges).
// Fill always targets the buffer that is not being tested or released, so the
// two ports never touch the same address.
// DISC = 0: Alice's memory (data only). DISC = 1: Bob's (data + disclosed marks).
`timescale 1ns / 1ps
`default_nettype none

module key_bram_pp #(
    parameter DISC = 0
) (
    input  wire        clk,
    // port A: fill
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [31:0] wr_data,
    // port B: test / release
    input  wire        rd_en,
    input  wire [7:0]  rd_addr,
    output reg  [31:0] rd_data,
    output wire [31:0] disc_data,
    input  wire        disc_we,
    input  wire [31:0] disc_wdata
);
    reg [31:0] mem [0:255];

    always @(posedge clk)
        if (wr_en) mem[wr_addr] <= wr_data;

    always @(posedge clk)
        if (rd_en) rd_data <= mem[rd_addr];

    generate
        if (DISC != 0) begin : g_disc
            reg [31:0] dmem [0:255];
            reg [31:0] d_q;
            always @(posedge clk)                      // port A: clear on fill
                if (wr_en) dmem[wr_addr] <= 32'd0;
            always @(posedge clk) begin                // port B: mark / read
                if (disc_we) dmem[rd_addr] <= disc_wdata;
                if (rd_en)   d_q <= dmem[rd_addr];
            end
            assign disc_data = d_q;
        end else begin : g_nodisc
            assign disc_data = 32'd0;
            /* verilator lint_off UNUSEDSIGNAL */
            wire unused = disc_we ^ (^disc_wdata);
            /* verilator lint_on UNUSEDSIGNAL */
        end
    endgenerate
endmodule

`default_nettype wire
