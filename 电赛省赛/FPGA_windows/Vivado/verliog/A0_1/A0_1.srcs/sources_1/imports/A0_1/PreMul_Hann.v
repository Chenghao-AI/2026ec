`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// PreMul_Hann — 3 级流水加窗模块 (适配 8192 点 FFT)
// ----------------------------------------------------------------------------
//   Stage 1:  x_in 打 1 拍 + HannTable 同步读 coefs
//   Stage 2:  12-bit signed x * 13-bit (zero-padded w) = 24-bit signed
//   Stage 3:  24-bit >>> 12 -> 16-bit signed Q1.15 送 FFT
//
//   与 Xilinx FFT IP 输入位宽严格对齐 (16-bit signed Q1.15)
//
//   8192 点版本:
//     idx 为 13 位 (0..8191)。
//     复用现有 32768 点系数表，每隔 4 点读取一个系数，得到完整的
//     8192 点 Hann 窗；首尾仍为 0，且不再截取 32768 点窗的四分之一。
// ============================================================================
module PreMul_Hann (
    input  wire              clk,
    input  wire              rst,
    input  wire signed [11:0] x_in,
    input  wire [12:0]        idx,
    output wire signed [15:0] x_hanned_16b
);

    // Stage 1: 同步读窗 + 输入打 1 拍
    wire [11:0] w_coef;
    HannTable u_hann_rom (
        .addr  ({idx, 2'b00}),
        .coeff (w_coef)
    );

    reg signed [11:0] x_in_d1 = 12'sd0;
    reg        [11:0] w_reg = 12'd0;
    always @(posedge clk) begin
        if (rst) begin
            x_in_d1 <= 12'sd0;
            w_reg   <= 12'd0;
        end else begin
            x_in_d1 <= x_in;
            w_reg   <= w_coef;
        end
    end

    // Stage 2: 12 x 12 -> 24-bit signed multiply
    wire signed [23:0] mul_raw = $signed(x_in_d1) * $signed({1'b0, w_reg});
    reg signed [23:0] mul_r = 24'sd0;
    always @(posedge clk) begin
        if (rst) mul_r <= 24'sd0;
        else     mul_r <= mul_raw;
    end

    // Stage 3: 24-bit >>> 12 -> 16-bit Q1.15
    reg signed [15:0] x_hanned_r = 16'sd0;
    always @(posedge clk) begin
        if (rst) x_hanned_r <= 16'sd0;
        else     x_hanned_r <= mul_r >>> 12;
    end

    assign x_hanned_16b = x_hanned_r;

endmodule
`default_nettype wire
