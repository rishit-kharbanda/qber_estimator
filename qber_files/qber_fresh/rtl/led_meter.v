// ============================================================================
// led_meter.v  -  SPRT score meter on the ZedBoard's 8 user LEDs
// Part 3 (User Interface), QBER Estimator, CS G553       (INTERFACES.md 4b)
//
// While a block is being tested:
//   ONE LED marks where live_score sits between the SAFE limit (thr_b) and
//   the ABORT limit (thr_a). The range is cut into 8 equal slots:
//
//        thr_b (SAFE)                                    thr_a (ABORT)
//        | LD0 | LD1 | LD2 | LD3 | LD4 | LD5 | LD6 | LD7 |
//
//   Matches walk the dot toward LD0, errors jump it toward LD7.
//
// When dec_top pulses blk_done:
//   SAFE  -> LD0..LD3 all on        ABORT -> LD4..LD7 all on
//   The decision is shown for at least HOLD_CYC clocks and until the score
//   changes again (so in step mode it stays until the next step).
//
// SAFE_ON_LD0 = 0 mirrors everything (SAFE on LD4..LD7).
// Note: on the ZedBoard, LD0 is the RIGHT-most LED.
// ============================================================================
`timescale 1ns/1ps

module led_meter #(
    parameter integer W           = 16,          // score width (INTERFACES: s16)
    parameter integer HOLD_CYC    = 50_000_000,  // 0.5 s at 100 MHz
    parameter integer SAFE_ON_LD0 = 1
)(
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET rst" *)
    input  wire                clk,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input  wire                rst,          // synchronous, active high
    input  wire signed [W-1:0] live_score,   // from dec_top
    input  wire signed [W-1:0] thr_a,        // ABORT limit, SPRT_THR_A (+1176)
    input  wire signed [W-1:0] thr_b,        // SAFE  limit, SPRT_THR_B (-1176)
    input  wire                blk_done,     // pulse: both engines decided
    input  wire                sprt_abort,   // decision, valid with blk_done
    output reg         [7:0]   led
);

    // ------------------------------------------------------------------
    // 1. Which of the 8 slots is the score in?  (no divider)
    //    slot width = (thr_a - thr_b) / 8, done with a shift.
    //    pos = how many slot boundaries the score has passed (0..7).
    //    Two extra bits stop the subtraction from overflowing.
    // ------------------------------------------------------------------
    wire signed [W+1:0] s_ext = live_score;
    wire signed [W+1:0] a_ext = thr_a;
    wire signed [W+1:0] b_ext = thr_b;
    wire signed [W+1:0] step  = (a_ext - b_ext) >>> 3;

    // The 7 slot boundaries depend only on the limits (set once per run), so
    // they are registered: the score path is then just 7 comparators.
    // (Part 4 timing fix: thr -> boundary -> compare -> LED was 16 logic
    // levels, -0.15 ns at 100 MHz in the full design.)
    reg signed [W+1:0] bnd [1:7];
    integer k;
    always @(posedge clk)
        for (k = 1; k < 8; k = k + 1)
            bnd[k] <= b_ext + k * step;

    reg [2:0] pos;
    always @* begin
        pos = 3'd0;
        for (k = 1; k < 8; k = k + 1)                 // 7 comparators
            if (s_ext >= bnd[k])
                pos = k[2:0];
    end

    wire [2:0] idx = SAFE_ON_LD0 ? pos : (3'd7 - pos);

    // ------------------------------------------------------------------
    // 2. Latch and hold the decision
    // ------------------------------------------------------------------
    reg               show_dec;    // 1 = showing a decision
    reg               dec_abort;   // the decision being shown
    reg        [31:0] hold;        // clocks of minimum display left
    reg signed [W-1:0] held_score; // score when the decision arrived

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
            else if (live_score != held_score)   // a new block has started
                show_dec <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // 3. Drive the LEDs (registered, so they never glitch)
    // ------------------------------------------------------------------
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
