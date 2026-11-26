// sprt_engine.v - Wald SPRT on the disclosed test-bit stream (Part 2)
//
// Integer log-likelihood score, scaled x256 by the ARM:
//   error  -> score += INC_ERR  (default +333)
//   match  -> score += INC_OK   (default  -22)
//   score >= THR_A (+1176) -> ABORT
//   score <= THR_B (-1176) -> ACCEPT
//   n == NMAX (404) without crossing -> truncate: ABORT if score > 0, else ACCEPT
//                                       (a tie at score 0 accepts, as in qkd_model.py)
//   NMAX = 0 means "no cap".
//
// Timing:
//   * All state advances only when ce = 1 (INTERFACES.md section 0).
//   * clr (= blk_start) clears the engine. If in_valid arrives in the same
//     cycle as clr, that bit is the first bit of the new block.
//   * Bits arriving after done are ignored (not counted in n).
//   * done/abort/trunc/n/score are registers: they show the result of the
//     deciding bit in the cycle after that bit.
//
// Score width: SW = 18 bits internally. With 16-bit increments and
// thresholds the score can never leave +/-(2^16), so 18 bits never overflow.
// live_score is the score saturated to s16 for the register map and LEDs.
`timescale 1ns / 1ps
`default_nettype none

module sprt_engine #(
    parameter SW = 18
) (
    input  wire               clk,
    input  wire               rst,       // synchronous, active-high
    input  wire               ce,
    input  wire               clr,       // blk_start: clear for a new block
    input  wire               in_valid,  // t_valid
    input  wire               err,       // t_err
    input  wire signed [15:0] inc_err,
    input  wire signed [15:0] inc_ok,
    input  wire signed [15:0] thr_a,
    input  wire signed [15:0] thr_b,
    input  wire        [15:0] nmax,
    output reg                done,
    output reg                abort,     // valid when done
    output reg                trunc,     // valid when done
    output reg         [15:0] n,         // bits consumed this block
    output reg  signed [SW-1:0] score,
    output wire signed [15:0] live_score
);

    // Sign-extended copies of the 16-bit parameters
    wire signed [SW-1:0] inc_err_x = {{(SW-16){inc_err[15]}}, inc_err};
    wire signed [SW-1:0] inc_ok_x  = {{(SW-16){inc_ok[15]}},  inc_ok};
    wire signed [SW-1:0] thr_a_x   = {{(SW-16){thr_a[15]}},   thr_a};
    wire signed [SW-1:0] thr_b_x   = {{(SW-16){thr_b[15]}},   thr_b};

    // State as seen this cycle (clr wins, so a bit with clr starts the new block)
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

    // Saturate to s16 for LIVE_SCORE and the LED meter
    localparam signed [SW-1:0] S16_MAX = 32767;
    localparam signed [SW-1:0] S16_MIN = -32768;
    assign live_score = (score > S16_MAX) ? 16'sh7FFF :
                        (score < S16_MIN) ? 16'sh8000 : score[15:0];

endmodule

`default_nettype wire
