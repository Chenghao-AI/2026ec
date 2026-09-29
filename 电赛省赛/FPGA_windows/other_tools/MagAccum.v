`timescale 1ns / 1ps
// =====================================================================
// MagAccum.v  (P1 / 2026_G)
//
// 帧末启动 (start = 1, 1 拍), 依次读 2560 cell 的 (Q1, Q2),
//   Re = Q1 - Q2 * c1    (c1 = cos(2πk/N))
//   Im =       Q2 * c2    (c2 = sin(2πk/N))
//   mag_sq_partial = Re² + Im²
//
// 输出逐拍一个 mag_sq (32-bit), 周期对齐 scan_idx.
// scan_idx 由 SpectrumTop 提供 (简易计数器, 0..2559)
//
// 资源: 每帧一次性计算, 时间换空间, 综合开销极低.
// =====================================================================
module MagAccum #(
    parameter N_CELL = 2560,
    parameter ADDR_W = 12
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  scan_start,
    input  wire [ADDR_W-1:0]     scan_idx,
    input  wire signed [27:0]    scan_Q1,
    input  wire signed [27:0]    scan_Q2,
    input  wire signed [15:0]    cos_k,
    input  wire signed [15:0]    sin_k,
    output reg  signed [31:0]    mag_sq,   // 仅当前有效
    output reg                   valid
);

    // 第 1 级: 减 + 乘
    reg signed [43:0] q2xcos_full, q2xsin_full;
    reg signed [27:0] q2xcos_trunc, q2xsin_trunc;
    always @(posedge clk) begin
        q2xcos_full  <= scan_Q2 * $signed(cos_k);
        q2xsin_full  <= scan_Q2 * $signed(sin_k);
        q2xcos_trunc <= q2xcos_full[27:0];
        q2xsin_trunc <= q2xsin_full[27:0];
    end

    // 第 2 级: Re = Q1 - q2xcos, Im = q2xsin
    reg signed [27:0] re_w, im_w;
    always @(posedge clk) begin
        re_w <= scan_Q1 - q2xcos_trunc;
        im_w <= q2xsin_trunc;
    end

    // 第 3 级: 平方
    reg signed [55:0] sq_re, sq_im;
    reg signed [27:0] re_r, im_r;
    always @(posedge clk) begin
        re_r  <= re_w;
        im_r  <= im_w;
        sq_re <= re_r * re_r;
        sq_im <= im_r * im_r;
    end

    // 第 4 级: 取高 32-bit (避免 56-bit 加法溢出), 输出
    reg signed [55:0] sum_sq;
    always @(posedge clk) begin
        sum_sq <= sq_re + sq_im;
    end
    assign mag_sq = sum_sq[55:24];   // 取高 32-bit, 等价 /2^24

    // valid 跟随 scan_idx (每周期一个有效值, 共 2560 个)
    reg        valid_r;
    reg        started;
    always @(posedge clk) begin
        if (rst) begin
            started <= 0;
            valid_r <= 0;
        end else if (scan_start && !started) begin
            started <= 1;
            valid_r <= 1;
        end else if (started) begin
            valid_r <= 1;
        end else begin
            valid_r <= 0;
        end
    end
    assign valid = valid_r;

endmodule
