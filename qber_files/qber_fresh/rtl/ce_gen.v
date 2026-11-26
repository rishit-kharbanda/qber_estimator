// ce_gen.v - clock-enable generator for the whole core (one 100 MHz clock domain).
// Part 1 (Rishit). INTERFACES.md section 0; CTRL.mode, RATE_DIV, SLOW_DIV.
//
//   mode 00 run : one ce every RATE_DIV cycles (0 or 1 = every cycle, full rate)
//   mode 01 slow: one ce every SLOW_DIV cycles (0 or 1 = every cycle)
//   mode 10 step: one ce for each CTRL.step pulse (ce = step delayed one cycle)
//   mode 11     : pause, ce = 0  (proposed; INTERFACES.md leaves 11 undefined)
//
// Fast fill (FAST_FILL = 1, part1/INTERFACES_change_proposal.md section 9):
// in slow and step modes, ce runs at full rate while no block is under test
// (testing = 0, from pe_top), so the ~2 x BLOCK_SIZE photons that fill a block
// pass in microseconds and only the disclosure is slowed down: the SPRT score
// then moves visibly bit by bit in the demo. Run mode (the rate sweeps) and
// pause are unchanged. Everything in the core counts ce edges, so decisions,
// counters and the timing proof are identical; only the wall-clock pacing differs.
// FAST_FILL = 0 gives the plain behaviour.
//
// ce is a register (it fans out to every stage; Vivado replicates it).
// A new divider takes effect after the current count finishes.
`timescale 1ns / 1ps
`default_nettype none

module ce_gen #(
    parameter FAST_FILL = 1
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  mode,
    input  wire        step,
    input  wire [31:0] rate_div,
    input  wire [31:0] slow_div,
    input  wire        testing,      // pe_top: a block is under test
    output reg         ce
);
    reg  [31:0] cnt;                  // cycles left until the next ce
    wire [31:0] div  = (mode == 2'b01) ? slow_div : rate_div;
    wire        fast = (div <= 32'd1);
    wire        fill = (FAST_FILL != 0) && !testing;   // slow/step: full rate while filling

    always @(posedge clk) begin
        if (rst) begin
            ce  <= 1'b0;
            cnt <= 32'd0;
        end else begin
            case (mode)
                2'b10: begin ce <= fill | step; cnt <= 32'd0; end
                2'b11: begin ce <= 1'b0;        cnt <= 32'd0; end
                default:
                    if ((mode == 2'b01 && fill) || fast || cnt == 32'd0) begin
                        ce  <= 1'b1;
                        cnt <= (fast || (mode == 2'b01 && fill)) ? 32'd0 : div - 32'd1;
                    end else begin
                        ce  <= 1'b0;
                        cnt <= cnt - 32'd1;
                    end
            endcase
        end
    end
endmodule

`default_nettype wire
