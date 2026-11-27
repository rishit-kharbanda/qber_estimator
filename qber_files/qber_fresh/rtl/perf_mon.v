`timescale 1ns / 1ps
`default_nettype none

module perf_mon #(
    parameter ND      = 4,
    parameter RT_LOG2 = 20
) (
    input  wire          clk,
    input  wire          rst,
    input  wire          clr,
    input  wire          ce,
    input  wire          busy,
    input  wire          ph_valid,
    input  wire          ph_proc,
    input  wire [ND-1:0] drop,
    input  wire          blk_start,
    input  wire          blk_done,
    output reg  [63:0]   cycles,
    output reg  [63:0]   photons_in,
    output reg  [63:0]   photons_proc,
    output reg  [63:0]   pl_dropped,
    output reg           pl_drop_flag,
    output reg           rate_toggle,
    output reg  [31:0]   lat_last,
    output reg  [31:0]   lat_max
);

    wire [ND-1:0] drop_q   = ce ? drop : {ND{1'b0}};
    wire          any_drop = |drop_q;
    reg  [7:0]    ndrop;
    integer i;
    always @* begin
        ndrop = 8'd0;
        for (i = 0; i < ND; i = i + 1)
            ndrop = ndrop + {7'd0, drop_q[i]};
    end

    reg [RT_LOG2-1:0] rt_cnt;
    reg [31:0]        lat_cnt;
    reg               timing;

    always @(posedge clk) begin
        if (rst || clr) begin
            cycles       <= 64'd0;
            photons_in   <= 64'd0;
            photons_proc <= 64'd0;
            pl_dropped   <= 64'd0;
            pl_drop_flag <= 1'b0;
            rate_toggle  <= 1'b0;
            rt_cnt       <= {RT_LOG2{1'b0}};
            lat_cnt      <= 32'd0;
            lat_last     <= 32'd0;
            lat_max      <= 32'd0;
            timing       <= 1'b0;
        end else begin
            if (busy)
                cycles <= cycles + 64'd1;
            if (ce && ph_valid)
                photons_in <= photons_in + 64'd1;
            if (ce && ph_proc) begin
                photons_proc <= photons_proc + 64'd1;
                rt_cnt <= rt_cnt + 1'b1;
                if (&rt_cnt) rate_toggle <= ~rate_toggle;
            end
            if (any_drop) begin
                pl_dropped   <= pl_dropped + {56'd0, ndrop};
                pl_drop_flag <= 1'b1;
            end

            if (blk_done && timing) begin
                lat_last <= lat_cnt + 32'd1;
                if (lat_cnt + 32'd1 > lat_max) lat_max <= lat_cnt + 32'd1;
            end
            if (ce && blk_start) begin
                timing  <= 1'b1;
                lat_cnt <= 32'd0;
            end else if (blk_done) begin
                timing  <= 1'b0;
            end else if (timing) begin
                lat_cnt <= lat_cnt + 32'd1;
            end
        end
    end

endmodule

`default_nettype wire
