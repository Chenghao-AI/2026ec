`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// uart_rx.v — 通用异步 UART 接收器 (460800-8-N-1, 16× 过采样)
// ----------------------------------------------------------------------------
//   16× 过采样, 在每位中点采样 (第 8 个 clk).
//
//   接口协议 (单 byte):
//     1. 检测 rx_serial 下降沿 -> 进入起始位等待
//     2. 等待 CYCLES_PER_BIT/2 后采样起始位 (确认低电平)
//     3. 每 CYCLES_PER_BIT 周期采样 1 bit, 共 8 bit (LSB first)
//     4. 采样停止位 (高电平); 错则 rx_error
//     5. rx_ready 1 周期脉冲 + rx_data 锁定
//
//   使用:
//     always @(posedge clk) if (rx_ready) rx_ready_d1 <= 1; else ...
// ============================================================================
module uart_rx #(
    parameter integer CLK_FREQ = 14745600,  // 时钟频率 (Hz)
    parameter integer BAUD     = 460800     // 波特率
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_serial,
    output reg  [7:0] rx_data = 8'd0,
    output reg        rx_ready = 1'b0,
    output reg        rx_error = 1'b0
);

    localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD;
    localparam integer CYCLES_PER_BIT_W = $clog2(CYCLES_PER_BIT + 1);
    localparam integer HALF_BIT = CYCLES_PER_BIT / 2;

    // 2-FF 同步 (异步输入)
    reg rx_sync0 = 1'b1;
    reg rx_sync1 = 1'b1;
    always @(posedge clk) begin
        rx_sync0 <= rx_serial;
        rx_sync1 <= rx_sync0;
    end

    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]                state = S_IDLE;
    reg [CYCLES_PER_BIT_W-1:0] tick_cnt = 0;
    reg [3:0]                bit_idx = 0;
    reg [7:0]                rx_shift = 8'd0;
    reg                      rx_sync1_d = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            tick_cnt <= 0;
            bit_idx  <= 0;
            rx_data  <= 8'd0;
            rx_shift <= 8'd0;
            rx_ready <= 1'b0;
            rx_error <= 1'b0;
            rx_sync1_d <= 1'b1;
        end else begin
            rx_ready <= 1'b0;
            rx_error <= 1'b0;
            rx_sync1_d <= rx_sync1;

            case (state)
                S_IDLE: begin
                    tick_cnt <= 0;
                    bit_idx  <= 0;
                    // 检测下降沿 (sync1=1 -> sync1_d=0)
                    if (rx_sync1_d == 1'b1 && rx_sync1 == 1'b0) begin
                        state    <= S_START;
                        tick_cnt <= 0;
                    end
                end

                S_START: begin
                    if (tick_cnt == HALF_BIT - 1) begin
                        // 中点采样, 应当为 0 (起始位)
                        if (rx_sync1 == 1'b0) begin
                            state    <= S_DATA;
                            tick_cnt <= 0;
                            bit_idx  <= 0;
                        end else begin
                            // 假触发, 回 IDLE
                            state <= S_IDLE;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                S_DATA: begin
                    if (tick_cnt == CYCLES_PER_BIT - 1) begin
                        tick_cnt <= 0;
                        rx_shift[bit_idx] <= rx_sync1;
                        if (bit_idx == 7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                S_STOP: begin
                    if (tick_cnt == CYCLES_PER_BIT - 1) begin
                        if (rx_sync1 == 1'b1) begin
                            rx_data  <= rx_shift;
                            rx_ready <= 1'b1;
                        end else begin
                            rx_error <= 1'b1;
                        end
                        state <= S_IDLE;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
