`timescale 1ns / 1ps
`default_nettype none

module sampler #(
    parameter [63:0] ZERO_SUB = 64'hA0761D6478BD642F
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [63:0] seed,
    input  wire [12:0] bs,
    input  wire [10:0] d,
    input  wire        test_all,
    input  wire        consume,
    input  wire        consume_bank,
    output reg  [1:0]  ready,
    input  wire        rd_bank,
    input  wire [9:0]  rd_addr,
    output reg  [11:0] rd_idx
);
    localparam S_IDLE = 3'd0, S_INIT = 3'd1, S_SEL = 3'd2, S_P0 = 3'd3,
               S_P1 = 3'd4, S_A = 3'd5, S_B = 3'd6;

    reg  [2:0]  st;
    reg  [12:0] p_bs;
    reg  [10:0] p_d;
    reg         p_seq;
    reg  [12:0] ip;
    reg  [10:0] i;
    reg         wbank;
    reg  [23:0] r24_q;
    reg  [11:0] j_q;
    reg  [11:0] j_wr;
    reg  [10:0] i1;
    reg  [12:0] bsk1;

    wire [63:0] rnd;
    wire rng_step = (st == S_P0) || (st == S_P1 && p_d > 11'd1) ||
                    (st == S_A && (i1 + 11'd1) < p_d);
    rng64 #(.ZERO_SUB(ZERO_SUB)) u_rng (
        .clk(clk), .rst(rst), .load(start), .seed(seed), .step(rng_step), .rnd(rnd));

    wire [36:0] prod0 = {13'd0, r24_q} * {24'd0, p_bs};
    wire [36:0] prod1 = {13'd0, r24_q} * {24'd0, bsk1};
    wire [12:0] j0    = prod0[36:24];
    wire [12:0] j1    = {2'b00, i1} + prod1[36:24];

    reg  [11:0] pmem [0:4095];
    reg  [11:0] pa_dout, pb_dout;
    reg         pa_we, pb_we;
    reg  [11:0] pa_addr, pb_addr, pa_din, pb_din;
    wire [12:0] ip1 = ip + 13'd1;

    always @* begin
        pa_we = 1'b0; pa_addr = {1'b0, i}; pa_din = 12'd0;
        pb_we = 1'b0; pb_addr = j_q;     pb_din = 12'd0;
        case (st)
            S_INIT: begin
                pa_we = 1'b1;          pa_addr = ip[11:0];  pa_din = ip[11:0];
                pb_we = (ip1 < p_bs);  pb_addr = ip1[11:0]; pb_din = ip1[11:0];
            end
            S_A: begin
                pa_addr = {1'b0, i};   pb_addr = j_q;
            end
            S_B: begin
                pa_we = 1'b1;               pa_addr = {1'b0, i}; pa_din = pb_dout;
                pb_we = (j_wr != {1'b0, i}); pb_addr = j_wr;     pb_din = pa_dout;
            end
            default: ;
        endcase
    end

    always @(posedge clk) begin
        if (pa_we) pmem[pa_addr] <= pa_din;
        pa_dout <= pmem[pa_addr];
    end
    always @(posedge clk) begin
        if (pb_we) pmem[pb_addr] <= pb_din;
        pb_dout <= pmem[pb_addr];
    end

    reg [11:0] imem [0:2047];
    always @(posedge clk)
        if (st == S_B) imem[{wbank, i[9:0]}] <= pb_dout;
    always @(posedge clk)
        rd_idx <= imem[{rd_bank, rd_addr}];

    always @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE; ready <= 2'b00; wbank <= 1'b0;
            p_bs <= 13'd0; p_d <= 11'd0; p_seq <= 1'b0;
            ip <= 13'd0; i <= 11'd0; r24_q <= 24'd0; j_q <= 12'd0; j_wr <= 12'd0;
            i1 <= 11'd1; bsk1 <= 13'h1FFF;
        end else if (start) begin
            p_bs <= bs; p_d <= d; p_seq <= test_all;
            ip <= 13'd0; i <= 11'd0; wbank <= 1'b0; ready <= 2'b00;
            i1 <= 11'd1; bsk1 <= bs - 13'd1;
            st <= S_INIT;
        end else begin
            if (consume && !p_seq) ready[consume_bank] <= 1'b0;
            case (st)
                S_INIT: begin
                    ip <= ip + 13'd2;
                    if (ip + 13'd2 >= p_bs) st <= S_SEL;
                end
                S_SEL:
                    if (p_seq)
                        ready <= 2'b11;
                    else if (!ready[wbank] && p_d != 11'd0) begin
                        i  <= 11'd0;
                        i1 <= 11'd1; bsk1 <= p_bs - 13'd1;
                        st <= S_P0;
                    end
                S_P0: begin
                    r24_q <= rnd[63:40];
                    st    <= S_P1;
                end
                S_P1: begin
                    j_q <= j0[11:0];
                    if (p_d > 11'd1) r24_q <= rnd[63:40];
                    st  <= S_A;
                end
                S_A: begin
                    j_wr <= j_q;
                    if (i1 < p_d) j_q <= j1[11:0];
                    if ((i1 + 11'd1) < p_d) r24_q <= rnd[63:40];
                    st <= S_B;
                end
                S_B: begin
                    if (i1 == p_d) begin
                        ready[wbank] <= 1'b1;
                        wbank <= ~wbank;
                        st    <= S_SEL;
                    end else begin
                        i  <= i1;
                        i1 <= i1 + 11'd1; bsk1 <= bsk1 - 13'd1;
                        st <= S_A;
                    end
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
