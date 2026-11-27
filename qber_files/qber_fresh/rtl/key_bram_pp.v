`timescale 1ns / 1ps
`default_nettype none

module key_bram_pp #(
    parameter DISC = 0
) (
    input  wire        clk,

    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [31:0] wr_data,

    input  wire        rd_en,
    input  wire [7:0]  rd_addr,
    output reg  [31:0] rd_data,
    output wire [31:0] disc_data,
    input  wire        disc_we,
    input  wire [31:0] disc_wdata
);
    reg [31:0] mem [0:255];

    always @(posedge clk)
        if (wr_en) mem[wr_addr] <= wr_data;

    always @(posedge clk)
        if (rd_en) rd_data <= mem[rd_addr];

    generate
        if (DISC != 0) begin : g_disc
            reg [31:0] dmem [0:255];
            reg [31:0] d_q;
            always @(posedge clk)
                if (wr_en) dmem[wr_addr] <= 32'd0;
            always @(posedge clk) begin
                if (disc_we) dmem[rd_addr] <= disc_wdata;
                if (rd_en)   d_q <= dmem[rd_addr];
            end
            assign disc_data = d_q;
        end else begin : g_nodisc
            assign disc_data = 32'd0;

            wire unused = disc_we ^ (^disc_wdata);

        end
    endgenerate
endmodule

`default_nettype wire
