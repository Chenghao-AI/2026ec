`timescale 1ns / 1ps

module top (
    input  wire        clk_50m,
    input  wire [11:0] adc_a_data,
    input  wire        adc_a_ora,
    input  wire [11:0] adc_b_data,
    input  wire        adc_b_orb,
    output wire        adc_aclk_p14,
    output wire        adc_bck_t16
);

    wire mmcm_locked;
    wire clk_40m;

    MMCM_Wrapper u_mmcm (
        .CLKIN1    (clk_50m),
        .CLKFBOUT  (),
        .CLKOUT0   (clk_40m),
        .CLKOUT1   (),
        .RESETN    (1'b1),
        .LOCKED    (mmcm_locked)
    );

    assign adc_aclk_p14 = ~clk_40m;
    assign adc_bck_t16  = ~clk_40m;

    DualAdcCaptureTop u_core (
        .io_clk_40m        (clk_40m),
        .io_adc_data_a_raw (adc_a_data),
        .io_adc_data_b_raw (adc_b_data),
        .io_ora_raw        (adc_a_ora),
        .io_orb_raw        (adc_b_orb),
        .io_adc_data_a     (),
        .io_adc_data_b     (),
        .io_ora            (),
        .io_orb            ()
    );

endmodule
