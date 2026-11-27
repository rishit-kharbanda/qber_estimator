`timescale 1ns / 1ps
`default_nettype none

module public_channel #(
    parameter PC_DELAY = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,

    input  wire        m1_basis_b,
    output wire        m1_basis_a,

    input  wire        m2_keep_a,
    output wire        m2_keep_b,

    input  wire        m3_valid_a,
    input  wire [11:0] m3_idx_a,
    output wire        m3_valid_b,
    output wire [11:0] m3_idx_b,

    input  wire        m4_valid_b,
    input  wire        m4_bit_b,
    output wire        m4_valid_a,
    output wire        m4_bit_a,

    input  wire        m5_valid_a,
    input  wire        m5_abort_a,
    output wire        m5_valid_b,
    output wire        m5_abort_b,

    output reg  [63:0] cnt_disclosed
);
    assign m1_basis_a = m1_basis_b;
    assign m2_keep_b  = m2_keep_a;
    assign m5_valid_b = m5_valid_a;
    assign m5_abort_b = m5_abort_a;

    always @(posedge clk)
        if (rst || start)          cnt_disclosed <= 64'd0;
        else if (ce && m4_valid_b) cnt_disclosed <= cnt_disclosed + 64'd1;

    generate
        if (PC_DELAY == 0) begin : g_wire
            assign m3_valid_b = m3_valid_a;
            assign m3_idx_b   = m3_idx_a;
            assign m4_valid_a = m4_valid_b;
            assign m4_bit_a   = m4_bit_b;
        end else begin : g_delay
            reg        v3 [0:PC_DELAY-1];
            reg [11:0] i3 [0:PC_DELAY-1];
            reg        v4 [0:PC_DELAY-1];
            reg        b4 [0:PC_DELAY-1];
            integer k;
            always @(posedge clk) begin
                if (rst || start) begin
                    for (k = 0; k < PC_DELAY; k = k + 1) begin
                        v3[k] <= 1'b0; i3[k] <= 12'd0; v4[k] <= 1'b0; b4[k] <= 1'b0;
                    end
                end else if (ce) begin
                    v3[0] <= m3_valid_a; i3[0] <= m3_idx_a;
                    v4[0] <= m4_valid_b; b4[0] <= m4_bit_b;
                    for (k = 1; k < PC_DELAY; k = k + 1) begin
                        v3[k] <= v3[k-1]; i3[k] <= i3[k-1];
                        v4[k] <= v4[k-1]; b4[k] <= b4[k-1];
                    end
                end
            end
            assign m3_valid_b = v3[PC_DELAY-1];
            assign m3_idx_b   = i3[PC_DELAY-1];
            assign m4_valid_a = v4[PC_DELAY-1];
            assign m4_bit_a   = b4[PC_DELAY-1];
        end
    endgenerate
endmodule

`default_nettype wire
