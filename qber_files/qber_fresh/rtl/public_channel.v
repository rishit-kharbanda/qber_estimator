// public_channel.v - the authenticated classical channel between Alice and Bob (Part 1).
// docs/pe_top_timing.md sections 3.1 and 3.3; INTERFACES.md section 3.
//
// Messages:
//   1  Bob's basis   -> Alice   (sifting)
//   2  keep          -> Bob     (sifting)
//   3  sample index  -> Bob     (disclosure request)
//   4  Bob's bit     -> Alice   (DISCLOSED: counted in cnt_disclosed)
//   5  decision      -> Bob     (ACCEPT releases the key, ABORT discards the block)
// Messages 1, 2 and 5 are wires. Messages 3 and 4 pass through PC_DELAY
// ce-register stages each (default 0 = wires), to mimic network latency; each
// stage adds 2 ce edges to every disclosed bit (L_rt = 4 + 2 * PC_DELAY), and
// the timing rule becomes (4 + 2*PC_DELAY)*D + ceil(BS/32) + 16 <= BLOCK_SIZE.
// Authentication is assumed, not modelled.
`timescale 1ns / 1ps
`default_nettype none

module public_channel #(
    parameter PC_DELAY = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    // message 1
    input  wire        m1_basis_b,
    output wire        m1_basis_a,
    // message 2
    input  wire        m2_keep_a,
    output wire        m2_keep_b,
    // message 3
    input  wire        m3_valid_a,
    input  wire [11:0] m3_idx_a,
    output wire        m3_valid_b,
    output wire [11:0] m3_idx_b,
    // message 4
    input  wire        m4_valid_b,
    input  wire        m4_bit_b,
    output wire        m4_valid_a,
    output wire        m4_bit_a,
    // message 5
    input  wire        m5_valid_a,
    input  wire        m5_abort_a,
    output wire        m5_valid_b,
    output wire        m5_abort_b,
    // disclosure counter (DISCLOSED, 0x190)
    output reg  [63:0] cnt_disclosed
);
    assign m1_basis_a = m1_basis_b;
    assign m2_keep_b  = m2_keep_a;
    assign m5_valid_b = m5_valid_a;
    assign m5_abort_b = m5_abort_a;

    // every bit Bob puts on the channel is public from then on
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
