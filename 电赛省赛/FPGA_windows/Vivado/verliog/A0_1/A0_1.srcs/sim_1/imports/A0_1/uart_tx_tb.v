`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// uart_tx_tb.v — UART TX 测试
// ============================================================================
module uart_tx_tb;
    reg        clk = 0;
    reg        rst = 1;
    reg [7:0]  tx_data = 0;
    reg        tx_start = 0;
    wire       tx_serial;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ (14745600),
        .BAUD     (460800)
    ) u_dut (
        .clk       (clk),
        .rst       (rst),
        .tx_data   (tx_data),
        .tx_start  (tx_start),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy)
    );

    // 14.7456 MHz 时钟
    always #33.91 clk = ~clk;  // period ~67.82 ns = 14.7456 MHz

    integer i;
    initial begin
        $display("=== UART TX Test (BAUD=460800 @ 14.7456 MHz) ===");

        // 启动后等锁
        #100 rst = 0;
        #100;

        // 发送 0x55 (01010101)
        $display("Sending 0x55 ...");
        @(posedge clk);
        tx_data  = 8'h55;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // 等发送完成 (~24 us / 32 cycles)
        #30000;
        $display("After send: tx_serial=%b tx_busy=%b", tx_serial, tx_busy);

        // 发送 0xAA (10101010)
        $display("Sending 0xAA ...");
        @(posedge clk);
        tx_data  = 8'hAA;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        #30000;
        $display("After send: tx_serial=%b tx_busy=%b", tx_serial, tx_busy);

        // 发送连续 3 字节测试 mailbox 频率
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk);
            tx_data  = i + 8'hC0;  // C0, C1, C2
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            #30000;
        end

        $display("=== UART TX Test Done ===");
        $finish;
    end

    // 监视 tx_serial
    initial begin
        forever begin
            @(posedge clk);
            // 1 bit period = 32 cycles
            if (u_dut.state != u_dut.state) ;  // noop
        end
    end

endmodule
`default_nettype wire
