`timescale 1ps / 1ps
`default_nettype none

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
        .CLKFBOUT_MULT_F    (20.000),
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (20.000),
        .CLKOUT0_DIVIDE_F   (10.000),     // 100 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .CLKOUT1_DIVIDE     (40),         // 25 MHz 
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
