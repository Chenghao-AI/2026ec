`timescale 1ns / 1ps
module dac_top_tb;
    reg clk_50m = 1'b0;
    always #10 clk_50m = ~clk_50m;

    wire [13:0] cha_data;
    wire        cha_clk;
    wire [13:0] chb_data;
    wire        chb_clk;
    wire [3:0]  status_led;

    dac_top u_dut (
        .clk_50m  (clk_50m),
        .cha_data (cha_data),
        .cha_clk  (cha_clk),
        .chb_data (chb_data),
        .chb_clk  (chb_clk),
        .status_led(status_led)
    );

    integer cyc;
    reg [13:0] cha_hist [0:8191];
    reg [13:0] chb_hist [0:8191];
    integer done_sampling;

    initial begin
        $dumpfile("dac_top_tb.vcd");
        $dumpvars(0, dac_top_tb);
    end

    integer i;
    initial begin
        cyc = 0;
        done_sampling = 0;
        # 320;
        for (i = 0; i < 4096; i = i + 1) begin
            @(posedge clk_50m);
            #1;
            cha_hist[i] = u_dut.cha_data;
            chb_hist[i] = u_dut.chb_data;
            cyc = cyc + 1;
        end
        $display("[TB] Sampled %0d cycles", cyc);
        done_sampling = 1;
    end

    integer j;
    integer cha_crosses, chb_crosses;
    integer cha_min, cha_max, chb_min, chb_max;
    integer cha_periods [0:255];
    integer chb_periods [0:255];
    integer prev_cha_cross, prev_chb_cross;
    integer cha_period_count, chb_period_count;
    integer cha_period_avg, chb_period_avg;
    integer cha_violations, chb_violations;

    // Assertion block runs continuously; waits for done_sampling before acting
    initial begin
        wait (done_sampling == 1);
        # 100;

        cha_min = 14'h3FFF; cha_max = 14'h0000;
        chb_min = 14'h3FFF; chb_max = 14'h0000;
        cha_violations = 0; chb_violations = 0;
        for (j = 0; j < 4096; j = j + 1) begin
            if (cha_hist[j] < cha_min) cha_min = cha_hist[j];
            if (cha_hist[j] > cha_max) cha_max = cha_hist[j];
            if (chb_hist[j] < chb_min) chb_min = chb_hist[j];
            if (chb_hist[j] > chb_max) chb_max = chb_hist[j];
            if (j > 50) begin
                if (cha_hist[j] < 14'h1AAB || cha_hist[j] > 14'h255D) cha_violations = cha_violations + 1;
                if (chb_hist[j] < 14'h1AAB || chb_hist[j] > 14'h255D) chb_violations = chb_violations + 1;
            end
        end

        cha_crosses = 0; chb_crosses = 0;
        prev_cha_cross = -1; prev_chb_cross = -1;
        cha_period_count = 0; chb_period_count = 0;
        for (j = 1; j < 4096; j = j + 1) begin
            if (cha_hist[j-1] < 14'h2000 && cha_hist[j] >= 14'h2000) begin
                if (prev_cha_cross >= 0) begin
                    cha_periods[cha_period_count] = j - prev_cha_cross;
                    cha_period_count = cha_period_count + 1;
                end
                prev_cha_cross = j;
                cha_crosses = cha_crosses + 1;
            end
            if (chb_hist[j-1] < 14'h2000 && chb_hist[j] >= 14'h2000) begin
                if (prev_chb_cross >= 0) begin
                    chb_periods[chb_period_count] = j - prev_chb_cross;
                    chb_period_count = chb_period_count + 1;
                end
                prev_chb_cross = j;
                chb_crosses = chb_crosses + 1;
            end
        end

        cha_period_avg = 0; chb_period_avg = 0;
        for (j = 0; j < cha_period_count; j = j + 1) begin
            if (cha_periods[j] > 0)
                cha_period_avg = cha_period_avg + cha_periods[j];
        end
        for (j = 0; j < chb_period_count; j = j + 1) begin
            if (chb_periods[j] > 0)
                chb_period_avg = chb_period_avg + chb_periods[j];
        end
        if (cha_period_count > 0) cha_period_avg = cha_period_avg / cha_period_count;
        if (chb_period_count > 0) chb_period_avg = chb_period_avg / chb_period_count;

        $display("================================================================");
        $display("[TB] DAC_exercise xsim summary");
        $display("================================================================");
        $display("CHA: min=%h (0x1AAB=6827)  max=%h (0x255D=9557)", cha_min, cha_max);
        $display("CHB: min=%h (0x1AAB=6827)  max=%h (0x255D=9557)", chb_min, chb_max);
        $display("CHA: %0d upward midpoint crossings, average period = %0d clk (expect 50)",
                 cha_crosses, cha_period_avg);
        $display("CHB: %0d upward midpoint crossings, average period = %0d clk (expect 25)",
                 chb_crosses, chb_period_avg);
        $display("CHA range violations (excluding startup): %0d", cha_violations);
        $display("CHB range violations (excluding startup): %0d", chb_violations);

        if (cha_min < 14'h1AAB || cha_max > 14'h255D) begin
            $display("*** FAIL: CHA range [%h, %h] outside [6827, 9557]", cha_min, cha_max);
            $fatal(1, "CHA range check failed");
        end
        if (chb_min < 14'h1AAB || chb_max > 14'h255D) begin
            $display("*** FAIL: CHB range [%h, %h] outside [6827, 9557]", chb_min, chb_max);
            $fatal(1, "CHB range check failed");
        end
        if (cha_period_avg < 49 || cha_period_avg > 51) begin
            $display("*** FAIL: CHA period %0d not within [49, 51] clk", cha_period_avg);
            $fatal(1, "CHA period check failed");
        end
        if (chb_period_avg < 24 || chb_period_avg > 26) begin
            $display("*** FAIL: CHB period %0d not within [24, 26] clk", chb_period_avg);
            $fatal(1, "CHB period check failed");
        end

        $display("================================================================");
        $display("[TB] ALL ASSERTIONS PASSED");
        $display("================================================================");
        $finish;
    end

    initial begin
        # 500_000;
        $display("[TB] TIMEOUT");
        $fatal(2, "simulation timeout");
    end
endmodule