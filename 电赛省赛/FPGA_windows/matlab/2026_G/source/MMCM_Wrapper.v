`timescale 1ps / 1ps
`default_nettype none

// ============================================================================
// MMCM_Wrapper — 50 MHz → 8 MHz (CLKOUT0)
// ----------------------------------------------------------------------------
//   CLKFBOUT_MULT_F = 16       VCO = 50 MHz × 16 = 800 MHz
//   CLKOUT0_DIVIDE_F = 100     CLKOUT0 = 800 MHz / 100 = 8 MHz
//   VCO 800 MHz 落在 600~1200 MHz 范围内
//   后续由 DivideBy2_BUFG 模块再做 1 级 2 分频得 4 MHz 采样时钟
// ============================================================================
module MMCM_Wrapper (
    input  wire CLKIN1,
    output wire CLKFBOUT,
    output wire CLKOUT0,
    output wire CLKOUT1,
    input  wire RESETN,
    output wire LOCKED
);

    wire rst_int;
    assign rst_int = ~RESETN;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (16.000),     // VCO = 50 MHz × 16 = 800 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (20.000),     // 50 MHz -> 周期 20 ns
        .CLKOUT0_DIVIDE_F   (100.000),    // CLKOUT0 = 800 / 100 = 8 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .CLKOUT1_DIVIDE     (1),
        .CLKOUT1_DUTY_CYCLE (0.500),
        .CLKOUT1_PHASE      (0.000),
        .CLKOUT2_DIVIDE     (1),
        .CLKOUT3_DIVIDE     (1),
        .CLKOUT4_DIVIDE     (1),
        .CLKOUT5_DIVIDE     (1),
        .CLKOUT6_DIVIDE     (1),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    )
    mmcm_inst (
        .CLKFBOUT  (CLKFBOUT),
        .CLKOUT0   (CLKOUT0),
        .CLKOUT1   (CLKOUT1),
        .LOCKED    (LOCKED),
        .CLKFBIN   (CLKFBOUT),
        .CLKIN1    (CLKIN1),
        .RST       (rst_int),
        .PWRDWN    (1'b0)
    );

endmodule
`default_nettype wire