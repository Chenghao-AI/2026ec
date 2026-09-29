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
    assign CLKFBOUT = 1'b0;
    assign CLKOUT0  = CLKIN1;
    assign CLKOUT1  = CLKIN1;
    assign LOCKED   = 1'b1;
endmodule
`default_nettype wire