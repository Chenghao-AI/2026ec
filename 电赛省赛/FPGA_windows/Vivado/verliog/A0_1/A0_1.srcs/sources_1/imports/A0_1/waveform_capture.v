`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// waveform_capture.v — 环形缓存 ADC 原始 12-bit signed 数据 + Vpp/Vrms 统计
// ----------------------------------------------------------------------------
//   深度 32768 × 12-bit (与 FrameBuf_FFT_Driver 同周期采样)
//
//   功能:
//     1. 在 clk_4m 时钟域, 每周期把 adc_in 写入环形 BRAM
//     2. 写指针 wr_addr 自增, 满 32768 后回卷到 0, 同时 frame_pulse 1 周期脉冲
//     3. 实时统计 Vpp = max - min, Vrms = sqrt(Σx²/N)
//
//   读接口:
//     rd_data 直接通过 wr_addr - RD_LEN + rd_idx 读出最近 2048 个 sample
//
//   ADC 12-bit signed → 协议 0.01 mV 单位: value = adc * 122
//   ADC 1 LSB = 5 V / 4096 = 1.221 mV = 122 × 0.01 mV
// ============================================================================
module waveform_capture #(
    parameter integer BRAM_DEPTH = 32768,
    parameter integer RD_LEN     = 2048
)(
    input  wire              clk_4m,
    input  wire              rst,

    // 写接口
    input  wire signed [11:0] adc_in,

    // 读接口
    input  wire              snapshot,
    input  wire [10:0]       rd_idx,        // 0..2047, 从末地址倒数
    output wire signed [11:0] rd_data,

    // Vpp / Vrms 统计接口
    output wire signed [11:0] max_val,
    output wire signed [11:0] min_val,
    output wire [31:0]        sum_sq,

    // frame 同步
    output wire               frame_pulse   // 每 32768 sample 一个 1 周期脉冲
);

    localparam ADDR_W = 15;  // 32768 = 2^15

    // ---- 写指针 + BRAM ----
    reg [ADDR_W-1:0] wr_addr = 0;
    reg              frame_pulse_r = 0;

    (* ram_style = "block" *) reg signed [11:0] bram [0:BRAM_DEPTH-1];

    always @(posedge clk_4m) begin
        if (rst) begin
            wr_addr       <= 0;
            frame_pulse_r <= 1'b0;
        end else begin
            frame_pulse_r <= 1'b0;
            bram[wr_addr] <= adc_in;
            if (wr_addr == {ADDR_W{1'b1}}) begin
                wr_addr       <= 0;
                frame_pulse_r <= 1'b1;     // 刚写完第 32768 个 sample
            end else begin
                wr_addr <= wr_addr + 1'b1;
            end
        end
    end

    // ---- 同步读 BRAM (用于 BRAM 推断) ----
    reg [ADDR_W-1:0] snapshot_base_addr = 0;
    reg signed [11:0] rd_data_r = 12'sd0;
    wire [ADDR_W-1:0] rd_addr_comb = snapshot_base_addr + rd_idx;
    always @(posedge clk_4m) begin
        if (rst) begin
            snapshot_base_addr <= 0;
            rd_data_r <= 12'sd0;
        end else begin
            if (snapshot)
                snapshot_base_addr <= wr_addr - RD_LEN[ADDR_W-1:0];
            rd_data_r <= bram[rd_addr_comb];
        end
    end

    assign rd_data = rd_data_r;

    // ---- Vpp / Vrms 统计 ----
    // 每 frame (32768 sample) 内统计
    reg signed [11:0] max_v     = 12'sd0;
    reg signed [11:0] min_v     = 12'sd0;
    reg [31:0]        sum_sq_v  = 32'd0;
    reg [31:0]        cnt_v     = 32'd0;
    reg signed [11:0] max_v_out = 12'sd0;
    reg signed [11:0] min_v_out = 12'sd0;
    reg [31:0]        sum_sq_v_out = 32'd0;

    always @(posedge clk_4m) begin
        if (rst) begin
            max_v        <= 12'sd0;
            min_v        <= 12'sd0;
            sum_sq_v     <= 32'd0;
            cnt_v        <= 32'd0;
            max_v_out    <= 12'sd0;
            min_v_out    <= 12'sd0;
            sum_sq_v_out <= 32'd0;
        end else begin
            // 实时统计
            if (adc_in > max_v) max_v <= adc_in;
            if (adc_in < min_v) min_v <= adc_in;
            sum_sq_v <= sum_sq_v + (adc_in * adc_in);
            cnt_v    <= cnt_v + 1'b1;

            // 满 32768 -> 输出当前 frame 统计并复位
            if (cnt_v == 32'd32767) begin
                max_v_out     <= max_v;
                min_v_out     <= min_v;
                sum_sq_v_out  <= sum_sq_v;
                max_v     <= 12'sd0;
                min_v     <= 12'sd0;
                sum_sq_v  <= 32'd0;
                cnt_v     <= 32'd0;
            end
        end
    end

    assign max_val = max_v_out;
    assign min_val = min_v_out;
    assign sum_sq  = sum_sq_v_out;
    assign frame_pulse = frame_pulse_r;

endmodule
`default_nettype wire
