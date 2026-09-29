`timescale 1ns / 1ps

module dac_top (
    input  wire        clk_50m,
    output wire [13:0] cha_data,
    output wire        cha_clk,
    output wire [13:0] chb_data,
    output wire        chb_clk,
    output wire [3:0]  status_led
);

    reg [3:0] rst_cnt = 4'h0;
    reg       rst_reg = 1'b1;
    always @(posedge clk_50m) begin
        if (rst_cnt[3] == 1'b0) begin
            rst_cnt <= rst_cnt + 4'h1;
            rst_reg <= 1'b1;
        end else begin
            rst_reg <= 1'b0;
        end
    end
    wire dac_rst = rst_reg;

    wire clk_dac;
    wire mmcm_locked;
    MMCM_Wrapper u_mmcm (
        .CLKIN1   (clk_50m),
        .CLKFBOUT (),
        .CLKOUT0  (clk_dac),
        .CLKOUT1  (),
        .RESETN   (1'b1),
        .LOCKED   (mmcm_locked)
    );

    wire [3:0] status_raw;
    AD9764_Controller u_dac (
        .clock      (clk_dac),
        .reset      (dac_rst),
        .io_chaData (cha_data),
        .io_chbData (chb_data),
        .io_chaClk  (cha_clk),
        .io_chbClk  (chb_clk),
        .io_statusLed(status_raw)
    );

    assign status_led = ~status_raw;

endmodule