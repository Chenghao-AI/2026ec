`timescale 1ns / 1ps

module top_tb;

    reg clk_50m = 0;
    always #10 clk_50m = ~clk_50m;

    reg  key1 = 1'b1, key2 = 1'b1, key3 = 1'b1, key4 = 1'b1;
    wire [3:0] led;

    wire sda;
    wire scl;
    pullup(sda);
    pullup(scl);
    assign sda = 1'bz;

    top u_top (
        .clk_50m (clk_50m),
        .sda     (sda),
        .scl     (scl),
        .key1    (key1),
        .key2    (key2),
        .key3    (key3),
        .key4    (key4),
        .led     (led)
    );

    reg [15:0] dac_data;
    always @* dac_data = u_top.u_step2.am.io_dacData;

    task measure_range;
        input  [31:0] cycles;
        output [15:0] mn_out;
        output [15:0] mx_out;
        integer i;
        reg [15:0] mn, mx;
        begin
            mn = 16'hFFFF; mx = 16'h0;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk_50m);
                #1;
                if (dac_data < mn) mn = dac_data;
                if (dac_data > mx) mx = dac_data;
            end
            mn_out = mn;
            mx_out = mx;
        end
    endtask

    task show_envelope;
        input [255:0] name;
        input [31:0] cycles;
        reg [15:0] mn_v, mx_v;
        begin
            measure_range(cycles, mn_v, mx_v);
            $display("| %-38s | min=0x%04x max=0x%04x range=%6d |",
                     name, mn_v, mx_v, mx_v - mn_v);
        end
    endtask

    task force_key_pulse;
        input [1:0] idx;
        begin
            // �� @posedge ǰ�����? 1-cycle pulse, �� FSM ���ܲɵ�
            case (idx)
                0: begin
                    @(posedge clk_50m); force u_top.u_step2.kd1.pulseReg = 1'b1;
                    @(posedge clk_50m); force u_top.u_step2.kd1.pulseReg = 1'b0;
                    release u_top.u_step2.kd1.pulseReg;
                end
                1: begin
                    @(posedge clk_50m); force u_top.u_step2.kd2.pulseReg = 1'b1;
                    @(posedge clk_50m); force u_top.u_step2.kd2.pulseReg = 1'b0;
                    release u_top.u_step2.kd2.pulseReg;
                end
                2: begin
                    @(posedge clk_50m); force u_top.u_step2.kd3.pulseReg = 1'b1;
                    @(posedge clk_50m); force u_top.u_step2.kd3.pulseReg = 1'b0;
                    release u_top.u_step2.kd3.pulseReg;
                end
                3: begin
                    @(posedge clk_50m); force u_top.u_step2.kd4.pulseReg = 1'b1;
                    @(posedge clk_50m); force u_top.u_step2.kd4.pulseReg = 1'b0;
                    release u_top.u_step2.kd4.pulseReg;
                end
            endcase
        end
    endtask

    initial begin
        $display("================================================================");
        $display("| Step 2-1: AM waveform test (using force into kd pulseReg)     |");
        $display("================================================================");
        $display("| Step                                         | Output (DAC)   |");
        $display("----------------------------------------------------------------");

        // ?????�� + ?? AM ??? (~500k clk = 10 ms)
        repeat (300000) @(posedge clk_50m);  // 6 ms

        // (1) ??? m=0.3 ???
        show_envelope("[1] Direct m=0.3 (default)", 50000);

        // (2) KEY3 x6 -> m=0.9
        repeat (6) begin
            force_key_pulse(2);
            repeat (100) @(posedge clk_50m);  // ?? FSM ??????
        end
        $display("| %-38s | mod_idx=%0d (target 6) |",
                 "[2] After 6x KEY3 force_pulse", u_top.u_step2.fsm.io_modIdx);
        show_envelope("[3] Direct m=0.9 (after KEY3 x6)", 50000);

        // (3) KEY1 -> ??
        force_key_pulse(0);
        repeat (300000) @(posedge clk_50m);  // ?? shift register ?? (200 us = 10000 clk)
        $display("| %-38s | mode=%0d (target 1) |",
                 "[4] After KEY1 multi-path", u_top.u_step2.fsm.io_modeSel);
        show_envelope("[5] Multi-path m=0.9 alpha=0dB", 50000);

        // (4) KEY2 x10 -> 20 dB
        repeat (10) begin
            force_key_pulse(1);
            repeat (100) @(posedge clk_50m);
        end
        $display("| %-38s | atten=%0d (target 10) |",
                 "[6] After 10x KEY2 (multi-path)", u_top.u_step2.fsm.io_attenIdx);
        show_envelope("[7] Multi-path m=0.9 alpha=20dB", 50000);

        // (5) KEY1 -> ??? (??? KEY2/KEY4 ?��)
        force_key_pulse(0);
        repeat (1000) @(posedge clk_50m);
        $display("| %-38s | mode=%0d (target 0) |",
                 "[8] After KEY1 back to direct", u_top.u_step2.fsm.io_modeSel);
        force_key_pulse(1);  // ???��
        force_key_pulse(3);  // ???��
        $display("| KEY2/KEY4 in direct mode rejected     | atten=%0d delay=%0d |",
                 u_top.u_step2.fsm.io_attenIdx, u_top.u_step2.fsm.io_delayIdx);
        show_envelope("[9] Direct, after ignored KEY2/KEY4", 50000);

        $display("================================================================");
        $finish;
    end

    initial begin
        $dumpfile("tb_waveform.vcd");
        $dumpvars(0, top_tb);
    end

endmodule