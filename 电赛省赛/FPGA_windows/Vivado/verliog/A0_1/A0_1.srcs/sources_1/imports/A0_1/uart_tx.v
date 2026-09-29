`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// uart_tx.v — 通用异步 UART 发送器 (460800-8-N-1)
// ----------------------------------------------------------------------------
//   1 起始位 + 8 数据位 (LSB first) + 1 停止位
//
//   用 clk_uart 作为 bit 时钟. 1 个 bit 周期 = CLK_FREQ / BAUD.
//   通过参数 CLK_FREQ, BAUD 适配任意时钟域.
//
//   接口协议 (单 byte):
//     1. tx_start 上拉 1 个 clk_uart 周期
//     2. tx_busy 变高, tx_serial 输出起始位/数据位/停止位
//     3. tx_busy 变低后, tx_serial 保持 1 (idle)
//
//   使用:
//     if (!tx_busy && need_send) begin
//         tx_data <= byte;
//         tx_start <= 1;
//     end else begin
//         tx_start <= 0;
//     end
// ============================================================================
module uart_tx #(
    parameter integer CLK_FREQ = 14745600,  // 时钟频率 (Hz)
    parameter integer BAUD     = 460800     // 波特率
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_start,    // 1 周期脉冲
    output reg        tx_serial = 1'b1,
    output wire       tx_busy
);

    localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD;
    localparam integer CYCLES_PER_BIT_W = $clog2(CYCLES_PER_BIT + 1);

    // 状态机
    localparam S_IDLE = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]              state = S_IDLE;
    reg [CYCLES_PER_BIT_W-1:0] tick_cnt = 0;
    reg [3:0]              bit_idx = 0;     // 0..8 (8 数据位)
    reg [7:0]              tx_shift = 8'd0;

    assign tx_busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            tx_serial <= 1'b1;
            tick_cnt <= 0;
            bit_idx  <= 0;
            tx_shift <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    tick_cnt  <= 0;
                    bit_idx   <= 0;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_serial <= 1'b0;   // 起始位
                        state    <= S_START;
                        tick_cnt <= 0;
                    end
                end

                S_START: begin
                    if (tick_cnt == CYCLES_PER_BIT - 1) begin
                        tx_serial <= tx_shift[0];  // 数据位 0 (LSB)
                        state    <= S_DATA;
                        tick_cnt <= 0;
                        bit_idx  <= 1;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                S_DATA: begin
                    if (tick_cnt == CYCLES_PER_BIT - 1) begin
                        tick_cnt <= 0;
                        if (bit_idx == 8) begin
                            tx_serial <= 1'b1;       // 停止位
                            state    <= S_STOP;
                            bit_idx  <= 0;
                        end else begin
                            tx_serial <= tx_shift[bit_idx];
                            bit_idx  <= bit_idx + 1;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                S_STOP: begin
                    if (tick_cnt == CYCLES_PER_BIT - 1) begin
                        tx_serial <= 1'b1;
                        state    <= S_IDLE;
                        tick_cnt <= 0;
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
