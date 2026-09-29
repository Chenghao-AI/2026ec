`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// top.v — 仅 CHA 频谱分析顶层 (去除 CHB)
// ----------------------------------------------------------------------------
//   50 MHz 板载晶振 (U18) ──► MMCM (50→8 MHz, MULT=16, DIV=100)
//       │
//       └─► DivideBy2_BUFG (8→4 MHz) ──► 全局 clk_4m
//                                                  │
//                                                  ├─► SpectrumTop (Hann→FrameBuf→FFT→CORDIC→BinSelect)
//                                                  │
//                                                  └─► ODDR 驱动 adc_aclk_p14 (D1=0,D2=1 反相)
//
//   引脚约束保持 R14..P15 (CHA 数据) + P14 (ACLK 输出) + P16 (ORA)
//   探针 ila_probe_* 给 ILA 调试核心 (在 SpectrumTop 内部用 mark_debug)
// ============================================================================
module top (
    input  wire        clk_50m,
    input  wire [11:0] adc_a_data,
    input  wire        adc_a_ora,
    output wire        adc_aclk_p14
);

    wire mmcm_locked;
    wire clk_8m;
    wire clk_4m;

    // ── MMCM 派生 8 MHz ──
    MMCM_Wrapper u_mmcm (
        .CLKIN1    (clk_50m),
        .CLKFBOUT  (),
        .CLKOUT0   (clk_8m),
        .CLKOUT1   (),
        .RESETN    (1'b1),
        .LOCKED    (mmcm_locked)
    );

    // ── 8 → 4 MHz 二分频 ──
    DivideBy2_BUFG u_div2 (
        .clk_8m (clk_8m),
        .clk_4m (clk_4m)
    );

    // ── ADC 采样时钟: ODDR 驱动 P14 (D1=0, D2=1 反相) ──
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT        (1'b0),
        .SRTYPE      ("SYNC")
    ) u_oddr_aclk (
        .Q (adc_aclk_p14),
        .C (clk_4m),
        .CE(1'b1),
        .D1(1'b0),
        .D2(1'b1),
        .R (1'b0),
        .S (1'b0)
    );

    // ── ADC 数据对齐 + 偏移二进制→2's complement ──
    wire signed [11:0] adc_a_signed;
    wire               ora_synced;
    AdcChaCapture u_adc_cap (
        .clk_4m        (clk_4m),
        .adc_a_raw     (adc_a_data),
        .ora_raw       (adc_a_ora),
        .adc_a_signed  (adc_a_signed),
        .ora_out       (ora_synced)
    );
    wire _ora_unused = ^ora_synced;

    // ── 频谱分析顶层 ──
    SpectrumTop u_spec (
        .clk_4m              (clk_4m),
        .rst                 (~mmcm_locked),
        .adc_a_signed        (adc_a_signed)
    );

    // ── ILA 集成 (chipscope 调试) ──
    //   探针映射:
    //     PROBE0 (16-bit) <- ila_probe_mag        : CORDIC |X+jY| 幅度
    //     PROBE1 (13-bit) <- ila_probe_bin        : BinSelect 输出相对 bin (0..8191)
    //     PROBE2 (1-bit)  <- ila_probe_valid      : BinSelect 有效标记
    //     PROBE3 (12-bit) <- ila_probe_adc        : ADC 时域原始码 (用于校准)
    //     PROBE4 (1-bit)  <- ila_probe_frame_end  : 帧结束标记
    ila_0 u_ila_0 (
        .clk                 (clk_4m),
        .probe0              (u_spec.ila_probe_mag),
        .probe1              (u_spec.ila_probe_bin),
        .probe2              (u_spec.ila_probe_valid),
        .probe3              (u_spec.ila_probe_adc),
        .probe4              (u_spec.ila_probe_frame_end)
    );

endmodule
`default_nettype wire