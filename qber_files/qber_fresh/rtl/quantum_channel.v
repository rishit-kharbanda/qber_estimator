`timescale 1ns / 1ps
`default_nettype none

module quantum_channel #(
    parameter [63:0] ZS_EVE   = 64'hBF58476D1CE4E5B9,
    parameter [63:0] ZS_NOISE = 64'h94D049BB133111EB
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire [63:0] seed_eve,
    input  wire [63:0] seed_noise,
    input  wire [15:0] p_noise,
    input  wire [15:0] f_eve,
    input  wire        in_valid,
    input  wire        in_bit,
    input  wire        in_basis,
    output reg         out_valid,
    output reg         out_bit,
    output reg         out_basis,
    output reg         eve_hit,
    output reg         noise_hit,
    output reg         e_basis,
    output reg         e_bit
);

    wire [63:0] r2, r3;

    wire        take = ce & in_valid;

    rng64 #(.ZERO_SUB(ZS_EVE)) u_eve (
        .clk(clk), .rst(rst), .load(start), .seed(seed_eve), .step(take), .rnd(r2));
    rng64 #(.ZERO_SUB(ZS_NOISE)) u_noise (
        .clk(clk), .rst(rst), .load(start), .seed(seed_noise), .step(take), .rnd(r3));

    wire eve    = (r2[63:48] < f_eve);
    wire eb     = r2[0];
    wire emeas  = (eb == in_basis) ? in_bit : r2[1];
    wire bit1   = eve ? emeas : in_bit;
    wire basis1 = eve ? eb    : in_basis;

    wire flip   = (r3[63:48] < p_noise);

    always @(posedge clk) begin
        if (rst || start) begin
            out_valid <= 1'b0;
            out_bit   <= 1'b0;
            out_basis <= 1'b0;
            eve_hit   <= 1'b0;
            noise_hit <= 1'b0;
            e_basis   <= 1'b0;
            e_bit     <= 1'b0;
        end else if (ce) begin
            out_valid <= in_valid;
            if (in_valid) begin
                out_bit   <= bit1 ^ flip;
                out_basis <= basis1;
                eve_hit   <= eve;
                noise_hit <= flip;
                e_basis   <= eb;
                e_bit     <= emeas;
            end
        end
    end
endmodule

`default_nettype wire
