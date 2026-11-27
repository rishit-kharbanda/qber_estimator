`timescale 1ns/1ps

module led_meter #(
    parameter integer W           = 16,
    parameter integer HOLD_CYC    = 50_000_000,
    parameter integer SAFE_ON_LD0 = 1
)(
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst" *)
    input  wire                clk,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input  wire                rst,
    input  wire signed [W-1:0] live_score,
    input  wire signed [W-1:0] thr_a,
    input  wire signed [W-1:0] thr_b,
    input  wire                blk_done,
    input  wire                sprt_abort,
    output reg         [7:0]   led
);

    wire signed [W+1:0] s_ext = live_score;
    wire signed [W+1:0] a_ext = thr_a;
    wire signed [W+1:0] b_ext = thr_b;
    wire signed [W+1:0] step  = (a_ext - b_ext) >>> 3;

    reg signed [W+1:0] bnd [1:7];
    integer k;
    always @(posedge clk)
        for (k = 1; k < 8; k = k + 1)
            bnd[k] <= b_ext + k * step;

    reg [2:0] pos;
    always @* begin
        pos = 3'd0;
        for (k = 1; k < 8; k = k + 1)
            if (s_ext >= bnd[k])
                pos = k[2:0];
    end

    wire [2:0] idx = SAFE_ON_LD0 ? pos : (3'd7 - pos);

    reg               show_dec;
    reg               dec_abort;
    reg        [31:0] hold;
    reg signed [W-1:0] held_score;

    always @(posedge clk) begin
        if (rst) begin
            show_dec   <= 1'b0;
            dec_abort  <= 1'b0;
            hold       <= 32'd0;
            held_score <= {W{1'b0}};
        end else if (blk_done) begin
            show_dec   <= 1'b1;
            dec_abort  <= sprt_abort;
            hold       <= HOLD_CYC;
            held_score <= live_score;
        end else if (show_dec) begin
            if (hold != 0)
                hold <= hold - 1'b1;
            else if (live_score != held_score)
                show_dec <= 1'b0;
        end
    end

    wire [7:0] safe_pat  = SAFE_ON_LD0 ? 8'b0000_1111 : 8'b1111_0000;
    wire [7:0] abort_pat = ~safe_pat;

    always @(posedge clk) begin
        if (rst)
            led <= 8'b0;
        else if (show_dec)
            led <= dec_abort ? abort_pat : safe_pat;
        else
            led <= 8'b0000_0001 << idx;
    end

endmodule
