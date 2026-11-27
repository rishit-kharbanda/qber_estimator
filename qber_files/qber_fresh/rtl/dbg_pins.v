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
