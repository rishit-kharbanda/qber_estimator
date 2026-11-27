`timescale 1ns / 1ps
`default_nettype none

module stats (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,
    input  wire        ce,
    input  wire        busy,

    input  wire        sift_valid,
    input  wire        sift_err,

    input  wire        blk_start,
    input  wire        blk_info_valid,
    input  wire [12:0] blk_sifted,
    input  wire [12:0] blk_true_err,

    input  wire        blk_done,
    input  wire        sprt_abort,
    input  wire        sprt_trunc,
    input  wire        fix_abort,
    input  wire [15:0] n_sprt,
    input  wire [15:0] n_fix,

    output reg  [63:0] sifted,
    output reg  [63:0] sifted_errs,
    output reg  [63:0] blocks_done,
    output reg  [63:0] sum_n_sprt,
    output reg  [63:0] sum_n_fix,
    output reg  [63:0] abort_sprt,
    output reg  [63:0] abort_fix,
    output reg  [63:0] trunc_sprt,
    output reg  [63:0] key_sprt,
    output reg  [63:0] key_fix,

    output reg  [12:0] last_blk_sifted,
    output reg  [12:0] last_blk_true_err
);

    reg  [12:0] info_sifted, info_true_err;
    wire        info_now     = ce & blk_info_valid & ~blk_start;
    wire [12:0] cur_sifted   = info_now ? blk_sifted   : info_sifted;
    wire [12:0] cur_true_err = info_now ? blk_true_err : info_true_err;

    wire [16:0] key_s = ({4'd0, cur_sifted} > {1'b0, n_sprt}) ? ({4'd0, cur_sifted} - {1'b0, n_sprt}) : 17'd0;
    wire [16:0] key_f = ({4'd0, cur_sifted} > {1'b0, n_fix})  ? ({4'd0, cur_sifted} - {1'b0, n_fix})  : 17'd0;

    wire count_blk = blk_done & busy;

    always @(posedge clk) begin
        if (rst || clr) begin
            sifted      <= 64'd0;
            sifted_errs <= 64'd0;
            blocks_done <= 64'd0;
            sum_n_sprt  <= 64'd0;
            sum_n_fix   <= 64'd0;
            abort_sprt  <= 64'd0;
            abort_fix   <= 64'd0;
            trunc_sprt  <= 64'd0;
            key_sprt    <= 64'd0;
            key_fix     <= 64'd0;
            info_sifted       <= 13'd0;
            info_true_err     <= 13'd0;
            last_blk_sifted   <= 13'd0;
            last_blk_true_err <= 13'd0;
        end else begin
            if (ce && sift_valid) begin
                sifted <= sifted + 64'd1;
                if (sift_err) sifted_errs <= sifted_errs + 64'd1;
            end
            if (ce && blk_info_valid) begin
                info_sifted   <= blk_sifted;
                info_true_err <= blk_true_err;
            end
            if (blk_done) begin
                last_blk_sifted   <= cur_sifted;
                last_blk_true_err <= cur_true_err;
            end
            if (count_blk) begin
                blocks_done <= blocks_done + 64'd1;
                sum_n_sprt  <= sum_n_sprt + {48'd0, n_sprt};
                sum_n_fix   <= sum_n_fix  + {48'd0, n_fix};
                if (sprt_abort) abort_sprt <= abort_sprt + 64'd1;
                else            key_sprt   <= key_sprt + {47'd0, key_s};
                if (fix_abort)  abort_fix  <= abort_fix + 64'd1;
                else            key_fix    <= key_fix + {47'd0, key_f};
                if (sprt_trunc) trunc_sprt <= trunc_sprt + 64'd1;
            end
        end
    end

endmodule

`default_nettype wire
