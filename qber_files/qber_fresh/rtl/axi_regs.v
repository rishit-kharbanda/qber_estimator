// axi_regs.v - AXI4-Lite register file for the QBER estimator.
// Implements INTERFACES.md section 5 (Part 4).
//
//  * 0x000-0x07C : configuration words (RW, except STATUS at 0x004 which is RO)
//  * 0x100-0x1EC : 64-bit counters as LO/HI pairs at 0x100 + 8k; reading LO
//                  latches HI. k = 16, 17 (0x180-0x18C) are not counters:
//  * 0x180-0x18C : LIVE_SCORE, LIVE_N, LAT_LAST, LAT_MAX (32-bit, RO)
//  * 0x190, 0x198: DISCLOSED, KEY_OUT (counters k = 18, 19; Part 1 proposal)
//  * 0x1F0-0x1F8 : ID / VERSION / SCRATCH  [pending INTERFACES v1.0 proposal]
//
// CTRL pulse bits (start, soft_rst, step, stop) give a one-cycle pulse when
// written as 1 and always read back as 0. CTRL[8] stop is pending the
// INTERFACES v1.0 proposal. All other locations read 0.
//
// Signed fields (SPRT constants) are stored as written (32 bits); the core
// uses bits [15:0] as two's complement. Defaults are sign-extended.
//
// One clock domain; s_axi_aresetn is treated as a synchronous reset.
`timescale 1ns / 1ps
`default_nettype none

