`timescale 1ns / 1ps
`default_nettype none

module pe_top #(
    parameter PC_DELAY = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        run,
    input  wire        start,
    input  wire [12:0] block_size,
    input  wire        test_all,
    input  wire [15:0] sprt_nmax,
    input  wire [15:0] fix_n,
    input  wire [63:0] seed_samp,

    input  wire        ph_valid,
    input  wire        a_bit,
    input  wire        a_basis,
    input  wire        b_bit,
    input  wire        b_basis,

    output wire        t_valid,
    output wire        t_err,
    output reg         blk_start,
    output reg  [12:0] blk_sifted,
    output reg  [12:0] blk_true_err,
    output reg         blk_info_valid,
    output reg         sift_valid,
    output reg         sift_err,

    input  wire        blk_done,
    input  wire        sprt_abort,
    input  wire        fix_abort,
    input  wire [15:0] n_sprt,
    input  wire [15:0] n_fix,

    output reg         ph_proc,
    output wire [3:0]  pl_drop,
    output wire [63:0] cnt_disclosed,
    output wire [63:0] cnt_key_out,
    output reg         pe_err,

    output reg         testing
);

    wire unused_in = fix_abort ^ (^n_sprt) ^ (^n_fix);

    wire [15:0] d16   = (sprt_nmax > fix_n) ? sprt_nmax : fix_n;
    wire [10:0] d_now = (d16 > 16'd1024) ? 11'd1024 : d16[10:0];
    reg  [12:0] p_bs;
    reg  [10:0] p_d;
    reg         p_seq;
    always @(posedge clk) begin
        if (rst) begin
            p_bs <= 13'd4096; p_d <= 11'd404; p_seq <= 1'b0;
        end else if (start) begin
            p_bs <= block_size; p_d <= d_now; p_seq <= test_all;
        end
    end

    wire [31:0] a_word, a_disc_unused, b_word, b_disc, bd_disc_wdata;
    wire [7:0]  bd_addr, ko_addr;
    wire        bd_disc_we;
    wire        free_valid, free_buf;

    wire m1_b, m1_a, m2_b;
    wire as_valid, as_keep, as_bit, bs_valid, bs_bit;

    b_sift u_bsift (
        .clk(clk), .rst(rst), .ce(ce), .start(start),
        .ph_valid(ph_valid), .b_bit(b_bit), .b_basis(b_basis),
        .msg1_basis(m1_b), .s_valid(bs_valid), .s_b_bit(bs_bit));

    a_sift u_asift (
        .clk(clk), .rst(rst), .ce(ce), .start(start),
        .ph_valid(ph_valid), .a_bit(a_bit), .a_basis(a_basis), .bob_basis(m1_a),
        .s_valid(as_valid), .s_keep(as_keep), .s_a_bit(as_bit));

    always @(posedge clk) begin
        if (rst || start) begin
            sift_valid <= 1'b0; sift_err <= 1'b0;
        end else if (ce) begin
            sift_valid <= ph_valid & (a_basis == b_basis);
            sift_err   <= a_bit ^ b_bit;
        end
    end

    wire        m3_valid_b, m4_valid_b, m4_bit_b, m4_valid_a, m4_bit_a, m5_valid_b, m5_abort_b;
    wire [11:0] m3_idx_b;
    reg         req_valid;
    reg  [11:0] req_idx;
    wire        m5_valid, m5_abort;

    public_channel #(.PC_DELAY(PC_DELAY)) u_pc (
        .clk(clk), .rst(rst), .ce(ce), .start(start),
        .m1_basis_b(m1_b), .m1_basis_a(m1_a),
        .m2_keep_a(as_keep), .m2_keep_b(m2_b),
        .m3_valid_a(req_valid), .m3_idx_a(req_idx), .m3_valid_b(m3_valid_b), .m3_idx_b(m3_idx_b),
        .m4_valid_b(m4_valid_b), .m4_bit_b(m4_bit_b), .m4_valid_a(m4_valid_a), .m4_bit_a(m4_bit_a),
        .m5_valid_a(m5_valid), .m5_abort_a(m5_abort), .m5_valid_b(m5_valid_b), .m5_abort_b(m5_abort_b),
        .cnt_disclosed(cnt_disclosed));

    reg  [12:0] wp;
    reg         fill_buf;
    reg  [31:0] pk_a, pk_b;
    reg  [12:0] errc;
    reg  [1:0]  busy;
    reg         full_pend, pend_buf;
    reg  [12:0] pend_terr;

    wire        fill_ok = ~busy[fill_buf];
    wire        app     = ce & as_valid & as_keep & m2_b;
    wire        app_ok  = app & fill_ok;
    wire [4:0]  pos     = wp[4:0];
    wire        last    = (wp == p_bs - 13'd1);
    wire [31:0] pk_a_n  = pk_a | ({31'd0, as_bit} << pos);
    wire [31:0] pk_b_n  = pk_b | ({31'd0, bs_bit} << pos);
    wire        wword   = app_ok & ((pos == 5'd31) | last);
    wire [7:0]  waddr   = {fill_buf, wp[11:5]};
    wire [12:0] errc_n  = errc + {12'd0, as_bit ^ bs_bit};

    localparam T_WAIT = 2'd0, T_GAP = 2'd1, T_CHECK = 2'd2;
    reg         test_buf, idle_q, miss, drop0, drop1;
    reg  [1:0]  tst;
    reg  [10:0] m;
    wire        ko_active, cmp_fire;
    wire [1:0]  samp_ready;
    wire [11:0] samp_idx;

    wire list_ok   = p_seq | samp_ready[pend_buf];
    wire can_start = ce & full_pend & run & ~testing & idle_q & ~ko_active;
    wire do_start  = can_start & list_ok;
    wire in_check  = testing & (tst == T_CHECK);
    wire fin_done  = ce & in_check & blk_done;
    wire fin_err   = ce & in_check & ~blk_done & (m == p_d);
    wire finish    = fin_done | fin_err;
    wire next_req  = ce & in_check & ~blk_done & (m != p_d);
    wire [11:0] first_idx = p_seq ? 12'd0 : samp_idx;
    wire [11:0] next_idx  = p_seq ? {1'b0, m} : samp_idx;

    assign m5_valid = finish;
    assign m5_abort = fin_err | sprt_abort;
    assign pl_drop  = {2'b00, drop1, drop0};

    wire       rd_bank = testing ? test_buf : (full_pend ? pend_buf : fill_buf);
    wire [9:0] rd_addr = testing ? m[9:0] : 10'd0;

    always @(posedge clk) idle_q <= rst ? 1'b0 : ~testing;

    always @(posedge clk) begin
        if (rst || start) begin
            wp <= 13'd0; fill_buf <= 1'b0; pk_a <= 32'd0; pk_b <= 32'd0; errc <= 13'd0;
            busy <= 2'b00; full_pend <= 1'b0; pend_buf <= 1'b0; pend_terr <= 13'd0;
            testing <= 1'b0; test_buf <= 1'b0; tst <= T_WAIT; m <= 11'd0; miss <= 1'b0;
            req_valid <= 1'b0; req_idx <= 12'd0;
            blk_start <= 1'b0; blk_info_valid <= 1'b0; blk_sifted <= 13'd0; blk_true_err <= 13'd0;
            ph_proc <= 1'b0; drop0 <= 1'b0; drop1 <= 1'b0; pe_err <= 1'b0;
        end else if (ce) begin

            req_valid <= 1'b0; blk_start <= 1'b0; blk_info_valid <= 1'b0; drop1 <= 1'b0;

            ph_proc <= as_valid & ~(as_keep & ~fill_ok);
            drop0   <= as_valid &   as_keep & ~fill_ok;

            if (free_valid) busy[free_buf] <= 1'b0;

            if (do_start) begin
                blk_start      <= 1'b1;
                blk_info_valid <= 1'b1;
                blk_sifted     <= p_bs;
                blk_true_err   <= pend_terr;
                testing        <= 1'b1;
                test_buf       <= pend_buf;
                full_pend      <= 1'b0;
                miss           <= 1'b0;
                req_valid      <= 1'b1;
                req_idx        <= first_idx;
                m              <= 11'd1;
                tst            <= T_WAIT;
            end else if (can_start && !miss) begin
                drop1 <= 1'b1;
                miss  <= 1'b1;
            end
            if (testing) begin
                case (tst)
                    T_WAIT:  if (cmp_fire) tst <= T_GAP;
                    T_GAP:   tst <= T_CHECK;
                    T_CHECK:
                        if (finish) begin
                            testing <= 1'b0;
                            if (fin_err) pe_err <= 1'b1;
                        end else if (next_req) begin
                            req_valid <= 1'b1;
                            req_idx   <= next_idx;
                            m         <= m + 11'd1;
                            tst       <= T_WAIT;
                        end
                    default: tst <= T_WAIT;
                endcase
            end

            if (app_ok) begin
                pk_a <= wword ? 32'd0 : pk_a_n;
                pk_b <= wword ? 32'd0 : pk_b_n;
                if (last) begin
                    wp             <= 13'd0;
                    fill_buf       <= ~fill_buf;
                    busy[fill_buf] <= 1'b1;
                    full_pend      <= 1'b1;
                    pend_buf       <= fill_buf;
                    pend_terr      <= errc_n;
                    errc           <= 13'd0;
                end else begin
                    wp   <= wp + 13'd1;
                    errc <= errc_n;
                end
            end
        end
    end

    key_bram_pp #(.DISC(0)) u_akey (
        .clk(clk), .wr_en(wword), .wr_addr(waddr), .wr_data(pk_a_n),
        .rd_en(ce), .rd_addr({test_buf, req_idx[11:5]}), .rd_data(a_word),
        .disc_data(a_disc_unused), .disc_we(1'b0), .disc_wdata(32'd0));

    key_bram_pp #(.DISC(1)) u_bkey (
        .clk(clk), .wr_en(wword), .wr_addr(waddr), .wr_data(pk_b_n),
        .rd_en(ce), .rd_addr(ko_active ? ko_addr : bd_addr), .rd_data(b_word),
        .disc_data(b_disc), .disc_we(bd_disc_we), .disc_wdata(bd_disc_wdata));

    sampler u_samp (
        .clk(clk), .rst(rst), .start(start), .seed(seed_samp),
        .bs(block_size), .d(d_now), .test_all(test_all),
        .consume(finish), .consume_bank(test_buf), .ready(samp_ready),
        .rd_bank(rd_bank), .rd_addr(rd_addr), .rd_idx(samp_idx));

    b_disclose u_bdisc (
        .clk(clk), .rst(rst), .ce(ce), .start(start), .test_buf(test_buf),
        .m3_valid(m3_valid_b), .m3_idx(m3_idx_b),
        .mem_addr(bd_addr), .mem_data(b_word), .disc_data(b_disc),
        .disc_we(bd_disc_we), .disc_wdata(bd_disc_wdata),
        .m4_valid(m4_valid_b), .m4_bit(m4_bit_b));

    compare u_cmp (
        .clk(clk), .rst(rst), .ce(ce), .start(start),
        .req_valid(req_valid), .req_sel(req_idx[4:0]), .a_word(a_word),
        .m4_valid(m4_valid_a), .m4_bit(m4_bit_a),
        .t_valid(t_valid), .t_err(t_err), .fire(cmp_fire));

    (* mark_debug = "true" *) wire        key_valid;
    (* mark_debug = "true" *) wire [31:0] key_data, key_keep;

    key_out u_kout (
        .clk(clk), .rst(rst), .ce(ce), .start(start), .bs(p_bs),
        .m5_valid(m5_valid_b), .m5_abort(m5_abort_b), .blk_buf(test_buf),
        .active(ko_active), .mem_addr(ko_addr), .mem_data(b_word), .disc_data(b_disc),
        .free_valid(free_valid), .free_buf(free_buf),
        .key_valid(key_valid), .key_data(key_data), .key_keep(key_keep),
        .cnt_key_out(cnt_key_out));

    wire unused_mem = ^a_disc_unused;

endmodule

`default_nettype wire
