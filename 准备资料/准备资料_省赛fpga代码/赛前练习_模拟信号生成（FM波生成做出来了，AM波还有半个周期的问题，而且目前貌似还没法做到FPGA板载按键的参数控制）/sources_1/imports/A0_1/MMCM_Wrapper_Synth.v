`timescale 1ps / 1ps

module MMCM_Wrapper (
    input  wire CLKIN1,
    input  wire RESETN,
    output wire CLKOUT_DSP,
    output wire CLKOUT_BUF,
    output wire LOCKED
);

    wire mmcm_fb;
    wire mmcm_clk0, mmcm_clk1;

    MMCME2_BASE #(
        .CLKIN1_PERIOD       (20.0),
        .CLKFBOUT_MULT_F     (20.0),
        .CLKOUT0_DIVIDE_F    (8.0),
        .CLKOUT1_DIVIDE      (8),
        .CLKOUT0_DUTY_CYCLE  (0.5),
        .CLKOUT1_DUTY_CYCLE  (0.5),
        .CLKOUT0_PHASE       (0.0),
        .CLKOUT1_PHASE       (0.0),
        .DIVCLK_DIVIDE       (1),
        .STARTUP_WAIT        ("FALSE"),
        .BANDWIDTH           ("OPTIMIZED")
    ) mmcm_inst (
        .CLKIN1        (CLKIN1),
        .CLKFBIN       (mmcm_fb),
        .CLKFBOUT      (mmcm_fb),
        .CLKOUT0       (mmcm_clk0),
        .CLKOUT1       (mmcm_clk1),
        .CLKOUT2       (),
        .CLKOUT3       (),
        .CLKOUT4       (),
        .CLKOUT5       (),
        .CLKOUT6       (),
        .LOCKED        (LOCKED),
        .RST           (~RESETN),
        .PWRDWN        (1'b0)
    );

    BUFG bufg_dsp  (.I(mmcm_clk0), .O(CLKOUT_DSP));
    BUFG bufg_buf  (.I(mmcm_clk1), .O(CLKOUT_BUF));

endmodule