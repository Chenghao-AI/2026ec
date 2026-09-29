`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// BinSelect — 32768 点 FFT 输出 bin 选择器 (60 .. 8251 → 相对 0 .. 8191)
// ----------------------------------------------------------------------------
//   输入 bin 域 (15-bit, 0..32767):
//     取 bin_in ∈ [60, 8251] 共 8192 个 bin (覆盖 7.32 kHz .. 1.007 MHz @ fs=4MHz)
//     重新映射为相对索引 0 .. 8191 (13-bit)，便于 ILA 紧凑存储
//
//   对应频率 (Δf = 122.07 Hz @ fs=4MHz / N=32768):
//     bin 60   -> 7.324 kHz   (相对索引 0)
//     bin 8251 -> 1.007 MHz   (相对索引 8191)
//     bin 410  -> ~50 kHz
//     bin 1638 -> ~200 kHz    (200kHz 真实测试点: bin=1638.4 ≈ 1638)
//     bin 8192 -> 1.000 MHz
//
//   注: 采用门控阀值 (≥60 且 ≤8251) 之外的 bin 拉低 valid_out, ILA buffer
//       仅记录这部分有效数据 (降低 BRAM 需求).
// ============================================================================
module BinSelect #(
    parameter BIN_LO    = 15'd60,     // 包含 (起始 bin)
    parameter BIN_HI    = 15'd8251,   // 包含 (终止 bin)
    parameter OUT_WIDTH = 13           // 输出相对 bin 位宽 (0..8191)
)(
    input  wire              clk,
    input  wire              rst,
    input  wire [23:0]       mag_in,
    input  wire [14:0]       bin_in,           // 0..32767, 来自 FFT bin_cnt
    input  wire              mag_in_valid,
    output reg  [23:0]       mag_out    = 24'd0,
    output reg  [OUT_WIDTH-1:0] bin_out = {OUT_WIDTH{1'b0}},
    output reg               valid_out  = 1'b0
);

    // 比较采用组合逻辑，使 bin_in 一旦落在 [BIN_LO, BIN_HI] 即触发
    wire in_range = (bin_in >= BIN_LO) && (bin_in <= BIN_HI);

    always @(posedge clk) begin
        if (rst) begin
            mag_out   <= 24'd0;
            bin_out   <= {OUT_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (mag_in_valid && in_range) begin
            mag_out   <= mag_in;
            bin_out   <= bin_in - BIN_LO;     // 重新映射到相对索引
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
`default_nettype wire
