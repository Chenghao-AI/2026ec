`timescale 1ns / 1ps
// =====================================================================
// FrameCounter.v  (P1 / 2026_G)
//
// 14-bit mod 10240 计数器 (因为 10240 = 2^14 内)
// 输出:
//   io_idx            : 0..10239, 当前 sample 索引
//   io_frame_end_pulse: idx == 10239 时拉高 1 拍 (帧末信号)
//   io_first_sample   : idx == 0 时拉高 1 拍 (下一个 cell 清 0)
// =====================================================================
module FrameCounter #(
    parameter N_FRAME = 10240
) (
    input  wire        clk,
    input  wire        rst,
    output reg  [13:0] io_idx,
    output wire        io_frame_end_pulse,
    output wire        io_first_sample
);
    always @(posedge clk) begin
        if (rst) io_idx <= 14'd0;
        else if (io_idx == (N_FRAME-1)) io_idx <= 14'd0;
        else io_idx <= io_idx + 14'd1;
    end
    assign io_frame_end_pulse = (io_idx == 14'd10239);
    assign io_first_sample    = (io_idx == 14'd0);
endmodule
