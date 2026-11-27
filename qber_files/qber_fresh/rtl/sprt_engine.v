`timescale 1ns / 1ps
`default_nettype none

module sprt_engine #(
    parameter SW = 18
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               ce,
    input  wire               clr,
    input  wire               in_valid,
    input  wire               err,
    input  wire signed [15:0] inc_err,
    input  wire signed [15:0] inc_ok,
    input  wire signed [15:0] thr_a,
    input  wire signed [15:0] thr_b,
    input  wire        [15:0] nmax,
    output reg                done,
    output reg                abort,
    output reg                trunc,
    output reg         [15:0] n,
    output reg  signed [SW-1:0] score,
    output wire signed [15:0] live_score
);

    wire signed [SW-1:0] inc_err_x = {{(SW-16){inc_err[15]}}, inc_err};
    wire signed [SW-1:0] inc_ok_x  = {{(SW-16){inc_ok[15]}},  inc_ok};
    wire signed [SW-1:0] thr_a_x   = {{(SW-16){thr_a[15]}},   thr_a};
    wire signed [SW-1:0] thr_b_x   = {{(SW-16){thr_b[15]}},   thr_b};

    wire signed [SW-1:0] s0 = clr ? {SW{1'b0}} : score;
    wire        [15:0]   n0 = clr ? 16'd0      : n;
    wire                 d0 = clr ? 1'b0       : done;

    wire signed [SW-1:0] nxt  = s0 + (err ? inc_err_x : inc_ok_x);
    wire        [15:0]   n1   = n0 + 16'd1;
    wire                 take = in_valid & ~d0;

    wire hit_a   = (nxt >= thr_a_x);
    wire hit_b   = (nxt <= thr_b_x);
    wire hit_max = (nmax != 16'd0) && (n1 == nmax);
    wire pos     = (nxt > $signed({SW{1'b0}}));

    always @(posedge clk) begin
        if (rst) begin
            score <= {SW{1'b0}};
            n     <= 16'd0;
            done  <= 1'b0;
            abort <= 1'b0;
            trunc <= 1'b0;
        end else if (ce) begin
            if (clr) begin
                score <= {SW{1'b0}};
                n     <= 16'd0;
                done  <= 1'b0;
                abort <= 1'b0;
                trunc <= 1'b0;
            end
            if (take) begin
                score <= nxt;
                n     <= n1;
                if (hit_a) begin
                    done <= 1'b1; abort <= 1'b1; trunc <= 1'b0;
                end else if (hit_b) begin
                    done <= 1'b1; abort <= 1'b0; trunc <= 1'b0;
                end else if (hit_max) begin
                    done <= 1'b1; abort <= pos;  trunc <= 1'b1;
                end
            end
        end
    end

    localparam signed [SW-1:0] S16_MAX = 32767;
    localparam signed [SW-1:0] S16_MIN = -32768;
    assign live_score = (score > S16_MAX) ? 16'sh7FFF :
                        (score < S16_MIN) ? 16'sh8000 : score[15:0];

endmodule

`default_nettype wire
