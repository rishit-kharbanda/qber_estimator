// fixed_engine.v - fixed-sample QBER test, the baseline (Part 2)
//
// Plain:     consume FIX_N bits (202); ABORT if errors > FIX_C (12).
// Curtailed: (curtail = 1) also stop as soon as the outcome is certain:
//              errors > FIX_C                           -> ABORT now
//              errors + (FIX_N - n) <= FIX_C            -> ACCEPT now
// Decision order per bit is the same as qkd_model.py:
//   n == FIX_N first, then curtail-abort, then curtail-accept.
//
// Timing and clr behaviour are identical to sprt_engine.v.
// FIX_N must be >= 1 (the ARM validates it).
`timescale 1ns / 1ps
`default_nettype none

module fixed_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        clr,       // blk_start
    input  wire        in_valid,  // t_valid
    input  wire        err,       // t_err
    input  wire        curtail,   // CTRL.curtail_en
    input  wire [15:0] fix_n,
    input  wire [15:0] fix_c,
    output reg         done,
    output reg         abort,     // valid when done
    output reg  [15:0] n,         // bits consumed this block
    output reg  [15:0] e          // errors seen this block
);

    wire [15:0] n0 = clr ? 16'd0 : n;
    wire [15:0] e0 = clr ? 16'd0 : e;
    wire        d0 = clr ? 1'b0  : done;

    wire [15:0] n1   = n0 + 16'd1;
    wire [15:0] e1   = e0 + {15'd0, err};
    wire        take = in_valid & ~d0;

    // 17-bit sum so it cannot wrap
    wire [16:0] best_case_errs = {1'b0, e1} + {1'b0, fix_n} - {1'b0, n1};

    wire at_n      = (n1 == fix_n);
    wire over_c    = (e1 > fix_c);
    wire cannot_ab = (best_case_errs <= {1'b0, fix_c});

    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0; abort <= 1'b0; n <= 16'd0; e <= 16'd0;
        end else if (ce) begin
            if (clr) begin
                done <= 1'b0; abort <= 1'b0; n <= 16'd0; e <= 16'd0;
            end
            if (take) begin
                n <= n1;
                e <= e1;
                if (at_n) begin
                    done <= 1'b1; abort <= over_c;
                end else if (curtail && over_c) begin
                    done <= 1'b1; abort <= 1'b1;
                end else if (curtail && cannot_ab) begin
                    done <= 1'b1; abort <= 1'b0;
                end
            end
        end
    end

endmodule

`default_nettype wire
