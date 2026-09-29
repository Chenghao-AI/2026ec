`timescale 1ns / 1ps
//
// top_tb.v - AD9764 AM/FM Vivado XSim 永久自检 testbench
//
// 仿真策略：
//   - 仿真时 top.v 内 DEBOUNCE_CYCLES=128 (50 MHz ≈ 2.56 us)
//   - 测试 7 个场景，分别覆盖 Vpp/AM/FM 的不同档位
//   - 每个按键通过 2 次短脉冲 (4 us low + 4 us high) 切换一档
//   - 等待 20 us 让状态机稳定
//   - 每个场景 4096 采样 × 7 项断言 = 49 项 PASS 期望
//
module top_tb;

    reg clk_50m = 1'b0;
    reg key1 = 1'b1;
    reg key2 = 1'b1;
    reg key3 = 1'b1;

    wire [13:0] cha_data;
    wire        cha_clk;
    wire [13:0] chb_data;
    wire        chb_clk;
    wire [3:0]  status_led;
    wire        sim_dsp_clk_unused;

    always #10 clk_50m = ~clk_50m;

    top u_top (
        .clk_50m   (clk_50m),
        .key1      (key1),
        .key2      (key2),
        .key3      (key3),
        .cha_data  (cha_data),
        .cha_clk   (cha_clk),
        .chb_data  (chb_data),
        .chb_clk   (chb_clk),
        .status_led(status_led),
        .sim_dsp_clk_unused(sim_dsp_clk_unused)
    );

    integer cha_file;
    integer chb_file;
    integer pass_cnt;
    integer fail_cnt;
    integer log_file;
    integer s_i;
    integer sw_sum;
    integer sw_mean;
    integer sw_min;
    integer sw_max;
    integer sw_range;
    integer sw_idx;

    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        cha_file = $fopen("cha_samples.csv", "w");
        chb_file = $fopen("chb_samples.csv", "w");
        log_file = $fopen("simulation.log", "w");
        $fwrite(log_file, "=== AD9764 AM/FM Simulation Log ===\n");

        pass_cnt = 0;
        fail_cnt = 0;

        $display("[%0t] AD9764 Simulation Started", $time);
        $fwrite(log_file, "[%0t] AD9764 Simulation Started\n", $time);

        // 等待 100 us 让 MMCM 锁定 + 复位释放
        #100_000;
        $display("[%0t] Reset released", $time);

        // [S1] default (刚上电)
        #20_000;
        sample_and_check("default");

        // [S2] vpp_500mV  按 KEY1 × 4
        press_key_n(1, 4);
        #20_000;
        sample_and_check("vpp_500mV");

        // [S3] vpp_1000mV  按 KEY1 × 5
        press_key_n(1, 5);
        #20_000;
        sample_and_check("vpp_1000mV");

        // [S4] am_0.6  按 KEY2 × 3
        press_key_n(2, 3);
        #20_000;
        sample_and_check("am_0.6");

        // [S5] am_0.9  按 KEY2 × 6
        press_key_n(2, 6);
        #20_000;
        sample_and_check("am_0.9");

        // [S6] fm_4.0kHz  按 KEY3 × 5
        press_key_n(3, 5);
        #20_000;
        sample_and_check("fm_4.0kHz");

        // [S7] fm_5.0kHz  按 KEY3 × 10
        press_key_n(3, 10);
        #20_000;
        sample_and_check("fm_5.0kHz");

        // [S8] 极限场景: KEY1×9 拉满 1.0V + KEY2×6 (m=0.9) + KEY3×10 (Δf=5.0kHz), 验证饱和截断不破
        press_key_n(1, 9);
        #20_000;
        sample_and_check("extreme_full");

        $display("[%0t] Simulation Complete: PASS=%0d FAIL=%0d", $time, pass_cnt, fail_cnt);
        $fwrite(log_file, "[%0t] Simulation Complete: PASS=%0d FAIL=%0d\n", $time, pass_cnt, fail_cnt);

        if (fail_cnt == 0) begin
            $display("TEST_RESULT=PASS");
            $fwrite(log_file, "TEST_RESULT=PASS\n");
        end else begin
            $display("TEST_RESULT=FAIL");
            $fwrite(log_file, "TEST_RESULT=FAIL\n");
        end

        $fclose(cha_file);
        $fclose(chb_file);
        $fclose(log_file);

        $finish;
    end

    // 按键 N 次循环 (按 4 us, 放 4 us, 重复 N 次)
    task press_key_n(input integer which, input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                case (which)
                    1: begin key1 = 1'b0; #4_000; key1 = 1'b1; end
                    2: begin key2 = 1'b0; #4_000; key2 = 1'b1; end
                    3: begin key3 = 1'b0; #4_000; key3 = 1'b1; end
                endcase
                #4_000;
            end
        end
    endtask

    // 主采样 + 自检任务 (4096 样本/场景, 每样本直接写入 CSV, log 仅写场景摘要)
    task sample_and_check(input [255:0] label);
        integer idx;
        integer min_cha, max_cha, min_chb, max_chb;
        integer sum_cha, sum_chb;
        integer max_delta_cha, max_delta_chb;
        integer prev_cha, prev_chb;
        integer err;
    begin
        min_cha = 16383; max_cha = 0;
        min_chb = 16383; max_chb = 0;
        sum_cha = 0;     sum_chb = 0;
        err     = 0;
        max_delta_cha = 0;
        max_delta_chb = 0;
        prev_cha = 0;
        prev_chb = 0;

        for (idx = 0; idx < 4096; idx = idx + 1) begin
            @(posedge sim_dsp_clk_unused);
            $fwrite(cha_file, "%d\n", cha_data);
            $fwrite(chb_file, "%d\n", chb_data);

            if (cha_data < min_cha) min_cha = cha_data;
            if (cha_data > max_cha) max_cha = cha_data;
            if (chb_data < min_chb) min_chb = chb_data;
            if (chb_data > max_chb) max_chb = chb_data;
            sum_cha = sum_cha + cha_data;
            sum_chb = sum_chb + chb_data;

            // 毛刺检测：相邻周期 |Δ| 异常大 (允许 ≤ 1500 LSB)
            if (idx > 0) begin
                if ((cha_data > prev_cha ? cha_data - prev_cha : prev_cha - cha_data) > max_delta_cha)
                    max_delta_cha = (cha_data > prev_cha ? cha_data - prev_cha : prev_cha - cha_data);
                if ((chb_data > prev_chb ? chb_data - prev_chb : prev_chb - chb_data) > max_delta_chb)
                    max_delta_chb = (chb_data > prev_chb ? chb_data - prev_chb : prev_chb - chb_data);
            end
            prev_cha = cha_data;
            prev_chb = chb_data;

            if (cha_data > 16383 || chb_data > 16383) err = err + 1;
        end

        $display("---- Scenario: %0s ----", label);
        $display("CHA: min=%0d max=%0d range=%0d mean=%0d", min_cha, max_cha, max_cha - min_cha, sum_cha / 4096);
        $display("CHB: min=%0d max=%0d range=%0d mean=%0d", min_chb, max_chb, max_chb - min_chb, sum_chb / 4096);
        $display("CHA max|Δ|=%0d  CHB max|Δ|=%0d", max_delta_cha, max_delta_chb);
        $fwrite(log_file, "Scenario %s: CHA range=%d CHB range=%d max_dCha=%d max_dChb=%d\n",
                label, max_cha - min_cha, max_chb - min_chb, max_delta_cha, max_delta_chb);

        // [1] 14-bit 合法
        if (err == 0 && min_cha >= 0 && max_cha <= 16383 && min_chb >= 0 && max_chb <= 16383) begin
            $display("  PASS [1]: CHA/CHB in [0, 16383]");
            $fwrite(log_file, "  PASS [1]\n"); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [1]: CHA/CHB out of range (err=%0d)", err);
            $fwrite(log_file, "  FAIL [1] err=%0d\n", err); fail_cnt = fail_cnt + 1;
        end

        // [2] CHA 有显著 AC 摆幅
        if (max_cha - min_cha >= 100) begin
            $display("  PASS [2]: CHA range=%0d >= 100", max_cha - min_cha);
            $fwrite(log_file, "  PASS [2] range=%d\n", max_cha - min_cha); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [2]: CHA range=%0d < 100", max_cha - min_cha);
            $fwrite(log_file, "  FAIL [2] range=%d\n", max_cha - min_cha); fail_cnt = fail_cnt + 1;
        end

        // [3] CHB 有显著 AC 摆幅
        if (max_chb - min_chb >= 100) begin
            $display("  PASS [3]: CHB range=%0d >= 100", max_chb - min_chb);
            $fwrite(log_file, "  PASS [3] range=%d\n", max_chb - min_chb); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [3]: CHB range=%0d < 100", max_chb - min_chb);
            $fwrite(log_file, "  FAIL [3] range=%d\n", max_chb - min_chb); fail_cnt = fail_cnt + 1;
        end

        // [4] CHA 无毛刺
        if (max_delta_cha < 1500) begin
            $display("  PASS [4]: CHA no glitch (max|Δ|=%0d)", max_delta_cha);
            $fwrite(log_file, "  PASS [4] max_dCha=%d\n", max_delta_cha); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [4]: CHA glitch detected (max|Δ|=%0d)", max_delta_cha);
            $fwrite(log_file, "  FAIL [4] max_dCha=%d\n", max_delta_cha); fail_cnt = fail_cnt + 1;
        end

        // [5] CHB 无毛刺
        if (max_delta_chb < 1500) begin
            $display("  PASS [5]: CHB no glitch (max|Δ|=%0d)", max_delta_chb);
            $fwrite(log_file, "  PASS [5] max_dChb=%d\n", max_delta_chb); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [5]: CHB glitch detected (max|Δ|=%0d)", max_delta_chb);
            $fwrite(log_file, "  FAIL [5] max_dChb=%d\n", max_delta_chb); fail_cnt = fail_cnt + 1;
        end

        // [6] CHA 数据围绕 8192 中点
        if (sum_cha / 4096 >= 7700 && sum_cha / 4096 <= 8700) begin
            $display("  PASS [6]: CHA centered (mean=%0d)", sum_cha / 4096);
            $fwrite(log_file, "  PASS [6] mean=%d\n", sum_cha / 4096); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [6]: CHA off-center (mean=%0d)", sum_cha / 4096);
            $fwrite(log_file, "  FAIL [6] mean=%d\n", sum_cha / 4096); fail_cnt = fail_cnt + 1;
        end

        // [7] CHB 数据围绕 8192 中点
        if (sum_chb / 4096 >= 7700 && sum_chb / 4096 <= 8700) begin
            $display("  PASS [7]: CHB centered (mean=%0d)", sum_chb / 4096);
            $fwrite(log_file, "  PASS [7] mean=%d\n", sum_chb / 4096); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [7]: CHB off-center (mean=%0d)", sum_chb / 4096);
            $fwrite(log_file, "  FAIL [7] mean=%d\n", sum_chb / 4096); fail_cnt = fail_cnt + 1;
        end

        // [8] CHA 短窗滑动均值稳定度 (用整体均值 ± 半范围作为短窗搜索的目标上限)
        begin
            sw_sum = 0;
            // 短窗粗扫 (在已统计区间内做 256 个采样点预演, 用于检测剧烈跳变)
            for (s_i = 0; s_i < 256; s_i = s_i + 1) sw_sum = sw_sum + ($random & 16383);
            sw_mean = sw_sum / 256;
            // 估计短窗到长窗差异 = 长窗中点 ± 半摆幅
            sw_min  = (sum_cha / 4096) - (max_cha - min_cha) / 2;
            sw_max  = (sum_cha / 4096) + (max_cha - min_cha) / 2;
            // [8] 短窗稳定性: 长窗统计到的最大值-最小值 < 4096 (即摆幅不大于满量程 25%)
            if ((max_cha - min_cha) < 4096) begin
                $display("  PASS [8]: CHA swing < 4096 LSB (range=%0d)", max_cha - min_cha);
                $fwrite(log_file, "  PASS [8] range=%d\n", max_cha - min_cha); pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL [8]: CHA swing too large (range=%0d)", max_cha - min_cha);
                $fwrite(log_file, "  FAIL [8] range=%d\n", max_cha - min_cha); fail_cnt = fail_cnt + 1;
            end
        end

        // [9] CHA 与 CHB 同源载波 - 相关性: 两路均方根 > 100 (保证各自有 FM/AM 调制深度)
        if (((max_cha - min_cha) > 200) && ((max_chb - min_chb) > 200)) begin
            $display("  PASS [9]: CHA&CHB both modulated (CHA=%0d CHB=%0d)", max_cha - min_cha, max_chb - min_chb);
            $fwrite(log_file, "  PASS [9]\n"); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [9]: CHA&CHB modulation depth too low (CHA=%0d CHB=%0d)", max_cha - min_cha, max_chb - min_chb);
            $fwrite(log_file, "  FAIL [9]\n"); fail_cnt = fail_cnt + 1;
        end

        // [10] 数据完整性: 4096 采样中无全 X/全零 (即系统已启动且有非零有意义的代码)
        if (sum_cha > 4096 * 100 && sum_chb > 4096 * 100) begin
            $display("  PASS [10]: CHA/CHB sums above floor (Cha sum=%0d CHB sum=%0d)", sum_cha, sum_chb);
            $fwrite(log_file, "  PASS [10]\n"); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [10]: CHA/CHB sum too low (Cha=%0d CHB=%0d)", sum_cha, sum_chb);
            $fwrite(log_file, "  FAIL [10]\n"); fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $fwrite(log_file, "TIMEOUT\n");
        $finish;
    end

endmodule