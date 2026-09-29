`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// spectrum_buffer.v — 缓存 1116 个 CORDIC 输出 mag (real_bin 11..1126)
// ----------------------------------------------------------------------------
//   输入: FFT bin 0..8191, 每个 bin 对应 CORDIC mag (16-bit)
//   缓存: real_bin 11..1126 (共 1116 点, 对应 5~550 kHz @ fs=4MHz/N=8192)
//
//   实时写入: 当 cordic_bin_in ∈ [11, 1126] 时, mag 写入 rd_addr-11 对应 BRAM 位置
//   读出: rd_addr 索引 (0..1115) 读出 1116 点
//
//   使用 1120×16 BRAM (1120 是 1116 + 4 余量, 满足 ≥ 1116)
//
//   注意: 只读不写时数据冻结, 用于 RESEND 时重发同一帧
// ============================================================================
module spectrum_buffer #(
    parameter integer BIN_LO = 11,
    parameter integer BIN_HI = 1126,
    parameter integer N_SPECTRUM = 1116
)(
    input  wire        clk_4m,
    input  wire        rst,

    // 写接口
    input  wire [15:0] cordic_mag_in,
    input  wire [12:0] cordic_bin_in,  // 0..8191
    input  wire        mag_valid,

    // 读接口
    input  wire        snapshot,
    input  wire [10:0] rd_addr,        // 0..1115
    output wire [15:0] rd_data,

    // 状态
    output reg         frame_ready     // 1: 已完成一次完整缓存 (用于触发协议发送)
);

    localparam ADDR_W = 11;  // 2048 = 2^11 (实际只用 1116)
    localparam [ADDR_W-1:0] BRAM_SIZE = 11'd2047;

    // Ping-pong BRAM: one completed spectrum remains stable for START.
    (* ram_style = "block" *) reg [15:0] bram0 [0:BRAM_SIZE];
    (* ram_style = "block" *) reg [15:0] bram1 [0:BRAM_SIZE];

    reg [ADDR_W-1:0] highest_addr = 0;  // 跟踪最后一个写入地址
    reg write_bank = 1'b0;
    reg completed_bank = 1'b0;
    reg snapshot_bank = 1'b0;

    wire in_range = (cordic_bin_in >= BIN_LO) && (cordic_bin_in <= BIN_HI);
    wire [ADDR_W-1:0] wr_addr = cordic_bin_in - BIN_LO[ADDR_W-1:0];

    // 写
    always @(posedge clk_4m) begin
        if (rst) begin
            highest_addr <= 0;
            frame_ready  <= 1'b0;
            write_bank <= 1'b0;
            completed_bank <= 1'b0;
            snapshot_bank <= 1'b0;
        end else begin
            if (snapshot)
                snapshot_bank <= completed_bank;
            if (mag_valid && in_range) begin
                if (write_bank)
                    bram1[wr_addr] <= cordic_mag_in;
                else
                    bram0[wr_addr] <= cordic_mag_in;
                if (wr_addr > highest_addr) highest_addr <= wr_addr;
                if (wr_addr == (N_SPECTRUM - 1)) begin
                    completed_bank <= write_bank;
                    write_bank <= ~write_bank;
                    highest_addr <= 0;
                    frame_ready <= 1'b1;
                end
            end
        end
    end

    // 同步读 BRAM (1 周期延迟)
    reg [10:0] rd_addr_d = 0;
    reg [15:0] rd_data_r = 16'd0;
    always @(posedge clk_4m) begin
        rd_addr_d <= rd_addr;
        if (snapshot_bank)
            rd_data_r <= bram1[rd_addr];
        else
            rd_data_r <= bram0[rd_addr];
    end

    assign rd_data = rd_data_r;

endmodule
`default_nettype wire
