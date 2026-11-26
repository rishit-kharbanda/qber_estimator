// dbg_pins.v - Pmod JD debug outputs (Part 2), INTERFACES.md section 4c
//
// jd[i], registered once so every pin has the same 1-cycle delay and can sit
// in an IOB flip-flop:
//   jd[0] ce          jd[4] sprt_abort
//   jd[1] t_valid     jd[5] fix_done
//   jd[2] t_err       jd[6] blk_done
//   jd[3] sprt_done   jd[7] rate_toggle
// Mapping jd[7:0] to JD1-4, JD7-10 is done in constraints/zedboard.xdc (Part 4).
// Single-cycle pulses are 10 ns wide; trigger the DSO on the edge.
`timescale 1ns / 1ps
`default_nettype none

module dbg_pins (
    input  wire       clk,
    input  wire       rst,
    input  wire       ce,
    input  wire       t_valid,
    input  wire       t_err,
    input  wire       sprt_done,
    input  wire       sprt_abort,
    input  wire       fix_done,
    input  wire       blk_done,
    input  wire       rate_toggle,
    (* IOB = "TRUE" *) output reg [7:0] jd
);

    always @(posedge clk) begin
        if (rst)
            jd <= 8'd0;
        else
            jd <= {rate_toggle, blk_done, fix_done, sprt_abort,
                   sprt_done, t_err & t_valid, t_valid & ce, ce};
    end

endmodule

`default_nettype wire
