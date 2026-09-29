`timescale 1ns / 1ps
// =====================================================================
// GoertzelCell.v  (P1 / 2026_G 题频谱分析)
//
// 单频点 Goertzel DFT 估计器, 2 级流水 (24-bit 输入已加窗)
//
//  算法 (注释保留数学公式):
//     s[n]   = x[n] + 2*cos(2πk/N) * s[n-1] - s[n-2]
//     s[-1]  = s[-2] = 0
//     N 个 sample 后:
//        Re = Q1 - Q2 * c1        (c1 = cos(2πk/N))
//        Im =       Q2 * c2        (c2 = sin(2πk/N))
//     mag = sqrt(Re² + Im²)
//
//  流水实现:
//   级 1: prod   = $signed(coeff) * s1        // 16 x 28 -> 44-bit
//   级 2: s0_new = $signed(x) + prod - s1     // 28-bit 加减
//   s1_new <= s0   (在 s0 写回时同步延迟一拍)
//
//  资源: ~30 LUT/乘 (LUT 推断) + 状态寄存器, 2560 cell → ~15K LUT @ 5MHz 周期
// =====================================================================
module GoertzelCell #(
    parameter X_WIDTH   = 24,   // 输入 x 数据位宽 (Q2.22 或 Q0.23)
    parameter STATE_W   = 28    // 状态位宽 (signed)
) (
    input  wire              clk,
    input  wire              clear,    // 帧首清 0
    input  wire              advance,  // sample 已就绪
    input  wire signed [X_WIDTH-1:0]  x,
    input  wire signed [15:0]         coeff,  // 2 * cos(2πk/N), Q1.15
    output reg  signed [STATE_W-1:0]  Q1,      // 最终 s0 (frame_end 时为有效值)
    output reg  signed [STATE_W-1:0]  Q2       // 最终 s1
);

    reg signed [STATE_W-1:0] s0, s1;

    // ---- 第 1 级组合: coeff (16) x s1 (28) -------------------------------
    wire signed [43:0] prod_full = $signed(coeff) * s1;
    // 取低 STATE_W 位 (相当于保留中间结果); 对极小 coeff 时无溢出可能
    wire signed [STATE_W-1:0] prod = prod_full[STATE_W-1:0];

    // ---- 第 2 级组合: x + prod - s1 -------------------------------------
    wire signed [STATE_W-1:0] s0_new = $signed(x) + prod - s1;

    // ---- 流水更新 --------------------------------------------------------
    always @(posedge clk) begin
        if (clear) begin
            s0 <= 0;
            s1 <= 0;
        end else if (advance) begin
            s1 <= s0;
            s0 <= s0_new;
        end
    end

    // 将最终状态以 1 拍延迟输出 (与 s0/s1 同源, 但 Q1/Q2 在 frame_end 拉高时被采样)
    always @(posedge clk) begin
        Q1 <= s0;
        Q2 <= s1;
    end

endmodule