module axi_regs #(
    parameter ADDR_W  = 12,
    parameter N_CNT   = 20,             // counters at 0x100 + 8k, k < 20 (k = 16, 17 unused)
    parameter [31:0] ID_VALUE      = 32'h5142_4552,   // "QBER"
    parameter [31:0] VERSION_VALUE = 32'h0000_0200    // v0.2.0 (major.minor.patch, 8 bits each)
)(
    input  wire              s_axi_aclk,
    input  wire              s_axi_aresetn,
    // ---------------- AXI4-Lite slave ----------------
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
    // ---------------- to the core ----------------
    output reg               rst_core,        // sync, active-high: AXI reset or CTRL.soft_rst
    output reg               cfg_start,       // pulses
    output reg               cfg_step,
    output reg               cfg_stop,
    output wire [1:0]        cfg_mode,        // 00 run, 01 slow, 10 step
    output wire              cfg_curtail_en,
    output wire              cfg_test_all,
    output wire              cfg_stream_en,
    output wire [15:0]       cfg_p_noise,
    output wire [15:0]       cfg_f_eve,
    output wire [31:0]       cfg_rate_div,
    output wire [31:0]       cfg_slow_div,
    output wire [12:0]       cfg_block_size,
    output wire [31:0]       cfg_num_blocks,
    output wire [15:0]       cfg_sprt_inc_err,  // s16
    output wire [15:0]       cfg_sprt_inc_ok,   // s16
    output wire [15:0]       cfg_sprt_thr_a,    // s16
    output wire [15:0]       cfg_sprt_thr_b,    // s16
    output wire [15:0]       cfg_sprt_nmax,
    output wire [15:0]       cfg_fix_n,
    output wire [15:0]       cfg_fix_c,
    output wire [15:0]       cfg_stream_pkt,
    output wire [319:0]      cfg_seeds,         // seed n = [64n+63 : 64n], n = 0..4
    // ---------------- from the core ----------------
    input  wire [7:0]        status_in,         // STATUS[7:0], see section 5
    input  wire [N_CNT*64-1:0] cnt_in,          // counter k = [64k+63 : 64k]
    input  wire [15:0]       live_score,        // s16
    input  wire [31:0]       live_n,            // {n_fix, n_sprt}
    input  wire [31:0]       lat_last,          // clock cycles blk_start -> blk_done
    input  wire [31:0]       lat_max
);

    // ------------------------------------------------------------------
    // Word indices of the configuration block (address[6:2])
    // ------------------------------------------------------------------
    localparam I_CTRL = 0,  I_STATUS = 1,  I_P_NOISE = 2,  I_F_EVE = 3,
               I_RATE_DIV = 4, I_SLOW_DIV = 5, I_BLOCK_SIZE = 6, I_NUM_BLOCKS = 7,
               I_INC_ERR = 8, I_INC_OK = 9, I_THR_A = 10, I_THR_B = 11,
               I_NMAX = 12, I_FIX_N = 13, I_FIX_C = 14, I_STREAM_PKT = 15,
               I_SEED0 = 16;                     // 16..25: SEEDn_LO/HI

    localparam [31:0] CTRL_PULSE_MASK = 32'h0000_0113; // start[0], soft_rst[1], step[4], stop[8]

    reg [31:0] cfg [0:31];
    reg [31:0] scratch;
    reg [31:0] hi_shadow [0:N_CNT-1];

    integer i;

    // Reset values (also documented in sw/qber_regs.h)
    function [31:0] cfg_default;
        input integer idx;
        begin
            case (idx)
                I_RATE_DIV:   cfg_default = 32'd1;
                I_SLOW_DIV:   cfg_default = 32'd10_000_000;   // 10 photons/s
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

    // ------------------------------------------------------------------
    // Write channel: accept address and data together, one at a time
    // ------------------------------------------------------------------
    wire wr_en = s_axi_awvalid & s_axi_wvalid & ~s_axi_bvalid;
    assign s_axi_awready = wr_en;
    assign s_axi_wready  = wr_en;
    assign s_axi_bresp   = 2'b00;

    wire [ADDR_W-1:0] waddr = s_axi_awaddr;
    wire              w_cfg = (waddr[ADDR_W-1:7] == 0);       // 0x000-0x07C
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

    // ------------------------------------------------------------------
    // Read channel: registered data, one cycle after the address
    // ------------------------------------------------------------------
    assign s_axi_arready = ~s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;

    wire [ADDR_W-1:0] raddr = s_axi_araddr;
    wire [4:0]        r_idx = raddr[6:2];
    wire [4:0]        r_cnt = raddr[7:3];                    // k for 0x100 + 8k
    wire              r_hi  = raddr[2];
    wire [63:0]       r_cnt_val = (r_cnt < N_CNT) ? cnt_in[{r_cnt, 6'b0} +: 64] : 64'd0;
    wire [8:0]        r_word = raddr[10:2];   // word address within 2 KB
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
                    if (raddr[10:7] == 4'h0) begin                       // 0x000-0x07C
                        if (r_idx == I_STATUS)
                            s_axi_rdata <= {24'd0, status_in};
                        else
                            s_axi_rdata <= cfg[r_idx];
                    end else if (r_is_cnt) begin                                // counters
                        if (!r_hi) begin
                            s_axi_rdata      <= r_cnt_val[31:0];
                            hi_shadow[r_cnt] <= r_cnt_val[63:32];
                        end else begin
                            s_axi_rdata      <= hi_shadow[r_cnt];
                        end
                    end else begin
                        case (r_word)
                            9'h060: s_axi_rdata <= {{16{live_score[15]}}, live_score}; // 0x180
                            9'h061: s_axi_rdata <= live_n;                            // 0x184
                            9'h062: s_axi_rdata <= lat_last;                          // 0x188
                            9'h063: s_axi_rdata <= lat_max;                           // 0x18C
                            9'h07C: s_axi_rdata <= ID_VALUE;                          // 0x1F0
                            9'h07D: s_axi_rdata <= VERSION_VALUE;                     // 0x1F4
                            9'h07E: s_axi_rdata <= scratch;                           // 0x1F8
                            default: s_axi_rdata <= 32'd0;
                        endcase
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Configuration outputs
    // ------------------------------------------------------------------
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

    // unused
    wire unused_ok = &{1'b0, s_axi_awprot, s_axi_arprot};

endmodule

`default_nettype wire
