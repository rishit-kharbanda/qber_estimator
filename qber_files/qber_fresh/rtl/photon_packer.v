`timescale 1ns / 1ps
`default_nettype none

module photon_packer (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire        clear,
    input  wire        flush,
    input  wire [15:0] pkt_len,

    input  wire        ce,
    input  wire        ph_valid,
    input  wire        a_bit,
    input  wire        a_basis,
    input  wire        b_bit,
    input  wire        b_basis,

    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    output reg  [63:0] words_sent,
    output reg  [63:0] words_dropped,
    output reg         drop_flag
);

    wire [3:0]  nib  = {b_basis, b_bit, a_basis, a_bit};
    wire [15:0] plen = (pkt_len == 16'd0) ? 16'd256 : pkt_len;

    reg [27:0] acc;
    reg [2:0]  cnt;
    reg [15:0] pkt_cnt;

    reg [31:0] st_data;  reg st_valid, st_last, st_rel;
    reg [31:0] out_data; reg out_valid, out_last;

    wire take     = en & ce & ph_valid & ~clear;
    wire new_word = take & (cnt == 3'd7);
    wire [31:0] word = {nib, acc};
    wire boundary = (pkt_cnt == plen - 16'd1);

    wire out_free = ~out_valid | m_axis_tready;

    wire st_go    = st_valid & (st_rel | new_word | flush) & out_free;
    wire st_room  = ~st_valid | st_go;

    assign m_axis_tdata  = out_data;
    assign m_axis_tvalid = out_valid;
    assign m_axis_tlast  = out_last;

    always @(posedge clk) begin
        if (rst) begin
            acc <= 28'd0; cnt <= 3'd0; pkt_cnt <= 16'd0;
            st_data <= 32'd0; st_valid <= 1'b0; st_last <= 1'b0; st_rel <= 1'b0;
            out_data <= 32'd0; out_valid <= 1'b0; out_last <= 1'b0;
            words_sent <= 64'd0; words_dropped <= 64'd0; drop_flag <= 1'b0;
        end else begin

            if (out_valid & m_axis_tready) begin
                out_valid  <= 1'b0;
                words_sent <= words_sent + 64'd1;
            end

            if (clear) begin
                words_sent    <= 64'd0;
                words_dropped <= 64'd0;
                drop_flag     <= 1'b0;
            end
            if (st_go) begin
                out_data  <= st_data;
                out_last  <= st_last | flush;
                out_valid <= 1'b1;
                st_valid  <= 1'b0;
            end

            if (clear | ~en) begin
                cnt <= 3'd0;
            end else if (take) begin
                if (cnt != 3'd7)
                    acc[{cnt, 2'b00} +: 4] <= nib;
                cnt <= cnt + 3'd1;
            end

            if (new_word) begin
                if (st_room) begin
                    st_data  <= word;
                    st_valid <= 1'b1;
                    st_last  <= boundary | flush;
                    st_rel   <= boundary | flush;
                    pkt_cnt  <= (boundary | flush) ? 16'd0 : pkt_cnt + 16'd1;
                end else begin

                    words_dropped <= words_dropped + 64'd1;
                    drop_flag     <= 1'b1;
                    if (flush) begin
                        st_last <= 1'b1;
                        st_rel  <= 1'b1;
                    end
                end
            end else if (flush) begin
                pkt_cnt <= 16'd0;
                if (st_valid & ~st_go) begin
                    st_last <= 1'b1;
                    st_rel  <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
