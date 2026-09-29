`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// AdcChaCapture — ADC CHA 单通道对齐 + 偏移二进制→2's complement
// ----------------------------------------------------------------------------
//   AD9226 是 12-bit LVCMOS 并行接口, 在每个 ACLK 上升沿输出当前 sample.
//   数据相对 ACLK 的 output latency 典型 7 个周期, 此处做 8 拍对齐
//   (留 1 拍裕度保证 setup/hold 满足).
//
//   AD9226 默认输出为偏移二进制 (offset binary, 0~4095, 2048 = 0 V).
//   数学等价: 2's complement = offset binary MSB 取反, 即 {~adc[11], adc[10:0]}.
//
//   输出:
//     adc_a_signed : signed 12-bit (-2048..+2047)
//     ora_out      : 同步后的 overflow 标志
// ============================================================================
module AdcChaCapture (
    input  wire        clk_4m,
    input  wire [11:0] adc_a_raw,
    input  wire        ora_raw,
    output wire signed [11:0] adc_a_signed,
    output wire        ora_out
);

    reg [11:0] adc_pipe [0:7];
    reg        ora_pipe [0:7];
    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            adc_pipe[i] = 12'd0;
            ora_pipe[i] = 1'b0;
        end
    end
    always @(posedge clk_4m) begin
        adc_pipe[0] <= adc_a_raw;
        ora_pipe[0] <= ora_raw;
        for (i = 1; i < 8; i = i + 1) begin
            adc_pipe[i] <= adc_pipe[i-1];
            ora_pipe[i] <= ora_pipe[i-1];
        end
    end

    // MSB 取反, 偏移二进制 -> 2's complement
    assign adc_a_signed = {~adc_pipe[7][11], adc_pipe[7][10:0]};
    assign ora_out      = ora_pipe[7];

endmodule
`default_nettype wire