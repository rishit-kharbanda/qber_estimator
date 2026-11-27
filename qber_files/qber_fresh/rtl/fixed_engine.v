`timescale 1ns / 1ps
`default_nettype none

module fixed_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        clr,
    input  wire        in_valid,
    input  wire        err,
    input  wire        curtail,
    input  wire [15:0] fix_n,
    input  wire [15:0] fix_c,
    output reg         done,
    output reg         abort,
    output reg  [15:0] n,
    output reg  [15:0] e
);

    wire [15:0] n0 = clr ? 16'd0 : n;
    wire [15:0] e0 = clr ? 16'd0 : e;
    wire        d0 = clr ? 1'b0  : done;

    wire [15:0] n1   = n0 + 16'd1;
    wire [15:0] e1   = e0 + {15'd0, err};
    wire        take = in_valid & ~d0;

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
