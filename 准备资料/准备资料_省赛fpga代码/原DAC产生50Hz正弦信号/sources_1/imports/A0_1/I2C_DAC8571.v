`timescale 1ns / 1ps

module I2C_DAC8571(
    input  wire        clock,         // 50MHz 主时钟
    input  wire        reset,         // 高电平复位
    input  wire        io_start,      // 启动信号
    input  wire [15:0] io_data_in,    // 16位 DAC 数据
    input  wire        io_sda_in,     // SDA 输入
    output wire        io_busy,       // 忙状态
    output wire        io_done,       // 完成信号 (单脉冲)
    output wire        io_ack_error,  // 应答错误
    output wire        io_scl,        // SCL 时钟 (400kHz)
    output wire        io_sda_out,    // SDA 输出
    output wire        io_sda_en      // SDA 输出使能
);

    // 状态定义
    localparam STATE_IDLE   = 4'd0;
    localparam STATE_START  = 4'd1;
    localparam STATE_ADDR   = 4'd2;
    localparam STATE_ACK1   = 4'd3;
    localparam STATE_CTRL   = 4'd4;
    localparam STATE_ACK2   = 4'd5;
    localparam STATE_DATA_H = 4'd6;
    localparam STATE_ACK3   = 4'd7;
    localparam STATE_DATA_L = 4'd8;
    localparam STATE_ACK4   = 4'd9;
    localparam STATE_STOP   = 4'd10;

    reg [3:0] state = STATE_IDLE;
    reg [6:0] div_cnt = 7'd0;       // 0-124 计数，产生 400kHz SCL
    reg [2:0] bit_cnt = 3'd0;
    reg [7:0] shift_reg = 8'h00;
    reg [15:0] data_reg = 16'h0000;

    reg scl_reg = 1'b1;
    reg sda_out_reg = 1'b1;
    reg sda_en_reg = 1'b0;
    reg busy_reg = 1'b0;
    reg done_reg = 1'b0;
    reg ack_error_reg = 1'b0;

    assign io_scl = scl_reg;
    assign io_sda_out = sda_out_reg;
    assign io_sda_en = sda_en_reg;
    assign io_busy = busy_reg;
    assign io_done = done_reg;
    assign io_ack_error = ack_error_reg;

    always @(posedge clock) begin
        if (reset) begin
            state         <= STATE_IDLE;
            div_cnt       <= 7'd0;
            bit_cnt       <= 3'd0;
            shift_reg     <= 8'h00;
            data_reg      <= 16'h0000;
            scl_reg       <= 1'b1;
            sda_out_reg   <= 1'b1;
            sda_en_reg    <= 1'b0;
            busy_reg      <= 1'b0;
            done_reg      <= 1'b0;
            ack_error_reg <= 1'b0;
        end else begin
            done_reg <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    scl_reg     <= 1'b1;
                    sda_out_reg <= 1'b1;
                    sda_en_reg  <= 1'b0;
                    busy_reg    <= 1'b0;
                    div_cnt     <= 7'd0;

                    if (io_start) begin
                        state         <= STATE_START;
                        data_reg      <= io_data_in;
                        busy_reg      <= 1'b1;
                        ack_error_reg <= 1'b0;
                    end
                end

                STATE_START: begin
                    sda_en_reg <= 1'b1;
                    if (div_cnt < 7'd62) begin
                        scl_reg     <= 1'b1;
                        sda_out_reg <= 1'b1;
                    end else begin
                        scl_reg     <= 1'b1;
                        sda_out_reg <= 1'b0; // Start Condition
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        state     <= STATE_ADDR;
                        bit_cnt   <= 3'd0;
                        shift_reg <= 8'h98; // 写地址
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_ADDR: begin
                    sda_en_reg  <= 1'b1;
                    sda_out_reg <= shift_reg[7];
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        if (bit_cnt == 3'd7) begin
                            state   <= STATE_ACK1;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_ACK1: begin
                    sda_en_reg  <= 1'b0;
                    sda_out_reg <= 1'b1;
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd93) begin // 1.25us 处采样 ACK
                        if (io_sda_in == 1'b1) begin
                            ack_error_reg <= 1'b1;
                        end
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        state     <= STATE_CTRL;
                        bit_cnt   <= 3'd0;
                        shift_reg <= 8'h10; // 控制字节 (0x10表示写数据并更新)
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_CTRL: begin
                    sda_en_reg  <= 1'b1;
                    sda_out_reg <= shift_reg[7];
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        if (bit_cnt == 3'd7) begin
                            state   <= STATE_ACK2;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_ACK2: begin
                    sda_en_reg  <= 1'b0;
                    sda_out_reg <= 1'b1;
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd93) begin
                        if (io_sda_in == 1'b1) begin
                            ack_error_reg <= 1'b1;
                        end
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        state     <= STATE_DATA_H;
                        bit_cnt   <= 3'd0;
                        shift_reg <= data_reg[15:8]; // 高8位
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_DATA_H: begin
                    sda_en_reg  <= 1'b1;
                    sda_out_reg <= shift_reg[7];
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        if (bit_cnt == 3'd7) begin
                            state   <= STATE_ACK3;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_ACK3: begin
                    sda_en_reg  <= 1'b0;
                    sda_out_reg <= 1'b1;
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd93) begin
                        if (io_sda_in == 1'b1) begin
                            ack_error_reg <= 1'b1;
                        end
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        state     <= STATE_DATA_L;
                        bit_cnt   <= 3'd0;
                        shift_reg <= data_reg[7:0]; // 低8位
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_DATA_L: begin
                    sda_en_reg  <= 1'b1;
                    sda_out_reg <= shift_reg[7];
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        if (bit_cnt == 3'd7) begin
                            state   <= STATE_ACK4;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_ACK4: begin
                    sda_en_reg  <= 1'b0;
                    sda_out_reg <= 1'b1;
                    scl_reg     <= (div_cnt >= 7'd62);

                    if (div_cnt == 7'd93) begin
                        if (io_sda_in == 1'b1) begin
                            ack_error_reg <= 1'b1;
                        end
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt   <= 7'd0;
                        state     <= STATE_STOP;
                    end else begin
                        div_cnt   <= div_cnt + 7'd1;
                    end
                end

                STATE_STOP: begin
                    sda_en_reg <= 1'b1;
                    if (div_cnt < 7'd62) begin
                        scl_reg     <= 1'b0;
                        sda_out_reg <= 1'b0;
                    end else if (div_cnt < 7'd93) begin
                        scl_reg     <= 1'b1;
                        sda_out_reg <= 1'b0;
                    end else begin
                        scl_reg     <= 1'b1;
                        sda_out_reg <= 1'b1; // Stop Condition
                    end

                    if (div_cnt == 7'd124) begin
                        div_cnt  <= 7'd0;
                        state    <= STATE_IDLE;
                        busy_reg <= 1'b0;
                        done_reg <= 1'b1;
                    end else begin
                        div_cnt  <= div_cnt + 7'd1;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule