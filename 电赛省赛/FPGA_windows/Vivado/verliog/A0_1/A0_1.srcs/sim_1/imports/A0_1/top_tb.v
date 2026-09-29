`timescale 1ns / 1ps

// ============================================================================
// top_tb.v — 行为仿真 testbench (Vivado XSim)
// ----------------------------------------------------------------------------
//   跳过 MMCM, 直接给 clk_4m. 因为 MMCM 在仿真中是黑盒, 没有可综合行为模型.
//   SpectrumTop 实际工作在 4 MHz, 我们就用 4 MHz 驱动.
//
//   生成合成 ADC 数据 (offset binary 0~4095):
//     1 个 100 kHz 正弦 + 1 个 200 kHz 正弦 (各 1000 LSB 幅值, DC=2048)
//     fs = 4 MHz
//
//   用 $fwrite 把每个 clk_4m 上升沿的 ILA 探针 (mag, bin, valid) 写入
//   ila_dump.csv, 供 MATLAB 离线画频谱图.
//
//   仿真时长: 5 帧 (5 * 8192 采样点 * 250 ns = 10.24 ms)
// ============================================================================
module top_tb;

    reg          clk_4m = 0;
    reg  [11:0]  adc_a_data = 12'd2048;
    reg          adc_a_ora = 0;

    wire signed [11:0] adc_a_signed;
    wire               ora_synced;

    AdcChaCapture u_adc_cap (
        .clk_4m        (clk_4m),
        .adc_a_raw     (adc_a_data),
        .ora_raw       (adc_a_ora),
        .adc_a_signed  (adc_a_signed),
        .ora_out       (ora_synced)
    );
    wire _ora_unused = ^ora_synced;

    SpectrumTop u_spec (
        .clk_4m              (clk_4m),
        .rst                 (1'b0),
        .adc_a_signed        (adc_a_signed)
    );

    // ----------------- 合成 ADC 数据 -----------------
    integer n = 0;
    reg signed [17:0] wave_sample = 18'sd0;
    integer fp = 0;

    // 4 MHz 时钟
    always #125 clk_4m = ~clk_4m;

    initial begin
        fp = $fopen("ila_dump.csv", "w");
        $fwrite(fp, "t_ns,adc_signed,bin,mag,valid,frame_end,wr_addr\n");
    end

    always @(posedge clk_4m) begin
        n = n + 1;
        wave_sample = $rtoi( 1000.0 * $sin(2.0 * 3.141592653589793 * 100000.0 * n / 4.0e6)
                           + 1000.0 * $sin(2.0 * 3.141592653589793 * 200000.0 * n / 4.0e6)
                           + 2048.0 );
        if (wave_sample < 0)         adc_a_data = 12'd0;
        else if (wave_sample > 4095) adc_a_data = 12'd4095;
        else                         adc_a_data = wave_sample[11:0];

        $fwrite(fp, "%0d,%d,%0d,%0d,%0d,%0d,%0d\n",
                $time,
                adc_a_signed,
                u_spec.ila_probe_bin,
                u_spec.ila_probe_mag,
                u_spec.ila_probe_valid,
                u_spec.ila_probe_frame_end,
                u_spec.u_driver.cur_wr_addr
        );
    end

    initial begin
        # (40960 * 250);    // 10.24 ms
        $display("[TB] done, time=%0t", $time);
        $fclose(fp);
        $finish;
    end

endmodule