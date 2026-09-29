`timescale 1ns / 1ps

module top_step2_tb;

    reg         clk_50m = 0;
    reg  [11:0] adc_a_data = 12'd2048;
    reg         adc_a_ora = 0;
    reg  [11:0] adc_b_data = 12'd2048;
    reg         adc_b_orb = 0;

    wire        adc_aclk_p14;
    wire        adc_bck_t16;
    wire [3:0]  pl_led;
    wire [3:0]  pl_key = 4'b1111;
    wire [7:0]  seg;
    wire [3:0]  dig_sel;
    wire        uo_ana;
    wire        is_am;
    wire [7:0]  ma;
    wire [2:0]  mod_freq;
    wire [31:0] maxE;

    top dut (
        .clk_50m     (clk_50m),
        .adc_a_data  (adc_a_data),
        .adc_a_ora   (adc_a_ora),
        .adc_b_data  (adc_b_data),
        .adc_b_orb   (adc_b_orb),
        .adc_aclk_p14(adc_aclk_p14),
        .adc_bck_t16 (adc_bck_t16),
        .pl_led      (pl_led),
        .pl_key      (pl_key),
        .seg         (seg),
        .dig_sel     (dig_sel),
        .uo_ana      (uo_ana)
    );

    assign is_am    = dut.is_am;
    assign ma       = dut.ma;
    assign mod_freq = dut.mod_freq;
    assign maxE     = dut.maxE;

    initial forever #10 clk_50m = ~clk_50m;

    integer csv_fd;
    integer scan_ok;
    integer idx;
    integer adc_val;
    integer sample_count;

    initial begin
        csv_fd = $fopen("am_long.csv", "r");
        if (csv_fd == 0) begin
            $display("[ERROR] cannot open am_long.csv");
            $finish;
        end

        scan_ok = $fscanf(csv_fd, "%s %s", idx, adc_val);
        
        sample_count = 0;
        while (!$feof(csv_fd)) begin
            scan_ok = $fscanf(csv_fd, "%d %d", idx, adc_val);
            if (scan_ok == 2) begin
                @(posedge clk_50m);
                #1;
                adc_a_data = adc_val[11:0];
                sample_count = sample_count + 1;
            end
        end
        
        $fclose(csv_fd);
        $display("[INFO] fed %d samples", sample_count);
        
        repeat(10000) @(posedge clk_50m);
        $display("[RESULT] is_am=%b ma=%d mod_freq=%d maxE=%d", is_am, ma, mod_freq, maxE);
        $display("[RESULT] pl_led=%b seg=%b dig_sel=%b uo_ana=%b", pl_led, seg, dig_sel, uo_ana);
        
        $finish;
    end

    initial begin
        $dumpfile("top_step2_tb.vcd");
        $dumpvars(0, top_step2_tb);
    end

    initial begin
        #50000000;
        $display("[TIMEOUT] simulation timed out");
        $finish;
    end

endmodule