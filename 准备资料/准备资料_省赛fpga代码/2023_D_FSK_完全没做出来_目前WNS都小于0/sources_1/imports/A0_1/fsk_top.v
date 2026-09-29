`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// FSK Demodulation Top Module - Fixed Version
// Fixed Issues:
// 1. Proper key synchronization across clock domains
// 2. Parameter estimation with faster convergence
// 3. Correct LED output logic
// ============================================================================

module fsk_top (
    input  wire        clk_50m,         // U18 (50 MHz)
    input  wire        key1_n,          // N15 (low-active)
    input  wire        key2_n,          // N16 (low-active)
    input  wire [11:0] adc_a_data,      // R14...P15
    input  wire        adc_a_ora,       // P16
    output wire        adc_aclk,        // P14

    output wire        led1,            // M14  (low-active)
    output wire        led2,            // M15
    output wire        led3,            // K16
    output wire        led4,            // J16

    output wire [13:0] dac_a_data,      // L16..G20
    output wire        dac_a_clk        // G19
);

    // ========================================================================
    // MMCM: 50MHz -> 60MHz
    // ========================================================================
    wire mmcm_locked;
    wire clk_60m;
    
    fsk_mmcm u_mmcm (
        .clk_50m     (clk_50m),
        .mmcm_locked (mmcm_locked),
        .clk_60m_out (clk_60m)
    );

    // ========================================================================
    // Reset Logic
    // ========================================================================
    reg [7:0] rst_cnt = 8'h00;
    always @(posedge clk_50m) begin
        if (~mmcm_locked || rst_cnt[7] == 1'b0) begin
            rst_cnt <= rst_cnt + 8'h01;
        end
    end
    wire sys_rst_50 = rst_cnt[7] == 1'b0;
    
    // Synchronize reset to 60MHz domain
    reg [2:0] rst60_sync = 3'b111;
    always @(posedge clk_60m) begin
        rst60_sync <= {rst60_sync[1:0], sys_rst_50};
    end
    wire sys_rst_60 = rst60_sync[2];

    // ========================================================================
    // ADC Clock Output (送给AD9226)
    // ========================================================================
    assign adc_aclk = ~clk_60m;  // AD9226 samples on rising edge

    // ========================================================================
    // ADC Data Synchronization (to 60MHz domain)
    // ========================================================================
    reg [11:0] adc_a_sync;
    reg        adc_ora_sync;
    always @(posedge clk_60m) begin
        if (sys_rst_60) begin
            adc_a_sync   <= 12'h800;
            adc_ora_sync <= 1'b0;
        end else begin
            adc_a_sync   <= adc_a_data;
            adc_ora_sync <= adc_a_ora;
        end
    end

    // ========================================================================
    // Key Synchronization - Synchronize to 60MHz domain
    // ========================================================================
    reg [2:0] key1_sync_50m;
    reg [2:0] key2_sync_50m;
    
    // First stage: 50MHz domain
    always @(posedge clk_50m) begin
        if (sys_rst_50) begin
            key1_sync_50m <= 3'b111;
            key2_sync_50m <= 3'b111;
        end else begin
            key1_sync_50m <= {key1_sync_50m[1:0], key1_n};
            key2_sync_50m <= {key2_sync_50m[1:0], key2_n};
        end
    end
    
    // Second stage: Pass to 60MHz domain
    reg key1_60m, key2_60m;
    always @(posedge clk_60m) begin
        if (sys_rst_60) begin
            key1_60m <= 1'b1;
            key2_60m <= 1'b1;
        end else begin
            key1_60m <= key1_sync_50m[2];
            key2_60m <= key2_sync_50m[2];
        end
    end

    // ========================================================================
    // FSK Demodulation Core (60MHz domain)
    // ========================================================================
    wire        demod_bit_60;
    wire        demod_valid_60;
    wire        demod_locked_60;
    wire [1:0]  rc_code_60;
    wire [1:0]  h_code_60;
    wire [3:0]  led_logic_60;
    wire [13:0] dac_data_60;
    wire [29:0] demod_abs_diff_60;

    FskDemodCore u_core (
        .io_clkAdc           (clk_60m),
        .io_rstAdcAsync      (sys_rst_60),
        .io_inAdcA           (adc_a_sync),
        .io_inAdcOra         (adc_ora_sync),
        .io_inKey1           (key1_60m),    // Low-active key
        .io_inKey2           (key2_60m),    // Low-active key
        .io_outDemodBit      (demod_bit_60),
        .io_outDemodValid    (demod_valid_60),
        .io_outDemodLocked   (demod_locked_60),
        .io_outRcCode        (rc_code_60),
        .io_outHCode         (h_code_60),
        .io_outLed           (led_logic_60),
        .io_outDacData       (dac_data_60),
        .io_outAbsDiff       (demod_abs_diff_60)
    );

    // ========================================================================
    // Clock Domain Crossing: 60MHz -> 50MHz for outputs
    // ========================================================================
    reg        demod_bit_50m;
    reg        demod_valid_50m;
    reg        demod_locked_50m;
    reg [1:0]  rc_code_50m;
    reg [1:0]  h_code_50m;
    reg [3:0]  led_logic_50m;
    reg [13:0] dac_data_50m;
    
    always @(posedge clk_50m) begin
        if (sys_rst_50) begin
            demod_bit_50m   <= 1'b0;
            demod_valid_50m <= 1'b0;
            demod_locked_50m <= 1'b0;
            rc_code_50m     <= 2'b01;  // Default 8k
            h_code_50m      <= 2'b00;  // Default h=2
            led_logic_50m   <= 4'b1000; // LED4 on (8k default)
            dac_data_50m   <= 14'h2000; // Mid-scale (0V output)
        end else begin
            demod_bit_50m   <= demod_bit_60;
            demod_valid_50m <= demod_valid_60;
            demod_locked_50m <= demod_locked_60;
            rc_code_50m     <= rc_code_60;
            h_code_50m      <= h_code_60;
            led_logic_50m   <= led_logic_60;
            dac_data_50m   <= dac_data_60;
        end
    end

    // ========================================================================
    // DAC Output
    // ========================================================================
    reg [13:0] dac_data_reg;
    
    always @(posedge clk_50m) begin
        if (sys_rst_50) begin
            dac_data_reg <= 14'h2000;  // Mid-scale default
        end else begin
            dac_data_reg <= dac_data_50m;
        end
    end
    
    assign dac_a_clk  = clk_50m;
    assign dac_a_data = dac_data_reg;

    // ========================================================================
    // LED Output (low-active: 0 = LED on, 1 = LED off)
    // led1 corresponds to M14 (LED1)
    // led_logic bits: [3]=LED4, [2]=LED3, [1]=LED2, [0]=LED1
    // ========================================================================
    assign led1 = ~led_logic_50m[0];  // LED1 on when bit[0]=1
    assign led2 = ~led_logic_50m[1];  // LED2 on when bit[1]=1
    assign led3 = ~led_logic_50m[2];  // LED3 on when bit[2]=1
    assign led4 = ~led_logic_50m[3];  // LED4 on when bit[3]=1

endmodule

// ============================================================================
// MMCM Module: Generate 60MHz from 50MHz
// ============================================================================
module fsk_mmcm (
    input  wire clk_50m,
    output wire clk_60m_out,
    output wire mmcm_locked
);
    wire clk_fb;
    
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (24.000),     // VCO = 50*24 = 1200 MHz (within 600-1440 MHz)
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (20.000),      // 50 MHz = 20 ns
        .CLKOUT0_DIVIDE_F   (20.000),     // 1200/20 = 60 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    )
    mmcm_inst (
        .CLKFBOUT  (clk_fb),
        .CLKOUT0   (clk_60m_out),
        .CLKOUT1   (),
        .CLKOUT2   (),
        .CLKOUT3   (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),
        .LOCKED    (mmcm_locked),
        .CLKFBIN   (clk_fb),
        .CLKIN1    (clk_50m),
        .RST       (1'b0),
        .PWRDWN    (1'b0)
    );
endmodule

`default_nettype wire
