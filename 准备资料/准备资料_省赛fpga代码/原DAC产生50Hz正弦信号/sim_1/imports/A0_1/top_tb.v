`timescale 1ns / 1ps

module top_tb;

    reg clk_50m = 0;
    wire sda;
    wire scl;
    wire dac_led;
    wire ack_led; // 接入顶层的 ack_led 方便观察应答状态

    // 产生 50MHz 时钟 (周期 20ns)
    always #10 clk_50m = ~clk_50m;

    // 1. 模拟 I2C 总线的外部上拉电阻（仿真中必须存在，否则总线电平会呈现 Z 或 X）
    pullup(sda);
    pullup(scl);

    // 2. 简易的 I2C 模拟从机(DAC)应答产生逻辑（已修改为纯标准 Verilog 写法）
    // 该逻辑会在检测到 I2C 起始信号后，自动在第 9 个时钟周期将 SDA 拉低，模拟 DAC 产生 ACK 应答
    reg sda_out = 1'bz;
    assign sda = sda_out;

    always @(negedge sda) begin
        if (scl == 1'b1) begin
            // 检测到起始信号 (SDA 在 SCL 高电平时拉低)
            
            // ① 应答器件地址字节 (Address Byte ACK)
            repeat(8) @(posedge scl);
            @(negedge scl);
            sda_out <= 1'b0; // 产生 ACK
            @(negedge scl);
            sda_out <= 1'bz; // 释放总线

            // ② 应答数据高字节 (High Data Byte ACK)
            repeat(8) @(posedge scl);
            @(negedge scl);
            sda_out <= 1'b0; 
            @(negedge scl);
            sda_out <= 1'bz;

            // ③ 应答数据低字节 (Low Data Byte ACK)
            repeat(8) @(posedge scl);
            @(negedge scl);
            sda_out <= 1'b0; 
            @(negedge scl);
            sda_out <= 1'bz;
        end
    end

    // 3. 例化顶层设计
    top u_top (
        .clk_50m (clk_50m),
        .sda     (sda),
        .scl     (scl),
        .dac_led (dac_led),
        .ack_led (ack_led)
    );

    // 4. 保存仿真波形
    initial begin
        $dumpfile("tb_waveform.vcd");
        $dumpvars(0, top_tb);
    end

    // 5. 仿真时间控制
    // 由于正弦波周期较长，这里设置 5ms（即 5_000_000 ns）以观察多组 I2C 发送行为
    initial begin
        #5_000_000;  
        $display("=== Simulation Complete ===");
        $finish;
    end

endmodule