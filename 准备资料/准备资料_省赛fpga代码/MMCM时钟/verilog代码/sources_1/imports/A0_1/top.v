`timescale 1ns / 1ps

module top (
    input  wire        clk_50m,        // U18  PL_GCLK

    output wire        led1,           // M14  
    output wire        led2,           // M15  1 kHz 
    output wire        led3,           // K16  2 kHz 
    output wire        led4,           // J16  0.5 kHz 

    output wire        osc_1khz,       // J11 PIN5 = G15   1 kHz 
    output wire        osc_2khz,       // J11 PIN7 = F16   2 kHz 
    output wire        osc_half_khz    // J11 PIN9 = G17   0.5 kHz 
);

    wire reset_n;
    assign reset_n = 1'b1;       

    wire        mmcm_locked;
    wire        clk_1khz;       // 50 MHz -> 1 kHz
    wire        clk_2khz;       // 100 MHz -> 2 kHz
    wire        clk_half_khz;   // 25 MHz -> 0.5 kHz

    MMCMClockGen u_MMCMClockGen (
        .clock           (clk_50m),  // 显式连接 clock，解决 12 缺 10 的警告
        .reset           (1'b0),     // 显式接 0，彻底消除 Synth 8-3295 悬空接0警告
        .io_clk_50m      (clk_50m),
        .io_reset_n      (reset_n),
        .io_clk_1khz     (clk_1khz),
        .io_clk_2khz     (clk_2khz),
        .io_clk_half_khz (clk_half_khz),
        .io_mmcm_locked  (mmcm_locked),
        .io_led_locked   (),         
        .io_led_1khz     (),         
        .io_led_2khz     (),         
        .io_led_half_khz ()          
    );
    // LED1: MMCM 
    assign led1 = ~mmcm_locked;
    // LED2: 1 kHz 
    assign led2 = ~clk_1khz;
    // LED3: 2 kHz 
    assign led3 = ~clk_2khz;
    // LED4: 0.5 kHz 
    assign led4 = ~clk_half_khz;

    assign osc_1khz     = clk_1khz;
    assign osc_2khz     = clk_2khz;
    assign osc_half_khz = clk_half_khz;

    (* mark_debug = "true" *) wire dbg_mmcm_locked;
    (* mark_debug = "true" *) wire dbg_clk_1khz;
    (* mark_debug = "true" *) wire dbg_clk_2khz;
    (* mark_debug = "true" *) wire dbg_clk_half_khz;

    assign dbg_mmcm_locked  = mmcm_locked;
    assign dbg_clk_1khz     = clk_1khz;
    assign dbg_clk_2khz     = clk_2khz;
    assign dbg_clk_half_khz = clk_half_khz;

endmodule
