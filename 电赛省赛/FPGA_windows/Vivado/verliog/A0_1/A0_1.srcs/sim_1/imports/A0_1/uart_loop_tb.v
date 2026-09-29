`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// uart_loop_tb.v — UART 闭环测试 (TX → RX)
// ============================================================================
module uart_loop_tb;
    reg        clk = 0;
    reg        rst = 1;
    reg [7:0]  tx_data = 0;
    reg        tx_start = 0;
    wire       tx_serial;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_ready;
    wire       rx_error;

    uart_tx #(
        .CLK_FREQ (14745600),
        .BAUD     (460800)
    ) u_tx (
        .clk       (clk),
        .rst       (rst),
        .tx_data   (tx_data),
        .tx_start  (tx_start),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ (14745600),
        .BAUD     (460800)
    ) u_rx (
        .clk       (clk),
        .rst       (rst),
        .rx_serial (tx_serial),  // 闭环
        .rx_data   (rx_data),
        .rx_ready  (rx_ready),
        .rx_error  (rx_error)
    );

    always #33.91 clk = ~clk;

    integer i;
    integer pass_cnt = 0;
    integer fail_cnt = 0;
    reg [7:0] expected;

    initial begin
        $display("=== UART Loopback Test ===");
        #100 rst = 0;
        #1000;

        for (i = 0; i < 4; i = i + 1) begin
            expected = i + 8'hC0;  // C0, C1, C2, C3
            $display("Sending 0x%02h ...", expected);

            @(posedge clk);
            tx_data  = expected;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;

            // 等 RX 接收到
            @(posedge rx_ready);
            $display("Received 0x%02h (expected 0x%02h) error=%b", rx_data, expected, rx_error);
            if (rx_data === expected && rx_error === 0) begin
                $display("PASS");
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL");
                fail_cnt = fail_cnt + 1;
            end

            // 等 rx_ready 归零
            @(posedge clk);
            #1000;
        end

        $display("=== UART Loopback Result: %0d PASS, %0d FAIL ===", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
`default_nettype wire
