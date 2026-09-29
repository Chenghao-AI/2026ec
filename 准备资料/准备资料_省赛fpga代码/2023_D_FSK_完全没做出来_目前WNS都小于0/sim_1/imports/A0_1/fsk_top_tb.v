`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// FSK Demodulation Comprehensive Testbench
// ============================================================================

module fsk_top_tb;

    // === Clock and Reset ===
    reg         clk_50m = 1'b0;
    wire        mmcm_locked;
    wire        clk_60m;
    reg [7:0]  rst_cnt = 8'h00;
    wire        sys_rst_50;

    // === Key Inputs (low-active) ===
    reg         key1_n = 1'b1;
    reg         key2_n = 1'b1;

    // === ADC Interface ===
    reg [11:0]  adc_a_data = 12'h800;
    reg         adc_a_ora = 1'b0;
    wire        adc_aclk;

    // === Outputs ===
    wire        led1, led2, led3, led4;
    wire [13:0] dac_a_data;
    wire        dac_a_clk;

    // === Internal signals ===
    integer     sim_phase = -1;

    // === 50MHz Clock ===
    initial forever #10 clk_50m = ~clk_50m;

    // === MMCM Simulation ===
    wire mmcm_clk_fb;
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (24.000),
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (20.000),
        .CLKOUT0_DIVIDE_F   (20.000),
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    )
    u_mmcm_sim (
        .CLKFBOUT  (mmcm_clk_fb),
        .CLKOUT0   (clk_60m),
        .CLKOUT1   (),
        .CLKOUT2   (),
        .CLKOUT3   (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),
        .LOCKED    (mmcm_locked),
        .CLKFBIN   (mmcm_clk_fb),
        .CLKIN1    (clk_50m),
        .RST       (1'b0),
        .PWRDWN    (1'b0)
    );

    // Force MMCM locked
    initial force u_mmcm_sim.LOCKED = 1'b1;

    // === Reset Counter ===
    always @(posedge clk_50m) begin
        if (~mmcm_locked) begin
            rst_cnt <= 8'h00;
        end else begin
            if (rst_cnt[7] == 1'b0)
                rst_cnt <= rst_cnt + 8'h01;
        end
    end
    assign sys_rst_50 = rst_cnt[7] == 1'b0;

    // === DUT ===
    fsk_top u_dut (
        .clk_50m        (clk_50m),
        .key1_n         (key1_n),
        .key2_n         (key2_n),
        .adc_a_data     (adc_a_data),
        .adc_a_ora      (adc_a_ora),
        .adc_aclk       (adc_aclk),
        .led1           (led1),
        .led2           (led2),
        .led3           (led3),
        .led4           (led4),
        .dac_a_data     (dac_a_data),
        .dac_a_clk      (dac_a_clk)
    );

    // === Access internal signals ===
    wire [1:0] dbg_rc_code  = u_dut.rc_code_50m;
    wire [1:0] dbg_h_code   = u_dut.h_code_50m;
    wire [3:0] dbg_led_logic = u_dut.led_logic_50m;

    // === FSK Signal Generation ===
    integer active_rc_kbps = 8;
    integer active_h = 3;
    integer active_f0 = 2_000_000;
    integer active_f1;
    real    amp = 0.4;
    real    center = 2048.0;
    real    scale = 2047.0 / 0.5;
    integer bit_period_60m;
    integer counter_60m = 0;
    reg     cur_bit = 1'b1;
    reg [15:0] lfsr = 16'hACE1;
    wire lfsr_bit = lfsr[15];

    // === ADC Signal Generation ===
    always @(posedge clk_60m) begin
        if (sys_rst_50) begin
            adc_a_data <= 12'h800;
            counter_60m <= 0;
            lfsr <= 16'hACE1;
            cur_bit <= 1'b1;
        end else begin
            counter_60m <= counter_60m + 1;
            if (cur_bit)
                adc_a_data <= 12'h800 + $rtoi(amp * scale * $sin(2.0 * 3.14159265 * $itor(active_f1) * $time / 1.0e9));
            else
                adc_a_data <= 12'h800 + $rtoi(amp * scale * $sin(2.0 * 3.14159265 * $itor(active_f0) * $time / 1.0e9));

            if (counter_60m > 0 && (counter_60m % bit_period_60m) == 0) begin
                cur_bit <= lfsr_bit;
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            end
        end
    end

    // === Test Configuration ===
    task set_combo;
        input integer rc;
        input integer h;
        begin
            active_rc_kbps = rc;
            active_h = h;
            active_f1 = active_f0 + h * rc * 1000;
            bit_period_60m = 60_000_000 / (rc * 1000);
            counter_60m = 0;
            lfsr = 16'hACE1;
            cur_bit = 1'b1;
            $display("[%0t] SET: rc=%0d kbps, h=%0d, f1=%0d Hz", $time, rc, h, active_f1);
        end
    endtask

    // === Expected LED ===
    function [3:0] get_expected_led;
        input [7:0] rc;
        input [7:0] h;
        input k1;
        input k2;
        reg [3:0] result;
        begin
            if (k2 == 0) begin  // KEY2 pressed - show h
                case (h)
                    8'd2:  result = 4'b0010;
                    8'd3:  result = 4'b0011;
                    8'd4:  result = 4'b0100;
                    8'd5:  result = 4'b0101;
                    default: result = 4'b0000;
                endcase
            end else begin  // KEY2 not pressed - show rc
                case (rc)
                    8'd6:  result = 4'b0110;
                    8'd8:  result = 4'b1000;
                    8'd10: result = 4'b1010;
                    default: result = 4'b0000;
                endcase
            end
            get_expected_led = result;
        end
    endfunction

    // === LED Check ===
    integer pass_count = 0;
    integer fail_count = 0;
    
    task check_led;
        input integer rc;
        input integer h;
        input integer k1;
        input integer k2;
        input [3:0] actual;
        input [3:0] expected;
        begin
            if (actual == expected) begin
                $display("[%0t] PASS: rc=%0d h=%0d k1=%0d k2=%0d -> LED=%b", 
                         $time, rc, h, k1, k2, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[%0t] FAIL: rc=%0d h=%0d k1=%0d k2=%0d -> LED=%b (expected %b)", 
                         $time, rc, h, k1, k2, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // === CSV Logging ===
    integer csv_fd;
    integer csv_count = 0;
    integer csv_max = 1000000;
    
    initial begin
        csv_fd = $fopen("C:/Users/24307/Desktop/FPGA_windows/matlab/FSK/source/vivado_dac_output.csv", "w");
        if (csv_fd == 0) begin
            $display("ERROR: Cannot open CSV file");
        end else begin
            $fwrite(csv_fd, "time_ns,idx,phase,key1_n,key2_n,dac_hex,dac_dec,led_logic,rc_code,h_code\n");
        end
    end

    always @(posedge clk_50m) begin
        if (!sys_rst_50 && sim_phase >= 0 && csv_count < csv_max && csv_fd != 0) begin
            $fwrite(csv_fd, "%d,%d,%d,%d,%d,%h,%d,%b,%d,%d\n",
                    $time, csv_count, sim_phase,
                    key1_n, key2_n,
                    dac_a_data, dac_a_data,
                    {led1, led2, led3, led4},
                    dbg_rc_code, dbg_h_code);
            csv_count <= csv_count + 1;
        end
    end

    // === Main Test ===
    reg [3:0] expected_led;
    integer test_rc, test_h;
    integer key_combo;
    
    initial begin
        $display("========================================");
        $display("FSK Demodulation Comprehensive Test");
        $display("========================================");

        // Wait for initialization (MMCM lock + reset)
        # 100000;
        $display("[%0t] Initialization complete", $time);

        // Test all 12 (rc, h) combinations
        for (sim_phase = 0; sim_phase < 12; sim_phase = sim_phase + 1) begin
            test_rc = (sim_phase < 4) ? 6 : (sim_phase < 8) ? 8 : 10;
            test_h = (sim_phase % 4) + 2;
            
            set_combo(test_rc, test_h);
            
            // Wait for signal processing to stabilize (200ms = 10M cycles @ 50MHz)
            # 200000000;
            
            // Test 4 key combinations
            for (key_combo = 0; key_combo < 4; key_combo = key_combo + 1) begin
                key1_n = (key_combo[0] == 1) ? 1'b1 : 1'b0;
                key2_n = (key_combo[1] == 1) ? 1'b1 : 1'b0;
                
                // Wait for debounce and sampling
                # 50000000;
                
                expected_led = get_expected_led(test_rc, test_h, key1_n, key2_n);
                check_led(test_rc, test_h, key1_n, key2_n, 
                          {led1, led2, led3, led4}, expected_led);
            end
        end

        // Summary
        if (csv_fd != 0) $fclose(csv_fd);
        
        $display("========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        # 10000;
        $finish;
    end

    // Timeout
    initial begin
        # 10000000000;
        $display("[%0t] TIMEOUT", $time);
        if (csv_fd != 0) $fclose(csv_fd);
        $finish;
    end

    // VCD
    initial begin
        $dumpfile("C:/Users/24307/Desktop/FPGA_windows/matlab/FSK/source/fsk_waveform.vcd");
        $dumpvars(0, fsk_top_tb);
    end

endmodule

`default_nettype wire
