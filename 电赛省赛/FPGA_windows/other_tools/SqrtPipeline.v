`timescale 1ns / 1ps
// =====================================================================
// SqrtPipeline.v  (P1 / 2026_G)
//
// 32-bit 无符号/有符号输入 → 32-bit 平方根近似 (24-bit 有效)
//
// 用 2 级 Newton-Raphson 迭代:
//
//  Newton 1:  x1 = (x0 + N/x0) / 2   (x0 = LUT 初始估计)
//  Newton 2:  x2 = (x1 + N/x1) / 2   (更精确的二次迭代)
//
// LUT 初始值取 sqrt(N / 2^32) * 65535 即当作 16-bit 初始.
// 综合器在 5 MHz 周期下推断为组合 LUT, 占 ~几百 LUT.
//
// 输出 sqrt_out 为 Q8.24 风格定点 (与 MagAccum 输入对齐).
// =====================================================================
module SqrtPipeline (
    input  wire             clk,
    input  wire             rst,
    input  wire             valid_in,
    input  wire [31:0]      x_in,
    output wire [23:0]      sqrt_out,
    output wire             valid_out
);

    // ---------- x0 初始值 (查表) ----------
    // 用输入 x_in 的高 16 位做索引, 取 65536 项 LUT (vivado 会推断 BRAM)
    reg [15:0] x0;
    reg [15:0] x1;
    reg [15:0] x2;

    wire [15:0] lut_out;
    sqrt_lut u_lut (.x16(x_in[31:16]), .sqrt_est(lut_out));

    // ---------- N/x0 除法 (Vivado 推断除法器) ----------
    // 改用移位 + 减法实现的 "non-restoring sqrt" 更省, 但 5 MHz 周期足够长, 这里用 LZD-divider 即可
    // 为简化, 用 Vivado /: (有符号) 和 / (无符号) 综合器会推断.
    reg [31:0] x_div_x0;
    reg [31:0] x_div_x1;

    always @(posedge clk) begin
        // Stage 1: x0 = LUT
        if (valid_in) x0 <= lut_out;
    end
    always @(posedge clk) begin
        // Stage 2: N/x0
        if (x0 != 0)
            x_div_x0 <= x_in / {x0, 16'h0000};
    end
    always @(posedge clk) begin
        // Stage 2 done: x1
        if (x0 != 0) x1 <= (x0 + x_div_x0[31:16]) >> 1;
    end
    always @(posedge clk) begin
        if (x1 != 0)
            x_div_x1 <= x_in / {x1, 16'h0000};
    end
    always @(posedge clk) begin
        if (x1 != 0) x2 <= (x1 + x_div_x1[31:16]) >> 1;
    end

    assign sqrt_out = {8'h00, x2};
    reg [2:0] valid_pipe;
    always @(posedge clk) begin
        if (rst) valid_pipe <= 3'd0;
        else     valid_pipe <= {valid_pipe[1:0], valid_in};
    end
    assign valid_out = valid_pipe[2];

endmodule

// =====================================================================
// sqrt_lut.v  — 单口 ROM, 65536 项, 16-bit 估计
// 每个地址存 sqrt((addr << 16) / 2^32) * 65535 ≈ sqrt(addr) / 256 * 65535
// 实际由 Vivado 推断为 BRAM, 不需 IP.
// =====================================================================
module sqrt_lut (
    input  wire [15:0] x16,
    output reg  [15:0] sqrt_est
);
    reg [15:0] mem [0:65535];
    initial begin
        $readmemh("sqrt_lut.mem", mem);
    end
    always @* sqrt_est = mem[x16];
endmodule
