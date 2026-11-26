// key_out.v - Bob releases the undisclosed bits of an accepted block (Part 1).
// docs/pe_top_timing.md section 3.4; part1/INTERFACES_change_proposal.md section 5.
//
// On message 5 (the decision, which follows the SPRT):
//   ABORT  -> the block is discarded; the buffer is freed on the next ce edge.
//   ACCEPT -> the block is read word by word (key word and disclosed-mark word
//             together) and output as {key_data, key_keep = ~disclosed}; the
//             kept bits are counted in cnt_key_out (KEY_OUT, 0x198). The buffer
//             is freed after the last word, about W + 3 ce edges later
//             (W = ceil(BLOCK_SIZE / 32)).
// Bits past BLOCK_SIZE in the last word are never kept. Every disclosed bit was
// marked by b_disclose, so the bits kept per block = BLOCK_SIZE - max(n_sprt, n_fix).
// key_valid / key_data / key_keep are the key stream (debug/ILA; no consumer yet).
//
// Timing fix (Part 4, 18 Nov 2026, after the first Vivado run of the full design
// failed at 100 MHz by 1.6 ns on bs -> mask -> popcount -> cnt_key_out):
//   * nw and the last-word mask depend only on BLOCK_SIZE, which is latched on
//     start, so they are registered (ready one clock after bs settles);
//   * the popcount of each released word is registered and added to
//     cnt_key_out one clock later.
// The key stream (key_valid/data/keep) and buffer release are unchanged; only
// KEY_OUT updates one clock later, so its final value is the same.
`timescale 1ns / 1ps
`default_nettype none

module key_out (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire [12:0] bs,           // BLOCK_SIZE (latched)
    input  wire        m5_valid,     // message 5: decision for the block in blk_buf
    input  wire        m5_abort,
    input  wire        blk_buf,
    output wire        active,       // key_out owns Bob's memory port B
    output wire [7:0]  mem_addr,
    input  wire [31:0] mem_data,
    input  wire [31:0] disc_data,
    output reg         free_valid,   // buffer free_buf may be refilled
    output reg         free_buf,
    output reg         key_valid,
    output reg  [31:0] key_data,
    output reg  [31:0] key_keep,
    output reg  [63:0] cnt_key_out
);
    reg       act, issue, rv, rbuf;
    reg [6:0] w, rw;

    // BLOCK_SIZE-only values, registered (bs is constant during a run)
    wire [13:0] bs31   = {1'b0, bs} + 14'd31;
    wire [7:0]  nw_c   = bs31[12:5];                   // words per block (1..128)
    wire [4:0]  rem    = bs[4:0];
    reg  [7:0]  nw, nw_m1;
    reg  [31:0] lmask;                                 // valid bits of the last word
    always @(posedge clk) begin
        nw    <= nw_c;
        nw_m1 <= nw_c - 8'd1;
        lmask <= (rem != 5'd0) ? ((32'd1 << rem) - 32'd1) : 32'hFFFF_FFFF;
    end

    wire        last_w = ({1'b0, rw} == nw_m1);
    wire [31:0] mask   = last_w ? lmask : 32'hFFFF_FFFF;
    wire [31:0] keep   = ~disc_data & mask;

    // balanced popcount (5 adder levels instead of a 32-long chain)
    function [5:0] popcount32(input [31:0] x);
        integer b;
        reg [1:0] p2 [0:15];
        reg [2:0] p4 [0:7];
        reg [3:0] p8 [0:3];
        reg [4:0] p16 [0:1];
        begin
            for (b = 0; b < 16; b = b + 1) p2[b]  = {1'b0, x[2*b]} + {1'b0, x[2*b+1]};
            for (b = 0; b < 8;  b = b + 1) p4[b]  = {1'b0, p2[2*b]} + {1'b0, p2[2*b+1]};
            for (b = 0; b < 4;  b = b + 1) p8[b]  = {1'b0, p4[2*b]} + {1'b0, p4[2*b+1]};
            for (b = 0; b < 2;  b = b + 1) p16[b] = {1'b0, p8[2*b]} + {1'b0, p8[2*b+1]};
            popcount32 = {1'b0, p16[0]} + {1'b0, p16[1]};
        end
    endfunction

    assign active   = act;
    assign mem_addr = {rbuf, w};

    // second stage of the key-bit count
    reg       pc_v;
    reg [5:0] pc_q;

    always @(posedge clk) begin
        if (rst || start) begin
            act <= 1'b0; issue <= 1'b0; rv <= 1'b0; rbuf <= 1'b0; w <= 7'd0; rw <= 7'd0;
            free_valid <= 1'b0; free_buf <= 1'b0;
            key_valid <= 1'b0; key_data <= 32'd0; key_keep <= 32'd0;
            cnt_key_out <= 64'd0; pc_v <= 1'b0; pc_q <= 6'd0;
        end else begin
            pc_v <= 1'b0;
            if (pc_v) cnt_key_out <= cnt_key_out + {58'd0, pc_q};
            if (ce) begin
                free_valid <= 1'b0;
                key_valid  <= 1'b0;
                if (m5_valid) begin
                    if (m5_abort) begin
                        free_valid <= 1'b1;
                        free_buf   <= blk_buf;
                    end else begin
                        act <= 1'b1; issue <= 1'b1; rv <= 1'b0; w <= 7'd0; rbuf <= blk_buf;
                    end
                end else if (act) begin
                    // read word w on this edge; its data is used on the next edge
                    rv <= issue;
                    rw <= w;
                    if (issue) begin
                        if ({1'b0, w} + 8'd1 == nw) issue <= 1'b0;
                        else                        w     <= w + 7'd1;
                    end
                    if (rv) begin
                        key_valid <= 1'b1;
                        key_data  <= mem_data;
                        key_keep  <= keep;
                        pc_q      <= popcount32(keep);
                        pc_v      <= 1'b1;
                        if (last_w) begin
                            act        <= 1'b0;
                            free_valid <= 1'b1;
                            free_buf   <= rbuf;
                        end
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
