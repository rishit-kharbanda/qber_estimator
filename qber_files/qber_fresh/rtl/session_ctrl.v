`timescale 1ns / 1ps
`default_nettype none

module session_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire        stop,
    input  wire [31:0] num_blocks,
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
                in_block <= 1'b0;
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
