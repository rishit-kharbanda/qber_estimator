`timescale 1ns / 1ps
`default_nettype none

module b_disclose (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire        test_buf,
    input  wire        m3_valid,
    input  wire [11:0] m3_idx,
    output wire [7:0]  mem_addr,
    input  wire [31:0] mem_data,
    input  wire [31:0] disc_data,
    output wire        disc_we,
    output wire [31:0] disc_wdata,
    output wire        m4_valid,
    output wire        m4_bit
);
    reg       pend;
    reg [4:0] sel;

    assign mem_addr   = {test_buf, m3_idx[11:5]};
    assign m4_valid   = pend;
    assign m4_bit     = mem_data[sel];
    assign disc_we    = ce & pend;
    assign disc_wdata = disc_data | (32'd1 << sel);

    always @(posedge clk) begin
        if (rst || start) begin
            pend <= 1'b0;
            sel  <= 5'd0;
        end else if (ce) begin
            pend <= m3_valid;
            if (m3_valid) sel <= m3_idx[4:0];
        end
    end
endmodule

`default_nettype wire
