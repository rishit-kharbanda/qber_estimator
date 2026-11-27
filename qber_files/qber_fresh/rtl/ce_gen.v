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
    input  wire        testing,
    output reg         ce
);
    reg  [31:0] cnt;
    wire [31:0] div  = (mode == 2'b01) ? slow_div : rate_div;
    wire        fast = (div <= 32'd1);
    wire        fill = (FAST_FILL != 0) && !testing;

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
