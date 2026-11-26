// photon_packer.v - packs the photon tap into 32-bit AXI-Stream words for the
// ARM (INTERFACES.md section 2, Part 4).
//
//  * Nibble i (bits 4i+3:4i) = {b_basis, b_bit, a_basis, a_bit} of photon i,
//    oldest photon in nibble 0. Eight photons per word.
//  * Never stalls the emulator. A finished word goes into a 2-word buffer
//    (staging + output register); if both are full, the new word is dropped
//    and words_dropped is incremented. A word already on the bus is never
//    withdrawn (AXI-Stream rule).
//  * tlast marks the last word of each packet of pkt_len words
//    (STREAM_PKT; 0 means 256). The packet in progress is also closed with
//    tlast when the stream ends (flush), so the AXI-Stream FIFO in
//    store-and-forward mode always releases the final words of a run.
//    To do this the newest word is held in staging until the next word
//    arrives or the stream ends.
//  * A partial word (fewer than 8 photons) is discarded at the end of a
//    run, and clear (CTRL.start) restarts packing at nibble 0.
//  * words_sent counts words accepted by the FIFO (tvalid & tready).
//    words_sent, words_dropped and drop_flag clear on rst and on clear.
`timescale 1ns / 1ps
`default_nettype none

module photon_packer (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,             // CTRL.stream_en
    input  wire        clear,          // pulse: drop partial word (CTRL.start)
    input  wire        flush,          // pulse: end of stream, close the packet
    input  wire [15:0] pkt_len,        // STREAM_PKT
    // photon tap (same five signals as section 1)
    input  wire        ce,             // photon taken on edges where ce & ph_valid
    input  wire        ph_valid,
    input  wire        a_bit,
    input  wire        a_basis,
    input  wire        b_bit,
    input  wire        b_basis,
    // AXI-Stream master
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    // counters / flags
    output reg  [63:0] words_sent,
    output reg  [63:0] words_dropped,
    output reg         drop_flag       // sticky until rst or clear
);

    wire [3:0]  nib  = {b_basis, b_bit, a_basis, a_bit};
    wire [15:0] plen = (pkt_len == 16'd0) ? 16'd256 : pkt_len;

    reg [27:0] acc;          // nibbles 0..6 of the word being built
    reg [2:0]  cnt;          // next nibble position
    reg [15:0] pkt_cnt;      // words staged in the current packet

    reg [31:0] st_data;  reg st_valid, st_last, st_rel;   // staging
    reg [31:0] out_data; reg out_valid, out_last;         // output register

    wire take     = en & ce & ph_valid & ~clear;
    wire new_word = take & (cnt == 3'd7);
    wire [31:0] word = {nib, acc};
    wire boundary = (pkt_cnt == plen - 16'd1);

    wire out_free = ~out_valid | m_axis_tready;
    // The held word may leave once its tlast is known: at a packet boundary
    // (st_rel), when a successor arrives, or at the end of the stream.
    wire st_go    = st_valid & (st_rel | new_word | flush) & out_free;
    wire st_room  = ~st_valid | st_go;                 // staging can take a new word

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
            // ---- output register ----
            if (out_valid & m_axis_tready) begin
                out_valid  <= 1'b0;
                words_sent <= words_sent + 64'd1;
            end
            // counters and drop flag clear on CTRL.start, like perf_mon (Part 2)
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

            // ---- nibble accumulator ----
            if (clear | ~en) begin
                cnt <= 3'd0;
            end else if (take) begin
                if (cnt != 3'd7)
                    acc[{cnt, 2'b00} +: 4] <= nib;
                cnt <= cnt + 3'd1;
            end

            // ---- staging ----
            if (new_word) begin
                if (st_room) begin
                    st_data  <= word;
                    st_valid <= 1'b1;
                    st_last  <= boundary | flush;
                    st_rel   <= boundary | flush;   // a packet end releases at once
                    pkt_cnt  <= (boundary | flush) ? 16'd0 : pkt_cnt + 16'd1;
                end else begin
                    // staging and output both full: drop the new word
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
