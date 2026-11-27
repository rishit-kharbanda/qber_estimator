`timescale 1ns / 1ps
`default_nettype none

module compare (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire        req_valid,
    input  wire [4:0]  req_sel,
    input  wire [31:0] a_word,
    input  wire        m4_valid,
    input  wire        m4_bit,
    output reg         t_valid,
    output reg         t_err,
    output wire        fire
);
    reg       hold;
    reg [4:0] sel;

    assign fire = ce & hold & m4_valid;

    always @(posedge clk) begin
        if (rst || start) begin
            hold <= 1'b0; sel <= 5'd0; t_valid <= 1'b0; t_err <= 1'b0;
        end else if (ce) begin
            t_valid <= 1'b0;
            if (req_valid) begin
                hold <= 1'b1;
                sel  <= req_sel;
            end
            if (hold && m4_valid) begin
                t_valid <= 1'b1;
                t_err   <= a_word[sel] ^ m4_bit;
                hold    <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
