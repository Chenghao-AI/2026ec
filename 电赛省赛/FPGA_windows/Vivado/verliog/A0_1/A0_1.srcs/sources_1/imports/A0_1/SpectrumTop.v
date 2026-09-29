`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// SpectrumTop — 频谱分析顶层 (8192 点架构)
// ----------------------------------------------------------------------------
//   数据流 (全部在 clk_4m 时钟域):
//     adc_a_signed[11:0]  -> PreMul_Hann         -> x_hanned_16b[15:0]
//                            v
//                          FrameBuf_FFT_Driver  -> AXI-Stream -> xfft_1 (8192点, Scaled)
//                            v
//                          xfft_1.m_axis (32-bit, Re 16 / Im 16)
//                            v
//                          cordic_1 (Translate, 16-bit in / 16-bit out)
//                            v
//                          mag 16-bit + bin_cnt[12:0] (内部计数, 0..8191)
//                            v
//                          BinSelect (取 bin 60..8251, 重新映射相对 0..8191)
//                            v
//                          mark_debug ILA 探针
//
//   ILA probe 输出:
//     ila_probe_mag       : 16-bit
//     ila_probe_bin       : 13-bit (相对 0..8191, 8192 个 bin)
//     ila_probe_valid     : 1-bit
//     ila_probe_adc       : 12-bit
//     ila_probe_frame_end : 1-bit
//     FFT输入帧、Hann窗、bin计数和TLAST均统一为8192点
// ============================================================================
module SpectrumTop (
    input  wire              clk_4m,
    input  wire              rst,
    input  wire signed [11:0] adc_a_signed,
    input  wire              adc_overrange,
    // 暴露给 UART 协议层
    output wire [12:0]       bin_cnt_out,
    output wire [15:0]       cordic_mag_out,
    output wire              cordic_valid_out,
    output wire              frame_end_pulse
);

    // ---- ILA probes (mark_debug = true adds to debug hub) ----
    (* mark_debug = "true" *) wire [15:0] ila_probe_mag;
    (* mark_debug = "true" *) wire [12:0] ila_probe_bin;     // 13-bit, 相对 0..8191
    (* mark_debug = "true" *) wire        ila_probe_valid;
    (* mark_debug = "true" *) wire [11:0] ila_probe_adc;
    (* mark_debug = "true" *) wire        ila_probe_frame_end;

    // ---- Pre-Mul Hann ----
    wire signed [15:0] x_hanned_16b;
    wire [12:0]        cur_wr_addr;

    // ---- 暴露 CORDIC 输出 / bin_cnt 给顶层 (用于 UART 协议层 spectrum_buffer) ----
    assign bin_cnt_out = bin_cnt;
    assign cordic_mag_out = cordic_mag;
    assign cordic_valid_out = cordic_mag_tvalid;
    assign frame_end_pulse = frame_end_out;

    PreMul_Hann u_hann (
        .clk          (clk_4m),
        .rst          (rst),
        .x_in         (adc_a_signed),
        .idx          (cur_wr_addr),
        .x_hanned_16b (x_hanned_16b)
    );

    // ---- FrameBuf + AXI-Stream Driver (8192 BRAM) ----
    wire [31:0] fft_s_tdata;
    wire        fft_s_tvalid;
    wire        fft_s_tlast;
    wire        fft_s_tready;
    wire [15:0] fft_cfg_tdata;
    wire        fft_cfg_tvalid;
    wire        wr_full;
    wire        frame_end_out;
    wire        capture_active;

    FrameBuf_FFT_Driver u_driver (
        .clk                   (clk_4m),
        .rst                   (rst),
        .x_hanned_in           (x_hanned_16b),
        .wr_full               (wr_full),
        .frame_end_out         (frame_end_out),
        .cur_wr_addr           (cur_wr_addr),
        .capture_active        (capture_active),
        .s_axis_data_tdata     (fft_s_tdata),
        .s_axis_data_tvalid    (fft_s_tvalid),
        .s_axis_data_tlast     (fft_s_tlast),
        .s_axis_data_tready    (fft_s_tready),
        .s_axis_config_tdata   (fft_cfg_tdata),
        .s_axis_config_tvalid  (fft_cfg_tvalid)
    );

    // ---- FFT IP ----
    wire [31:0] fft_m_tdata;
    wire        fft_m_tvalid;
    wire        fft_m_tlast;
    wire        fft_m_tready;
    wire        fft_m_tuser;

    assign fft_m_tready = 1'b1;

    xfft_1 u_fft (
        .aclk                       (clk_4m),
        .s_axis_config_tdata        (fft_cfg_tdata),
        .s_axis_config_tvalid       (fft_cfg_tvalid),
        .s_axis_config_tready       (),
        .s_axis_data_tdata          (fft_s_tdata),
        .s_axis_data_tvalid         (fft_s_tvalid),
        .s_axis_data_tready         (fft_s_tready),
        .s_axis_data_tlast          (fft_s_tlast),
        .m_axis_data_tdata          (fft_m_tdata),
        .m_axis_data_tvalid         (fft_m_tvalid),
        .m_axis_data_tready         (fft_m_tready),
        .m_axis_data_tlast          (fft_m_tlast),
        .event_frame_started        (),
        .event_tlast_unexpected     (),
        .event_tlast_missing        (),
        .event_status_channel_halt  (),
        .event_data_in_channel_halt (),
        .event_data_out_channel_halt()
    );

    // ---- FFT-frame validity guard ----
    // The six-bit FFT schedule is safe for any input sequence whose absolute
    // sample value is <=255 codes.  The competition signal is well below this
    // guard.  ADC ORA or an unexpected larger sample invalidates the complete
    // frame, so clipping/overflow-created harmonics never enter the spectrum
    // ping-pong buffer.
    wire adc_guard_exceeded =
        adc_overrange
        || ($signed(adc_a_signed) > 12'sd255)
        || ($signed(adc_a_signed) < -12'sd255);

    reg capture_invalid = 1'b0;
    reg pending_frame_invalid = 1'b0;
    reg fft_output_active = 1'b0;
    reg fft_output_invalid = 1'b0;
    (* mark_debug = "true" *) reg [31:0] rejected_fft_frames = 32'd0;

    always @(posedge clk_4m) begin
        if (rst) begin
            capture_invalid      <= 1'b0;
            pending_frame_invalid <= 1'b0;
            fft_output_active    <= 1'b0;
            fft_output_invalid   <= 1'b0;
            rejected_fft_frames  <= 32'd0;
        end else begin
            if (capture_active && adc_guard_exceeded)
                capture_invalid <= 1'b1;

            if (wr_full) begin
                pending_frame_invalid <= capture_invalid;
                if (capture_invalid)
                    rejected_fft_frames <= rejected_fft_frames + 1'b1;
                capture_invalid <= 1'b0;
            end

            if (fft_m_tvalid) begin
                if (!fft_output_active) begin
                    fft_output_invalid <= pending_frame_invalid;
                    fft_output_active  <= 1'b1;
                end
                if (fft_m_tlast)
                    fft_output_active <= 1'b0;
            end
        end
    end

    wire drop_fft_output =
        fft_output_active ? fft_output_invalid : pending_frame_invalid;
    wire fft_to_cordic_valid = fft_m_tvalid && !drop_fft_output;

    // ---- CORDIC ----
    wire [31:0] cordic_dout;
    wire        cordic_mag_tvalid;

    cordic_1 u_cordic (
        .aclk                   (clk_4m),
        .s_axis_cartesian_tvalid(fft_to_cordic_valid),
        .s_axis_cartesian_tdata (fft_m_tdata),
        .m_axis_dout_tvalid     (cordic_mag_tvalid),
        .m_axis_dout_tdata      (cordic_dout)
    );

    wire [15:0] cordic_mag = cordic_dout[15:0];

    // ---- 内部 bin 计数器 (13-bit, 0..8191) ----
    reg [12:0] bin_cnt = 13'd0;
    always @(posedge clk_4m) begin
        if (rst) bin_cnt <= 13'd0;
        else if (cordic_mag_tvalid) begin
            if (bin_cnt == 13'd8191) bin_cnt <= 13'd0;
            else                      bin_cnt <= bin_cnt + 13'd1;
        end
    end

    // ---- BinSelect (bin 60..8251 -> 相对 0..8191) ----
    wire [23:0] bin_mag_24;
    wire [12:0] bin_bin_13;
    wire        bin_valid;

    BinSelect #(
        .BIN_LO    (15'd0),     // 由外部 wire 补偿，固定 0
        .BIN_HI    (15'd8191),
        .OUT_WIDTH (13)
    ) u_binsel (
        .clk         (clk_4m),
        .rst         (rst),
        .mag_in      ({8'd0, cordic_mag}),
        .bin_in      ({2'b00, bin_cnt} + 15'd200), // 保留原ILA显示偏置
        .mag_in_valid(cordic_mag_tvalid),
        .mag_out     (bin_mag_24),
        .bin_out     (bin_bin_13),
        .valid_out   (bin_valid)
    );

    // ---- ILA probe 赋值 ----
    assign ila_probe_mag       = bin_valid ? bin_mag_24[15:0] : 16'd0;
    assign ila_probe_bin       = bin_valid ? bin_bin_13      : 13'd0;
    assign ila_probe_valid     = bin_valid;
    assign ila_probe_adc       = adc_a_signed;
    assign ila_probe_frame_end = frame_end_out;

endmodule
`default_nettype wire
