`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// FrameBuf_FFT_Driver — 32768 sample BRAM + AXI-Stream 驱动 FFT
// ----------------------------------------------------------------------------
//   单一状态机 (FSM):
//     S_IDLE  : 连续写 BRAM 采样, 满 32768 -> S_READ (wr_full 单周期脉冲)
//     S_READ  : 推 rd_addr 给 FFT, 帧末 (rd_addr==32767 && tready) -> S_IDLE
//
//   AXI-Stream:
//     s_axis_config_tdata  = 16'h0001  (Forward)
//     s_axis_config_tvalid = 1'b1
//     s_axis_data_tdata    = {16'd0, sample_in}    32-bit (Re 16, Im 16)
//     s_axis_data_tvalid   = (state == S_READ)
//     s_axis_data_tlast    = (rd_addr==32767) && tvalid && tready
//
//   注: BRAM 深度 32768 (2^15)，地址宽度 15 位。
//       资源估算: 32768 × 16 = 524288 bit ≈ 64 BRAM18K
// ============================================================================
module FrameBuf_FFT_Driver (
    input  wire              clk,
    input  wire              rst,
    input  wire signed [15:0] x_hanned_in,
    output wire              wr_full,
    output wire              frame_end_out,
    output wire [14:0]       cur_wr_addr,
    output wire [31:0]       s_axis_data_tdata,
    output wire              s_axis_data_tvalid,
    output wire              s_axis_data_tlast,
    input  wire              s_axis_data_tready,
    output wire [15:0]       s_axis_config_tdata,
    output wire              s_axis_config_tvalid
);
    localparam ADDR_W = 15;
    localparam [ADDR_W-1:0] N_FRM = 15'd32767;  // 最大地址 (=32767)
    localparam [ADDR_W-1:0] N_FRM_LO = 15'd0;   // 起始地址 (=0)

    // 配置通道: 上电常高, bit[0]=1 -> Forward
    assign s_axis_config_tdata  = 16'h0001;
    assign s_axis_config_tvalid = 1'b1;

    // BRAM 32768x16
    (* ram_style = "block" *) reg [15:0] buf_ram [0:32767];

    // FSM
    localparam S_IDLE = 1'b0;
    localparam S_READ = 1'b1;
    reg        state = S_IDLE;

    reg [ADDR_W-1:0] wr_addr = {ADDR_W{1'b0}};
    reg [ADDR_W-1:0] rd_addr = {ADDR_W{1'b0}};
    reg              wr_full_r   = 1'b0;
    reg              frame_end_r = 1'b0;

    // 单 always FSM
    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            wr_addr     <= {ADDR_W{1'b0}};
            rd_addr     <= {ADDR_W{1'b0}};
            wr_full_r   <= 1'b0;
            frame_end_r <= 1'b0;
        end else begin
            wr_full_r   <= 1'b0;
            frame_end_r <= 1'b0;

            case (state)
                S_IDLE: begin
                    buf_ram[wr_addr] <= x_hanned_in;
                    if (wr_addr == N_FRM) begin
                        wr_addr   <= N_FRM_LO;
                        rd_addr   <= N_FRM_LO;
                        wr_full_r <= 1'b1;
                        state     <= S_READ;
                    end else begin
                        wr_addr <= wr_addr + 1'b1;
                    end
                end

                S_READ: begin
                    if (s_axis_data_tready) begin
                        if (rd_addr == N_FRM) begin
                            rd_addr     <= N_FRM_LO;
                            frame_end_r <= 1'b1;
                            state       <= S_IDLE;
                        end else begin
                            rd_addr <= rd_addr + 1'b1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign s_axis_data_tdata  = {16'sd0, buf_ram[rd_addr]};
    assign s_axis_data_tvalid = (state == S_READ);
    assign s_axis_data_tlast  = (state == S_READ) && (rd_addr == N_FRM) && s_axis_data_tready;

    assign wr_full       = wr_full_r;
    assign frame_end_out = frame_end_r;
    assign cur_wr_addr   = wr_addr;

endmodule
`default_nettype wire
