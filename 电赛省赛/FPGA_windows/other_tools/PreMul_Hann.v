`timescale 1ns / 1ps
// =====================================================================
// PreMul_Hann.v  (P1 / 2026_G 题频谱分析)
//
// 加汉宁窗: x_hanned = x * w[n]
// x: 24-bit signed Q0.23 (ADC data - 2048 in -2048..2047 range, 左移 12 位)
// w: 12-bit unsigned Q0.12 (0..4095)
// 输出: 24-bit signed (截取高 12 位, 等效 Q12.0 整数, 范围 ±4096)
//
// 流水:
//   级 1: w_reg <= HannTable.io_val (BRAM 读, 1 拍)
//   级 2: x * w_reg (24-bit 截断)
//   级 3: 输出寄存器
//
// 同时输出 sample_idx (=idx_in+1) 供 GoertzelBank 同步判断清 0
// =====================================================================
module PreMul_Hann (
    input  wire              clk,
    input  wire              io_rst,           // 上电 / 帧首
    input  wire [13:0]       io_idx_in,        // 当前 sample 索引, 0..10239
    input  wire signed [23:0] io_x_in,         // 已符号化 + 12-bit 移位
    output wire signed [23:0] io_x_hanned,     // 加窗后
    output wire [13:0]        io_idx_out       // +1 延迟拍
);

    reg [11:0]  w_reg;
    wire [11:0] w_rom_out;
    HannTable u_hann (
        .io_clk (clk),
        .io_idx (io_idx_in),
        .io_val (w_rom_out)
    );
    always @(posedge clk) w_reg <= w_rom_out;

    reg signed [35:0] mul_full;
    reg signed [23:0] mul_trunc;
    always @(posedge clk) begin
        mul_full  <= $signed(io_x_in) * $signed({1'b0, w_reg}); // 24 x 12 unsigned-as-signed
        mul_trunc <= mul_full[23:0];
    end

    // 输出再延迟一拍 (与 FrameCounter 的 sample_idx 同步, 因为清 0 信号 frame_end
    // 在 idx == 10239 时拉高, 而 io_x_hanned 要在下一个 idx == 0 时仍可读)
    reg signed [23:0] x_hanned_r;
    always @(posedge clk) x_hanned_r <= mul_trunc;
    assign io_x_hanned = x_hanned_r;

    reg [13:0] idx_r;
    always @(posedge clk) idx_r <= io_idx_in;
    assign io_idx_out = idx_r;

endmodule
