`timescale 1ns / 1ps
// =====================================================================
// AdcChaCapture.v  (P1 / 2026_G)
//
// ADC CHA 单通道对齐 + 有符号化
// 输入 adc_data_a_raw (12-bit unsigned, 0..4095)
// 输出 io_data_a_signed (signed 12-bit: -2048..+2047)
// 输出 io_data_a_q22   (signed 24-bit Q2.22 = sign(data - 2048) << 12)
// 输出 io_ora          (1-cycle 延迟后的 overflow flag)
//
// 仅 1 拍 IDDR 风格寄存器 (AD9226 输出与 aclk 同源, register 锁存即可).
// =====================================================================
module AdcChaCapture (
    input  wire         clk,
    input  wire [11:0]  adc_data_a_raw,
    input  wire         ora_raw,
    output wire signed [11:0] io_data_a_signed,
    output wire signed [23:0] io_data_a_q22,
    output wire               io_ora
);
    reg [11:0] r1;
    reg        ora_r1;
    always @(posedge clk) begin
        r1     <= adc_data_a_raw;
        ora_r1 <= ora_raw;
    end
    wire signed [11:0] sub = $signed(r1) - 12'sd2048;
    assign io_data_a_signed = sub;

    // Q2.22: 把 12-bit signed -2048..+2047 放在 24-bit 高 12 位 (低 12 位为小数)
    // 等价于 {{12{sub[11]}}, sub}
    assign io_data_a_q22    = {{12{sub[11]}}, sub};
    assign io_ora           = ora_r1;
endmodule
