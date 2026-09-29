`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// top.v — 频谱分析 + STM32 UART 协议集成 (CHA only, 8192 点 FFT)
// ----------------------------------------------------------------------------
//   时钟域:
//     clk_50m   (U18) — 板载 50 MHz
//       ├─► clk_wiz_0 ──► clk_uart  (14.7456 MHz, 460800 baud × 32)
//       └─► MMCM_Wrapper ──► clk_8m ──► DivideBy2_BUFG ──► clk_4m (全局)
//
//   数据流:
//     ADC CHA 12-bit (signed)
//       └─► AdcChaCapture ──► adc_a_signed ──►
//             ├─► SpectrumTop (FFT 8192, CORDIC) ──► mag + bin
//             └─► waveform_capture (环形 32768×12 BRAM, Vpp/Vrms)
//       └─► spectrum_buffer (缓存 1116 点 5~550 kHz)
//
//   协议:
//     STM32 USART2 ──► J11 PIN4 (F16) ──► uart_rx ──► protocol_engine
//     protocol_engine ──► uart_tx ──► J11 PIN3 (F17) ──► STM32 USART2
//
//   引脚约束:
//     R14..P15 = ADC CHA 数据
//     P14 = ADC ACLK 输出 (4 MHz ODDR)
//     P16 = ADC ORA
//     F16 = J11 PIN4 = uart_rx_from_stm
//     F17 = J11 PIN3 = uart_tx_to_stm
// ============================================================================
module top (
    input  wire        clk_50m,
    input  wire [11:0] adc_a_data,
    input  wire        adc_a_ora,
    output wire        adc_aclk_p14,

    // UART 接口 (J11)
    input  wire        uart_rx_from_stm,   // F16 (PIN4)
    output wire        uart_tx_to_stm,     // F17 (PIN3)
    output wire [3:0]  led_status          // 4 个状态 LED (debug)
);

    // ============================================================
    // 时钟域
    // ============================================================
    wire mmcm_locked;
    wire clk_8m;
    wire clk_4m;
    wire clk_uart;
    wire clk_wiz_locked;

    // MMCM (50 → 8 MHz)
    MMCM_Wrapper u_mmcm (
        .CLKIN1    (clk_50m),
        .CLKFBOUT  (),
        .CLKOUT0   (clk_8m),
        .CLKOUT1   (),
        .RESETN    (1'b1),
        .LOCKED    (mmcm_locked)
    );

    // 8 → 4 MHz 二分频
    DivideBy2_BUFG u_div2 (
        .clk_8m (clk_8m),
        .clk_4m (clk_4m)
    );

    // ADC 采样时钟 (ODDR 4 MHz)
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT        (1'b0),
        .SRTYPE      ("SYNC")
    ) u_oddr_aclk (
        .Q (adc_aclk_p14),
        .C (clk_4m),
        .CE(1'b1),
        .D1(1'b0),
        .D2(1'b1),
        .R (1'b0),
        .S (1'b0)
    );

    // Clock Wizard (50 → 14.7456 MHz, 用于 UART 460800 baud × 32)
    // 注意: clk_in1 不能直接连顶层 clk_50m, 否则 vivado 把 clk_50m 既当 IO 又当内部 logic 报错
    wire clk_wiz_in;
    BUFG bufg_clk_wiz (.I(clk_50m), .O(clk_wiz_in));
    clk_wiz_0 u_clk_wiz (
        .clk_in1  (clk_wiz_in),
        .locked   (clk_wiz_locked),
        .clk_out1 (clk_uart)
    );

    // ============================================================
    // ADC 数据对齐
    // ============================================================
    wire signed [11:0] adc_a_signed;
    wire               ora_synced;
    AdcChaCapture u_adc_cap (
        .clk_4m        (clk_4m),
        .adc_a_raw     (adc_a_data),
        .ora_raw       (adc_a_ora),
        .adc_a_signed  (adc_a_signed),
        .ora_out       (ora_synced)
    );

    // ============================================================
    // 频谱分析 (SpectrumTop 现在暴露 CORDIC 输出 + bin_cnt)
    // ============================================================
    wire [12:0] spec_bin_cnt;
    wire [15:0] spec_cordic_mag;
    wire        spec_cordic_valid;
    wire        spec_frame_end;

    SpectrumTop u_spec (
        .clk_4m              (clk_4m),
        .rst                 (~mmcm_locked),
        .adc_a_signed        (adc_a_signed),
        .adc_overrange       (ora_synced),
        .bin_cnt_out         (spec_bin_cnt),
        .cordic_mag_out      (spec_cordic_mag),
        .cordic_valid_out    (spec_cordic_valid),
        .frame_end_pulse     (spec_frame_end)
    );

    // ============================================================
    // 波形采集 (环形 BRAM 32768×12)
    // ============================================================
    wire signed [11:0] wave_max;
    wire signed [11:0] wave_min;
    wire [31:0]        wave_sum_sq;
    wire               wave_frame_pulse;
    wire [10:0]        wave_rd_idx_o;
    wire signed [11:0] wave_rd_data_o;
    wire               proto_snapshot;

    waveform_capture u_wave_cap (
        .clk_4m      (clk_4m),
        .rst         (~mmcm_locked),
        .adc_in      (adc_a_signed),
        .snapshot    (proto_snapshot),
        .rd_idx      (wave_rd_idx_o),
        .rd_data     (wave_rd_data_o),
        .max_val     (wave_max),
        .min_val     (wave_min),
        .sum_sq      (wave_sum_sq),
        .frame_pulse (wave_frame_pulse)
    );

    // ============================================================
    // 频谱缓存 (1116 点, real_bin 11..1126 对应 5~550 kHz)
    // ============================================================
    wire [15:0] spec_rd_data_o;
    wire [10:0] spec_rd_idx_o;
    wire        spec_ready_o;

    spectrum_buffer u_spec_buf (
        .clk_4m       (clk_4m),
        .rst          (~mmcm_locked),
        .cordic_mag_in(spec_cordic_mag),
        .cordic_bin_in(spec_bin_cnt),
        .mag_valid    (spec_cordic_valid),
        .snapshot     (proto_snapshot),
        .rd_addr      (spec_rd_idx_o),
        .rd_data      (spec_rd_data_o),
        .frame_ready  (spec_ready_o)
    );

    // ============================================================
    // 协议引擎
    // ============================================================
    wire proto_error;
    wire proto_busy;

    protocol_engine u_proto (
        .clk_4m       (clk_4m),
        .clk_uart     (clk_uart),
        .rst          (~mmcm_locked || ~clk_wiz_locked),

        .rx_serial    (uart_rx_from_stm),
        .tx_serial    (uart_tx_to_stm),

        .wave_max     (wave_max),
        .wave_min     (wave_min),

        .wave_rd_idx  (wave_rd_idx_o),
        .wave_rd_data (wave_rd_data_o),

        .spec_rd_idx  (spec_rd_idx_o),
        .spec_rd_data (spec_rd_data_o),
        .data_ready   (spec_ready_o),

        .snapshot_pulse(proto_snapshot),
        .error_state  (proto_error),
        .busy         (proto_busy)
    );

    // ============================================================
    // LED 状态指示
    // ============================================================
    // AX7020 PL LEDs are active-low.
    assign led_status[0] = ~mmcm_locked;       // lit: MMCM OK
    assign led_status[1] = ~clk_wiz_locked;    // lit: UART clock OK
    assign led_status[2] = ~proto_busy;        // lit: UART protocol busy
    assign led_status[3] = ~proto_error;       // lit: communication error

    // ============================================================
    // ILA 调试 (保留原 5 个 probe)
    // ============================================================
    ila_0 u_ila_0 (
        .clk                 (clk_4m),
        .probe0              (u_spec.ila_probe_mag),
        .probe1              (u_spec.ila_probe_bin),
        .probe2              (u_spec.ila_probe_valid),
        .probe3              (u_spec.ila_probe_adc),
        .probe4              (u_spec.ila_probe_frame_end)
    );

endmodule
`default_nettype wire
