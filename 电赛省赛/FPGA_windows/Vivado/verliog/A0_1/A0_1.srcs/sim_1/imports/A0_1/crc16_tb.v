`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// crc16_tb.v — CRC-16/CCITT-FALSE 测试
// ============================================================================
module crc16_tb;
    reg        clk = 0;
    reg        rst = 1;
    reg        crc_init = 0;
    reg [7:0]  data_in = 0;
    reg        crc_tick = 0;
    wire [15:0] crc_out;

    crc16_ccitt u_dut (
        .clk       (clk),
        .rst       (rst),
        .crc_init  (crc_init),
        .data_in   (data_in),
        .crc_tick  (crc_tick),
        .crc_out   (crc_out)
    );

    always #5 clk = ~clk;  // 100 MHz

    // 参考值: crc("123456789") = 0x29B1
    reg [7:0] test_data [0:8];
    integer i;
    initial begin
        $display("=== CRC-16/CCITT-FALSE Test ===");
        test_data[0] = 8'h31; // '1'
        test_data[1] = 8'h32; // '2'
        test_data[2] = 8'h33; // '3'
        test_data[3] = 8'h34; // '4'
        test_data[4] = 8'h35; // '5'
        test_data[5] = 8'h36; // '6'
        test_data[6] = 8'h37; // '7'
        test_data[7] = 8'h38; // '8'
        test_data[8] = 8'h39; // '9'

        #20 rst = 0;

        // 初始化 CRC
        @(posedge clk); crc_init = 1;
        @(posedge clk); crc_init = 0;

        // 喂入 9 字节
        for (i = 0; i < 9; i = i + 1) begin
            @(posedge clk);
            data_in  = test_data[i];
            crc_tick = 1;
        end
        @(posedge clk); crc_tick = 0;

        // 等待 CRC 计算完成
        @(posedge clk);
        @(posedge clk);

        $display("CRC Result = 0x%04h (expected 0x29B1)", crc_out);
        if (crc_out == 16'h29B1)
            $display("PASS");
        else
            $display("FAIL");

        $finish;
    end
endmodule
`default_nettype wire
