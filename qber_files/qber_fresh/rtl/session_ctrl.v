// session_ctrl.v - run control and per-block decision hand-shake (Part 2)
//
// Run level (not ce-gated, so a start/stop pulse from axi_regs is never missed):
//   start            -> busy = 1, done = 0, block count cleared, any block left
//                       open by an earlier stop is forgotten (in_block = 0)
//   stop             -> busy = 0, done = 1 (block under test is abandoned)
//   NUM_BLOCKS != 0  -> after that many decided blocks, busy = 0, done = 1
//   busy is the proposed "run" signal to Part 1: generate photons and start
//   new block tests only while busy = 1.
//
// Block level (ce-qualified, like every stream pulse):
//   blk_start        -> in_block = 1 (the engines clear on the same edge)
//   blk_done         =  ce & in_block & sprt_done & fix_done
//                      (one ce-cycle pulse; it appears one ce-cycle after the
//                      deciding bit). blk_start in the same cycle is allowed:
//                      it closes the old block and opens the new one.
//   last_*           latched on blk_done (STATUS[4:2]).
//   seq_err          sticky: blk_start while a block was still undecided.
//                    Cleared by start.
//
// Fix (v1.1): start now also clears in_block. Before, a stop in the middle of
// a block left in_block = 1, so the first blk_start of the next run raised a
// false seq_err. pe_top resets on start as well, so no block is lost.
`timescale 1ns / 1ps
`default_nettype none

module session_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,        // CTRL.start pulse
    input  wire        stop,         // proposed CTRL.stop pulse
    input  wire [31:0] num_blocks,   // 0 = run until stop
    input  wire        blk_start,
    input  wire        sprt_done,
    input  wire        sprt_abort,
    input  wire        sprt_trunc,
    input  wire        fix_done,
    input  wire        fix_abort,
    output wire        blk_done,
    output reg         busy,
    output reg         done,
    output reg         in_block,
    output reg  [31:0] blocks_run,
    output reg         last_sprt_abort,
    output reg         last_fix_abort,
    output reg         last_trunc,
    output reg         seq_err
);

    assign blk_done = ce & in_block & sprt_done & fix_done;

    wire last_blk = (num_blocks != 32'd0) && (blocks_run + 32'd1 >= num_blocks);

    // Block hand-shake
    always @(posedge clk) begin
        if (rst) begin
            in_block <= 1'b0;
            seq_err  <= 1'b0;
            last_sprt_abort <= 1'b0;
            last_fix_abort  <= 1'b0;
            last_trunc      <= 1'b0;
        end else begin
            if (start) begin
                seq_err  <= 1'b0;
                in_block <= 1'b0;   // forget a block abandoned by stop
            end
            if (ce) begin
                if (blk_start) begin
                    in_block <= 1'b1;
                    if (in_block && !blk_done && !start)
                        seq_err <= 1'b1;
                end else if (blk_done) begin
                    in_block <= 1'b0;
                end
            end
            if (blk_done) begin
                last_sprt_abort <= sprt_abort;
                last_fix_abort  <= fix_abort;
                last_trunc      <= sprt_trunc;
            end
        end
    end

    // Run state
    always @(posedge clk) begin
        if (rst) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            blocks_run <= 32'd0;
        end else if (start) begin
            busy       <= 1'b1;
            done       <= 1'b0;
            blocks_run <= 32'd0;
        end else if (busy) begin
            if (stop) begin
                busy <= 1'b0;
                done <= 1'b1;
            end else if (blk_done) begin
                blocks_run <= blocks_run + 32'd1;
                if (last_blk) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
