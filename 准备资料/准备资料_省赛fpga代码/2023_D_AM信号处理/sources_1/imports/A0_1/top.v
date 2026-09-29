`timescale 1ns/1ps

module top (

    input  wire        clk_50m,
    input  wire [11:0] adc_a_data,
    input  wire        adc_a_ora,
    input  wire [11:0] adc_b_data,
    input  wire        adc_b_orb,
    output wire        adc_aclk_p14,
    output wire        adc_bck_t16,
    output wire [3:0]  pl_led,
    input  wire [3:0]  pl_key,
    output wire [7:0]  seg,
    output wire [3:0]  dig_sel,
    output wire        uo_ana

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

ODDR #(
    .DDR_CLK_EDGE("OPPOSITE_EDGE"),
    .INIT(1'b0),
    .SRTYPE("SYNC")
) u_oddr_adc_a (
    .Q  (adc_aclk_p14),
    .C  (clk_40m),
    .CE (1'b1),
    .D1 (1'b0),
    .D2 (1'b1),
    .R  (1'b0),
    .S  (1'b0)
);

    wire [11:0] adc_a_data_sync;
    wire [11:0] adc_b_data_sync;
    wire        adc_a_ora_sync;
    wire        adc_b_orb_sync;

    DualAdcCapture u_cap (
        .clock                (clk_40m),
        .reset                (~mmcm_locked),
        .io_io_adc_data_a_raw (adc_a_data),
        .io_io_adc_data_b_raw (adc_b_data),
        .io_io_ora_raw        (adc_a_ora),
        .io_io_orb_raw        (adc_b_orb),
        .io_io_adc_data_a     (adc_a_data_sync),
        .io_io_adc_data_b     (adc_b_data_sync),
        .io_io_ora            (adc_a_ora_sync),
        .io_io_orb            (adc_b_orb_sync)
    );

    wire [3:0] key_raw_hi;  

    assign key_raw_hi[0] = ~pl_key[0];
    assign key_raw_hi[1] = ~pl_key[1];
    assign key_raw_hi[2] = ~pl_key[2];
    assign key_raw_hi[3] = ~pl_key[3];

    wire [3:0] pl_led_int;
    wire       is_am;
    wire [7:0] ma;
    wire [2:0] mod_freq;

    TopStep2 u_am (
        .clock         (clk_40m),
        .reset         (~mmcm_locked),
        .io_adc_a_data (adc_a_data_sync),
        .io_key_raw_0  (key_raw_hi[0]),
        .io_key_raw_1  (key_raw_hi[1]),
        .io_key_raw_2  (key_raw_hi[2]),
        .io_key_raw_3  (key_raw_hi[3]),
        .io_pl_led     (pl_led_int),
        .io_seg        (seg),
        .io_dig_sel    (dig_sel),
        .io_uo_ana     (uo_ana),
        .io_is_am      (is_am),
        .io_ma         (ma),
        .io_mod_freq   (mod_freq)
    );

    assign pl_led = ~pl_led_int;

    assign adc_bck_t16 = 1'b0;

endmodule