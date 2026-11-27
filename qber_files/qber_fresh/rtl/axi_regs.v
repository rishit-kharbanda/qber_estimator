`timescale 1ns / 1ps
`default_nettype none

module axi_regs #(
    parameter ADDR_W  = 12,
    parameter N_CNT   = 20,
    parameter [31:0] ID_VALUE      = 32'h5142_4552,
    parameter [31:0] VERSION_VALUE = 32'h0000_0200
)(
    input  wire              s_axi_aclk,
    input  wire              s_axi_aresetn,

    input  wire [ADDR_W-1:0] s_axi_awaddr,
    input  wire [2:0]        s_axi_awprot,
    input  wire              s_axi_awvalid,
    output wire              s_axi_awready,
    input  wire [31:0]       s_axi_wdata,
    input  wire [3:0]        s_axi_wstrb,
    input  wire              s_axi_wvalid,
    output wire              s_axi_wready,
    output wire [1:0]        s_axi_bresp,
    output reg               s_axi_bvalid,
    input  wire              s_axi_bready,
    input  wire [ADDR_W-1:0] s_axi_araddr,
    input  wire [2:0]        s_axi_arprot,
    input  wire              s_axi_arvalid,
    output wire              s_axi_arready,
    output reg  [31:0]       s_axi_rdata,
    output wire [1:0]        s_axi_rresp,
    output reg               s_axi_rvalid,
    input  wire              s_axi_rready,

    output reg               rst_core,
    output reg               cfg_start,
    output reg               cfg_step,
    output reg               cfg_stop,
    output wire [1:0]        cfg_mode,
    output wire              cfg_curtail_en,
    output wire              cfg_test_all,
    output wire              cfg_stream_en,
    output wire [15:0]       cfg_p_noise,
    output wire [15:0]       cfg_f_eve,
    output wire [31:0]       cfg_rate_div,
    output wire [31:0]       cfg_slow_div,
    output wire [12:0]       cfg_block_size,
    output wire [31:0]       cfg_num_blocks,
    output wire [15:0]       cfg_sprt_inc_err,
    output wire [15:0]       cfg_sprt_inc_ok,
    output wire [15:0]       cfg_sprt_thr_a,
    output wire [15:0]       cfg_sprt_thr_b,
    output wire [15:0]       cfg_sprt_nmax,
    output wire [15:0]       cfg_fix_n,
    output wire [15:0]       cfg_fix_c,
    output wire [15:0]       cfg_stream_pkt,
    output wire [319:0]      cfg_seeds,

    input  wire [7:0]        status_in,
    input  wire [N_CNT*64-1:0] cnt_in,
    input  wire [15:0]       live_score,
    input  wire [31:0]       live_n,
    input  wire [31:0]       lat_last,
    input  wire [31:0]       lat_max
);

    localparam I_CTRL = 0,  I_STATUS = 1,  I_P_NOISE = 2,  I_F_EVE = 3,
               I_RATE_DIV = 4, I_SLOW_DIV = 5, I_BLOCK_SIZE = 6, I_NUM_BLOCKS = 7,
               I_INC_ERR = 8, I_INC_OK = 9, I_THR_A = 10, I_THR_B = 11,
               I_NMAX = 12, I_FIX_N = 13, I_FIX_C = 14, I_STREAM_PKT = 15,
               I_SEED0 = 16;

    localparam [31:0] CTRL_PULSE_MASK = 32'h0000_0113;

    reg [31:0] cfg [0:31];
    reg [31:0] scratch;
    reg [31:0] hi_shadow [0:N_CNT-1];

    integer i;

    function [31:0] cfg_default;
        input integer idx;
        begin
            case (idx)
                I_RATE_DIV:   cfg_default = 32'd1;
                I_SLOW_DIV:   cfg_default = 32'd10_000_000;
                I_BLOCK_SIZE: cfg_default = 32'd4096;
                I_INC_ERR:    cfg_default = 32'd333;
                I_INC_OK:     cfg_default = -32'sd22;
                I_THR_A:      cfg_default = 32'd1176;
                I_THR_B:      cfg_default = -32'sd1176;
                I_NMAX:       cfg_default = 32'd404;
                I_FIX_N:      cfg_default = 32'd202;
                I_FIX_C:      cfg_default = 32'd12;
                I_STREAM_PKT: cfg_default = 32'd256;
                16: cfg_default = 32'h1234_ABCD;  17: cfg_default = 32'h0000_0001;
                18: cfg_default = 32'h0BAD_F00D;  19: cfg_default = 32'h0000_0002;
                20: cfg_default = 32'hDEAD_BEEF;  21: cfg_default = 32'h0000_0003;
                22: cfg_default = 32'h1357_9BDF;  23: cfg_default = 32'h0000_0004;
                24: cfg_default = 32'h2468_ACE0;  25: cfg_default = 32'h0000_0005;
                default:      cfg_default = 32'd0;
            endcase
        end
    endfunction

    function [31:0] apply_strb;
        input [31:0] old_v, new_v;
        input [3:0]  strb;
        begin
            apply_strb = { strb[3] ? new_v[31:24] : old_v[31:24],
                           strb[2] ? new_v[23:16] : old_v[23:16],
                           strb[1] ? new_v[15:8]  : old_v[15:8],
                           strb[0] ? new_v[7:0]   : old_v[7:0] };
        end
    endfunction

    wire wr_en = s_axi_awvalid & s_axi_wvalid & ~s_axi_bvalid;
    assign s_axi_awready = wr_en;
    assign s_axi_wready  = wr_en;
    assign s_axi_bresp   = 2'b00;

    wire [ADDR_W-1:0] waddr = s_axi_awaddr;
    wire              w_cfg = (waddr[ADDR_W-1:7] == 0);
    wire [4:0]        w_idx = waddr[6:2];

    always @(posedge s_axi_aclk) begin
        cfg_start <= 1'b0;
        cfg_step  <= 1'b0;
        cfg_stop  <= 1'b0;
        rst_core  <= ~s_axi_aresetn;

        if (~s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            scratch      <= 32'd0;
            for (i = 0; i < 32; i = i + 1)
                cfg[i] <= cfg_default(i);
        end else begin
            if (s_axi_bvalid & s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (wr_en) begin
                s_axi_bvalid <= 1'b1;
                if (w_cfg && w_idx != I_STATUS) begin
                    if (w_idx == I_CTRL) begin
                        cfg[I_CTRL] <= apply_strb(cfg[I_CTRL], s_axi_wdata, s_axi_wstrb) & ~CTRL_PULSE_MASK;
                        if (s_axi_wstrb[0]) begin
                            cfg_start <= s_axi_wdata[0];
                            rst_core  <= s_axi_wdata[1];
                            cfg_step  <= s_axi_wdata[4];
                        end
                        if (s_axi_wstrb[1])
                            cfg_stop  <= s_axi_wdata[8];
                    end else begin
                        cfg[w_idx] <= apply_strb(cfg[w_idx], s_axi_wdata, s_axi_wstrb);
                    end
                end else if (waddr[ADDR_W-1:2] == (12'h1F8 >> 2)) begin
                    scratch <= apply_strb(scratch, s_axi_wdata, s_axi_wstrb);
                end
            end
        end
    end

    assign s_axi_arready = ~s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;

    wire [ADDR_W-1:0] raddr = s_axi_araddr;
    wire [4:0]        r_idx = raddr[6:2];
    wire [4:0]        r_cnt = raddr[7:3];
    wire              r_hi  = raddr[2];
    wire [63:0]       r_cnt_val = (r_cnt < N_CNT) ? cnt_in[{r_cnt, 6'b0} +: 64] : 64'd0;
    wire [8:0]        r_word = raddr[10:2];
    wire              r_is_cnt = (raddr[10:8] == 3'd1) && (r_cnt < N_CNT) &&
                                 (r_cnt != 5'd16) && (r_cnt != 5'd17);

    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= 32'd0;
            for (i = 0; i < N_CNT; i = i + 1)
                hi_shadow[i] <= 32'd0;
        end else begin
            if (s_axi_rvalid & s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (s_axi_arvalid & s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= 32'd0;
                if (raddr[ADDR_W-1:11] == 0) begin
                    if (raddr[10:7] == 4'h0) begin
                        if (r_idx == I_STATUS)
                            s_axi_rdata <= {24'd0, status_in};
                        else
                            s_axi_rdata <= cfg[r_idx];
                    end else if (r_is_cnt) begin
                        if (!r_hi) begin
                            s_axi_rdata      <= r_cnt_val[31:0];
                            hi_shadow[r_cnt] <= r_cnt_val[63:32];
                        end else begin
                            s_axi_rdata      <= hi_shadow[r_cnt];
                        end
                    end else begin
                        case (r_word)
                            9'h060: s_axi_rdata <= {{16{live_score[15]}}, live_score};
                            9'h061: s_axi_rdata <= live_n;
                            9'h062: s_axi_rdata <= lat_last;
                            9'h063: s_axi_rdata <= lat_max;
                            9'h07C: s_axi_rdata <= ID_VALUE;
                            9'h07D: s_axi_rdata <= VERSION_VALUE;
                            9'h07E: s_axi_rdata <= scratch;
                            default: s_axi_rdata <= 32'd0;
                        endcase
                    end
                end
            end
        end
    end

    assign cfg_mode         = cfg[I_CTRL][3:2];
    assign cfg_curtail_en   = cfg[I_CTRL][5];
    assign cfg_test_all     = cfg[I_CTRL][6];
    assign cfg_stream_en    = cfg[I_CTRL][7];
    assign cfg_p_noise      = cfg[I_P_NOISE][15:0];
    assign cfg_f_eve        = cfg[I_F_EVE][15:0];
    assign cfg_rate_div     = cfg[I_RATE_DIV];
    assign cfg_slow_div     = cfg[I_SLOW_DIV];
    assign cfg_block_size   = cfg[I_BLOCK_SIZE][12:0];
    assign cfg_num_blocks   = cfg[I_NUM_BLOCKS];
    assign cfg_sprt_inc_err = cfg[I_INC_ERR][15:0];
    assign cfg_sprt_inc_ok  = cfg[I_INC_OK][15:0];
    assign cfg_sprt_thr_a   = cfg[I_THR_A][15:0];
    assign cfg_sprt_thr_b   = cfg[I_THR_B][15:0];
    assign cfg_sprt_nmax    = cfg[I_NMAX][15:0];
    assign cfg_fix_n        = cfg[I_FIX_N][15:0];
    assign cfg_fix_c        = cfg[I_FIX_C][15:0];
    assign cfg_stream_pkt   = cfg[I_STREAM_PKT][15:0];

    genvar g;
    generate
        for (g = 0; g < 5; g = g + 1) begin : g_seed
            assign cfg_seeds[64*g +: 64] = {cfg[I_SEED0 + 2*g + 1], cfg[I_SEED0 + 2*g]};
        end
    endgenerate

    wire unused_ok = &{1'b0, s_axi_awprot, s_axi_arprot};

endmodule

`default_nettype wire
