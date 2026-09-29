`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// STM32 <-> FPGA UART protocol engine
//
// UART: 460800-8-N-1
// Frame: AA 55 | TYPE | SEQ | LEN_BE | Payload | CRC16_BE
// CRC:   CRC-16/CCITT-FALSE over TYPE + SEQ + LEN + Payload
//
// Accepted command frames:
//   START  : AA 55 01 SEQ 00 01 01 CRC_H CRC_L
//   STOP   : AA 55 02 SEQ 00 00 CRC_H CRC_L
//   RESEND : AA 55 03 SEQ 00 00 CRC_H CRC_L
//   ACK    : AA 55 10 SEQ 00 00 CRC_H CRC_L
//
// Result frame:
//   AA 55 20 SEQ LEN_H LEN_L Payload CRC_H CRC_L
//
// The result SEQ echoes the START SEQ.  Waveform and spectrum data are copied
// into a communication snapshot before transmission, so an ACK timeout or an
// explicit RESEND always retransmits the same result.
// ============================================================================
module protocol_engine #(
    parameter integer N_WAVEFORM = 2048,
    parameter integer N_SPECTRUM = 1116
)(
    input  wire               clk_4m,
    input  wire               clk_uart,
    input  wire               rst,

    input  wire               rx_serial,
    output wire               tx_serial,

    input  wire signed [11:0] wave_max,
    input  wire signed [11:0] wave_min,

    output wire [10:0]        wave_rd_idx,
    input  wire signed [11:0] wave_rd_data,

    output wire [10:0]        spec_rd_idx,
    input  wire [15:0]        spec_rd_data,
    input  wire               data_ready,

    output wire               snapshot_pulse,
    output wire               error_state,
    output wire               busy
);

    localparam [7:0] TYPE_CMD_START  = 8'h01;
    localparam [7:0] TYPE_CMD_STOP   = 8'h02;
    localparam [7:0] TYPE_CMD_RESEND = 8'h03;
    localparam [7:0] TYPE_ACK        = 8'h10;
    localparam [7:0] TYPE_RESULT     = 8'h20;

    localparam integer PAYLOAD_LEN = 21 + 2*N_WAVEFORM + 2*N_SPECTRUM;
    localparam integer ADC_TO_001MV = 122;
    localparam [31:0] F_START_HZ = 32'd5371;
    localparam [31:0] DF_HZ      = 32'd488;
    localparam [31:0] DT_NS      = 32'd250;

    // 50 ms at 4 MHz.  The initial send plus three retries are allowed.
    localparam [17:0] ACK_TIMEOUT_CYCLES = 18'd200_000;
    localparam [2:0]  MAX_RESEND = 3'd3;

    localparam [13:0] OFF_WAVEFORM = 14'd7;
    localparam [13:0] OFF_VPP      = 14'd7 + 2*N_WAVEFORM;
    localparam [13:0] OFF_VRMS     = 14'd9 + 2*N_WAVEFORM;
    localparam [13:0] OFF_K        = 14'd11 + 2*N_WAVEFORM;
    localparam [13:0] OFF_FSTART   = 14'd13 + 2*N_WAVEFORM;
    localparam [13:0] OFF_DF       = 14'd17 + 2*N_WAVEFORM;
    localparam [13:0] OFF_SPEC     = 14'd21 + 2*N_WAVEFORM;

    function [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0]  data_in;
        integer bit_index;
        reg [15:0] crc_work;
        begin
            crc_work = crc_in ^ {data_in, 8'h00};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (crc_work[15])
                    crc_work = (crc_work << 1) ^ 16'h1021;
                else
                    crc_work = crc_work << 1;
            end
            crc16_next = crc_work;
        end
    endfunction

    // ========================================================================
    // UART physical layer (clk_uart domain)
    // ========================================================================
    wire [7:0] rx_data_uart;
    wire       rx_ready_uart;
    wire       rx_error_uart;

    uart_rx #(
        .CLK_FREQ (14745600),
        .BAUD     (460800)
    ) u_uart_rx (
        .clk       (clk_uart),
        .rst       (rst),
        .rx_serial (rx_serial),
        .rx_data   (rx_data_uart),
        .rx_ready  (rx_ready_uart),
        .rx_error  (rx_error_uart)
    );

    wire       tx_busy_uart;
    reg  [7:0] tx_data_uart  = 8'd0;
    reg        tx_start_uart = 1'b0;

    uart_tx #(
        .CLK_FREQ (14745600),
        .BAUD     (460800)
    ) u_uart_tx (
        .clk       (clk_uart),
        .rst       (rst),
        .tx_data   (tx_data_uart),
        .tx_start  (tx_start_uart),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy_uart)
    );

    // ========================================================================
    // Complete command-frame parser (clk_uart domain)
    // ========================================================================
    localparam [3:0] RX_WAIT_AA = 4'd0;
    localparam [3:0] RX_WAIT_55 = 4'd1;
    localparam [3:0] RX_TYPE    = 4'd2;
    localparam [3:0] RX_SEQ     = 4'd3;
    localparam [3:0] RX_LEN_H   = 4'd4;
    localparam [3:0] RX_LEN_L   = 4'd5;
    localparam [3:0] RX_PAYLOAD = 4'd6;
    localparam [3:0] RX_CRC_H   = 4'd7;
    localparam [3:0] RX_CRC_L   = 4'd8;

    reg [3:0]  rx_state_uart = RX_WAIT_AA;
    reg [7:0]  rx_type_uart  = 8'd0;
    reg [7:0]  rx_seq_uart   = 8'd0;
    reg [7:0]  rx_len_hi_uart = 8'd0;
    reg [7:0]  rx_mode_uart  = 8'd0;
    reg [7:0]  rx_crc_hi_uart = 8'd0;
    reg [15:0] rx_crc_uart   = 16'hFFFF;
    // 50 ms inter-byte timeout at 14.7456 MHz.
    reg [19:0] rx_gap_count_uart = 20'd0;

    // A toggle safely transfers one parsed command into the 4 MHz domain.
    // The associated data remains stable until the next valid command.
    reg       cmd_toggle_uart = 1'b0;
    reg [7:0] cmd_type_uart   = 8'd0;
    reg [7:0] cmd_seq_uart    = 8'd0;
    reg [7:0] cmd_mode_uart   = 8'd0;

    always @(posedge clk_uart) begin
        if (rst) begin
            rx_state_uart  <= RX_WAIT_AA;
            rx_type_uart   <= 8'd0;
            rx_seq_uart    <= 8'd0;
            rx_len_hi_uart <= 8'd0;
            rx_mode_uart   <= 8'd0;
            rx_crc_hi_uart <= 8'd0;
            rx_crc_uart    <= 16'hFFFF;
            rx_gap_count_uart <= 20'd0;
            cmd_toggle_uart <= 1'b0;
            cmd_type_uart   <= 8'd0;
            cmd_seq_uart    <= 8'd0;
            cmd_mode_uart   <= 8'd0;
        end else if (rx_error_uart) begin
            rx_state_uart <= RX_WAIT_AA;
            rx_crc_uart   <= 16'hFFFF;
            rx_gap_count_uart <= 20'd0;
        end else if (rx_ready_uart) begin
            rx_gap_count_uart <= 20'd0;
            case (rx_state_uart)
                RX_WAIT_AA: begin
                    if (rx_data_uart == 8'hAA)
                        rx_state_uart <= RX_WAIT_55;
                end

                RX_WAIT_55: begin
                    if (rx_data_uart == 8'h55)
                        rx_state_uart <= RX_TYPE;
                    else if (rx_data_uart != 8'hAA)
                        rx_state_uart <= RX_WAIT_AA;
                end

                RX_TYPE: begin
                    rx_type_uart  <= rx_data_uart;
                    rx_crc_uart   <= crc16_next(16'hFFFF, rx_data_uart);
                    rx_state_uart <= RX_SEQ;
                end

                RX_SEQ: begin
                    rx_seq_uart   <= rx_data_uart;
                    rx_crc_uart   <= crc16_next(rx_crc_uart, rx_data_uart);
                    rx_state_uart <= RX_LEN_H;
                end

                RX_LEN_H: begin
                    rx_len_hi_uart <= rx_data_uart;
                    rx_crc_uart    <= crc16_next(rx_crc_uart, rx_data_uart);
                    rx_state_uart  <= RX_LEN_L;
                end

                RX_LEN_L: begin
                    rx_crc_uart <= crc16_next(rx_crc_uart, rx_data_uart);
                    if ((rx_type_uart == TYPE_CMD_START)
                        && (rx_len_hi_uart == 8'h00)
                        && (rx_data_uart == 8'h01)) begin
                        rx_state_uart <= RX_PAYLOAD;
                    end else if (((rx_type_uart == TYPE_CMD_STOP)
                                  || (rx_type_uart == TYPE_CMD_RESEND)
                                  || (rx_type_uart == TYPE_ACK))
                                 && (rx_len_hi_uart == 8'h00)
                                 && (rx_data_uart == 8'h00)) begin
                        rx_state_uart <= RX_CRC_H;
                    end else begin
                        rx_state_uart <= RX_WAIT_AA;
                    end
                end

                RX_PAYLOAD: begin
                    rx_mode_uart  <= rx_data_uart;
                    rx_crc_uart   <= crc16_next(rx_crc_uart, rx_data_uart);
                    rx_state_uart <= RX_CRC_H;
                end

                RX_CRC_H: begin
                    rx_crc_hi_uart <= rx_data_uart;
                    rx_state_uart  <= RX_CRC_L;
                end

                RX_CRC_L: begin
                    if (({rx_crc_hi_uart, rx_data_uart} == rx_crc_uart)
                        && ((rx_type_uart != TYPE_CMD_START)
                            || (rx_mode_uart == 8'h01))) begin
                        cmd_type_uart   <= rx_type_uart;
                        cmd_seq_uart    <= rx_seq_uart;
                        cmd_mode_uart   <= rx_mode_uart;
                        cmd_toggle_uart <= ~cmd_toggle_uart;
                    end
                    if (rx_data_uart == 8'hAA)
                        rx_state_uart <= RX_WAIT_55;
                    else
                        rx_state_uart <= RX_WAIT_AA;
                end

                default: rx_state_uart <= RX_WAIT_AA;
            endcase
        end else if (rx_state_uart != RX_WAIT_AA) begin
            if (rx_gap_count_uart >= 20'd737279) begin
                rx_state_uart <= RX_WAIT_AA;
                rx_crc_uart <= 16'hFFFF;
                rx_gap_count_uart <= 20'd0;
            end else begin
                rx_gap_count_uart <= rx_gap_count_uart + 1'b1;
            end
        end else begin
            rx_gap_count_uart <= 20'd0;
        end
    end

    // ========================================================================
    // TX mailbox: clk_4m -> clk_uart
    // ========================================================================
    reg [7:0] mbox_data_4m = 8'd0;
    reg       mbox_req_4m  = 1'b0;

    reg mbox_req_meta = 1'b0;
    reg mbox_req_sync = 1'b0;
    reg mbox_req_sync_d1 = 1'b0;
    always @(posedge clk_uart) begin
        mbox_req_meta    <= mbox_req_4m;
        mbox_req_sync    <= mbox_req_meta;
        mbox_req_sync_d1 <= mbox_req_sync;
        if (mbox_req_sync && !mbox_req_sync_d1 && !tx_busy_uart) begin
            tx_data_uart  <= mbox_data_4m;
            tx_start_uart <= 1'b1;
        end else begin
            tx_start_uart <= 1'b0;
        end
    end

    reg tx_busy_meta = 1'b0;
    reg tx_busy_sync = 1'b0;
    reg tx_busy_d1   = 1'b0;
    always @(posedge clk_4m) begin
        tx_busy_meta <= tx_busy_uart;
        tx_busy_sync <= tx_busy_meta;
        tx_busy_d1   <= tx_busy_sync;
    end
    wire tx_falling = tx_busy_d1 & ~tx_busy_sync;

    // ========================================================================
    // Parsed-command CDC: clk_uart -> clk_4m
    // ========================================================================
    reg cmd_toggle_meta = 1'b0;
    reg cmd_toggle_sync = 1'b0;
    reg cmd_toggle_d1   = 1'b0;
    reg [7:0] cmd_type_meta = 8'd0;
    reg [7:0] cmd_type_sync = 8'd0;
    reg [7:0] cmd_seq_meta  = 8'd0;
    reg [7:0] cmd_seq_sync  = 8'd0;
    reg [7:0] cmd_mode_meta = 8'd0;
    reg [7:0] cmd_mode_sync = 8'd0;

    always @(posedge clk_4m) begin
        cmd_toggle_meta <= cmd_toggle_uart;
        cmd_toggle_sync <= cmd_toggle_meta;
        cmd_toggle_d1   <= cmd_toggle_sync;
        cmd_type_meta   <= cmd_type_uart;
        cmd_type_sync   <= cmd_type_meta;
        cmd_seq_meta    <= cmd_seq_uart;
        cmd_seq_sync    <= cmd_seq_meta;
        cmd_mode_meta   <= cmd_mode_uart;
        cmd_mode_sync   <= cmd_mode_meta;
    end
    wire cmd_pulse_4m = cmd_toggle_sync ^ cmd_toggle_d1;

    // ========================================================================
    // CRC generator for result frames (clk_4m domain)
    // ========================================================================
    reg        crc_init_r  = 1'b0;
    reg        crc_tick_r  = 1'b0;
    reg  [7:0] crc_data_in = 8'd0;
    wire [15:0] crc_out_w;

    crc16_ccitt u_crc (
        .clk      (clk_4m),
        .rst      (rst),
        .crc_init (crc_init_r),
        .data_in  (crc_data_in),
        .crc_tick (crc_tick_r),
        .crc_out  (crc_out_w)
    );

    // ========================================================================
    // Stable communication snapshot
    // ========================================================================
    (* ram_style = "distributed" *)
    reg signed [15:0] wave_snapshot [0:N_WAVEFORM-1];
    (* ram_style = "distributed" *)
    reg [15:0] spec_snapshot [0:N_SPECTRUM-1];

    reg [10:0] capture_index = 11'd0;
    reg [10:0] wave_rd_idx_r = 11'd0;
    reg [10:0] spec_rd_idx_r = 11'd0;

    wire signed [31:0] wave_scaled_now =
        $signed(wave_rd_data) * $signed(32'sd122);
    // FFT uses a total 2^-6 scaling schedule.  For a bin-centred real sine
    // after a Hann window, the positive-frequency magnitude is:
    //   mag = ADC_peak * N * 0.5 / 2 / 64 = ADC_peak * 32
    // With ADC_TO_001MV=122, convert magnitude to 0.01 mV by 122/32=61/16.
    wire [31:0] spec_scaled_now =
        (spec_rd_data * 32'd61) / 32'd16;

    // ========================================================================
    // Main protocol state machine (clk_4m domain)
    // ========================================================================
    localparam [4:0] S_IDLE            = 5'd0;
    localparam [4:0] S_WAIT_DATA       = 5'd1;
    localparam [4:0] S_CAP_WAVE_ADDR   = 5'd2;
    localparam [4:0] S_CAP_WAVE_WAIT   = 5'd3;
    localparam [4:0] S_CAP_WAVE_STORE  = 5'd4;
    localparam [4:0] S_CAP_SPEC_ADDR   = 5'd5;
    localparam [4:0] S_CAP_SPEC_WAIT   = 5'd6;
    localparam [4:0] S_CAP_SPEC_STORE  = 5'd7;
    localparam [4:0] S_TX_HEADER       = 5'd8;
    localparam [4:0] S_TX_PAYLOAD      = 5'd9;
    localparam [4:0] S_TX_CRC          = 5'd10;
    localparam [4:0] S_WAIT_TX         = 5'd11;
    localparam [4:0] S_WAIT_ACK        = 5'd12;
    localparam [4:0] S_ERROR           = 5'd13;

    reg [4:0]  state = S_IDLE;
    reg [13:0] payload_pos = 14'd0;
    reg [7:0]  cur_seq = 8'd0;
    reg signed [11:0] v_max = 12'sd0;
    reg signed [11:0] v_min = 12'sd0;
    reg [17:0] ack_to_cnt = 18'd0;
    reg [2:0]  resend_n = 3'd0;
    reg error_state_r = 1'b0;
    reg busy_r = 1'b0;
    reg snapshot_pulse_r = 1'b0;

    wire signed [12:0] v_span =
        $signed({v_max[11], v_max}) - $signed({v_min[11], v_min});
    wire [31:0] vpp_val =
        v_span[12] ? 32'd0 : (v_span * ADC_TO_001MV);
    wire [31:0] vrms_val = (vpp_val * 32'd36) / 32'd100;

    wire [13:0] pos = payload_pos;
    wire in_wave =
        (pos >= OFF_WAVEFORM) && (pos < OFF_WAVEFORM + 2*N_WAVEFORM);
    wire [13:0] wave_off = pos - OFF_WAVEFORM;
    wire [10:0] wave_idx = wave_off[10:1];
    wire wave_odd = wave_off[0];
    wire [15:0] wave_word = wave_snapshot[wave_idx];
    wire [7:0] wave_byte = wave_odd ? wave_word[7:0] : wave_word[15:8];

    wire in_spec =
        (pos >= OFF_SPEC) && (pos < OFF_SPEC + 2*N_SPECTRUM);
    wire [13:0] spec_off = pos - OFF_SPEC;
    wire [10:0] spec_idx = spec_off[10:1];
    wire spec_odd = spec_off[0];
    wire [15:0] spec_word = spec_snapshot[spec_idx];
    wire [7:0] spec_byte = spec_odd ? spec_word[7:0] : spec_word[15:8];

    reg [7:0] dt_byte;
    reg [7:0] fs_byte;
    reg [7:0] df_byte;
    always @(*) begin
        case (pos - 14'd3)
            14'd0: dt_byte = DT_NS[31:24];
            14'd1: dt_byte = DT_NS[23:16];
            14'd2: dt_byte = DT_NS[15:8];
            14'd3: dt_byte = DT_NS[7:0];
            default: dt_byte = 8'h00;
        endcase
        case (pos - OFF_FSTART)
            14'd0: fs_byte = F_START_HZ[31:24];
            14'd1: fs_byte = F_START_HZ[23:16];
            14'd2: fs_byte = F_START_HZ[15:8];
            14'd3: fs_byte = F_START_HZ[7:0];
            default: fs_byte = 8'h00;
        endcase
        case (pos - OFF_DF)
            14'd0: df_byte = DF_HZ[31:24];
            14'd1: df_byte = DF_HZ[23:16];
            14'd2: df_byte = DF_HZ[15:8];
            14'd3: df_byte = DF_HZ[7:0];
            default: df_byte = 8'h00;
        endcase
    end

    reg [7:0] curr_byte;
    always @(*) begin
        case (1'b1)
            (pos == 14'd0): curr_byte = 8'h00;
            (pos == 14'd1): curr_byte = N_WAVEFORM[15:8];
            (pos == 14'd2): curr_byte = N_WAVEFORM[7:0];
            (pos >= 14'd3 && pos <= 14'd6): curr_byte = dt_byte;
            in_wave: curr_byte = wave_byte;
            (pos == OFF_VPP): curr_byte = vpp_val[15:8];
            (pos == OFF_VPP + 14'd1): curr_byte = vpp_val[7:0];
            (pos == OFF_VRMS): curr_byte = vrms_val[15:8];
            (pos == OFF_VRMS + 14'd1): curr_byte = vrms_val[7:0];
            (pos == OFF_K): curr_byte = N_SPECTRUM[15:8];
            (pos == OFF_K + 14'd1): curr_byte = N_SPECTRUM[7:0];
            (pos >= OFF_FSTART && pos < OFF_FSTART + 14'd4):
                curr_byte = fs_byte;
            (pos >= OFF_DF && pos < OFF_DF + 14'd4):
                curr_byte = df_byte;
            in_spec: curr_byte = spec_byte;
            default: curr_byte = 8'h00;
        endcase
    end

    always @(posedge clk_4m) begin
        if (rst) begin
            state            <= S_IDLE;
            payload_pos      <= 14'd0;
            mbox_req_4m      <= 1'b0;
            mbox_data_4m     <= 8'd0;
            crc_init_r       <= 1'b0;
            crc_tick_r       <= 1'b0;
            crc_data_in      <= 8'd0;
            cur_seq          <= 8'd0;
            capture_index    <= 11'd0;
            wave_rd_idx_r    <= 11'd0;
            spec_rd_idx_r    <= 11'd0;
            ack_to_cnt       <= 18'd0;
            resend_n         <= 3'd0;
            error_state_r    <= 1'b0;
            busy_r           <= 1'b0;
            snapshot_pulse_r <= 1'b0;
            v_max            <= 12'sd0;
            v_min            <= 12'sd0;
        end else begin
            crc_init_r       <= 1'b0;
            crc_tick_r       <= 1'b0;
            snapshot_pulse_r <= 1'b0;

            if (tx_falling && mbox_req_4m)
                mbox_req_4m <= 1'b0;

            // A valid received command has priority over one normal state step.
            if (cmd_pulse_4m) begin
                case (cmd_type_sync)
                    TYPE_CMD_START: begin
                        if ((state == S_IDLE) || (state == S_ERROR)) begin
                            cur_seq       <= cmd_seq_sync;
                            v_max         <= wave_max;
                            v_min         <= wave_min;
                            capture_index <= 11'd0;
                            ack_to_cnt    <= 18'd0;
                            resend_n      <= 3'd0;
                            error_state_r <= 1'b0;
                            busy_r        <= 1'b1;
                            if (data_ready) begin
                                snapshot_pulse_r <= 1'b1;
                                state <= S_CAP_WAVE_ADDR;
                            end else begin
                                state <= S_WAIT_DATA;
                            end
                        end
                    end

                    TYPE_CMD_STOP: begin
                        // Never cut a UART frame in half.  STOP is accepted
                        // while waiting/capturing or after a completed frame.
                        if ((state == S_WAIT_DATA)
                            || (state == S_CAP_WAVE_ADDR)
                            || (state == S_CAP_WAVE_WAIT)
                            || (state == S_CAP_WAVE_STORE)
                            || (state == S_CAP_SPEC_ADDR)
                            || (state == S_CAP_SPEC_WAIT)
                            || (state == S_CAP_SPEC_STORE)
                            || (state == S_WAIT_ACK)
                            || (state == S_ERROR)) begin
                            state         <= S_IDLE;
                            busy_r        <= 1'b0;
                            error_state_r <= 1'b0;
                            ack_to_cnt    <= 18'd0;
                        end
                    end

                    TYPE_ACK: begin
                        if ((state == S_WAIT_ACK)
                            && (cmd_seq_sync == cur_seq)) begin
                            state         <= S_IDLE;
                            busy_r        <= 1'b0;
                            error_state_r <= 1'b0;
                            ack_to_cnt    <= 18'd0;
                        end
                    end

                    TYPE_CMD_RESEND: begin
                        if ((state == S_WAIT_ACK)
                            && (cmd_seq_sync == cur_seq)) begin
                            state       <= S_TX_HEADER;
                            payload_pos <= 14'd0;
                            crc_init_r  <= 1'b1;
                            ack_to_cnt  <= 18'd0;
                        end
                    end

                    default: ;
                endcase
            end else begin
                case (state)
                    S_IDLE: begin
                        busy_r <= 1'b0;
                    end

                    S_WAIT_DATA: begin
                        if (data_ready) begin
                            snapshot_pulse_r <= 1'b1;
                            capture_index <= 11'd0;
                            state <= S_CAP_WAVE_ADDR;
                        end
                    end

                    S_CAP_WAVE_ADDR: begin
                        wave_rd_idx_r <= capture_index;
                        state <= S_CAP_WAVE_WAIT;
                    end

                    S_CAP_WAVE_WAIT: begin
                        state <= S_CAP_WAVE_STORE;
                    end

                    S_CAP_WAVE_STORE: begin
                        wave_snapshot[capture_index] <= wave_scaled_now[15:0];
                        if (capture_index == N_WAVEFORM - 1) begin
                            capture_index <= 11'd0;
                            state <= S_CAP_SPEC_ADDR;
                        end else begin
                            capture_index <= capture_index + 1'b1;
                            state <= S_CAP_WAVE_ADDR;
                        end
                    end

                    S_CAP_SPEC_ADDR: begin
                        spec_rd_idx_r <= capture_index;
                        state <= S_CAP_SPEC_WAIT;
                    end

                    S_CAP_SPEC_WAIT: begin
                        state <= S_CAP_SPEC_STORE;
                    end

                    S_CAP_SPEC_STORE: begin
                        spec_snapshot[capture_index] <= spec_scaled_now[15:0];
                        if (capture_index == N_SPECTRUM - 1) begin
                            capture_index <= 11'd0;
                            payload_pos <= 14'd0;
                            crc_init_r <= 1'b1;
                            state <= S_TX_HEADER;
                        end else begin
                            capture_index <= capture_index + 1'b1;
                            state <= S_CAP_SPEC_ADDR;
                        end
                    end

                    S_TX_HEADER: begin
                        if (!mbox_req_4m) begin
                            case (payload_pos)
                                14'd0: mbox_data_4m <= 8'hAA;
                                14'd1: mbox_data_4m <= 8'h55;
                                14'd2: begin
                                    mbox_data_4m <= TYPE_RESULT;
                                    crc_data_in  <= TYPE_RESULT;
                                    crc_tick_r   <= 1'b1;
                                end
                                14'd3: begin
                                    mbox_data_4m <= cur_seq;
                                    crc_data_in  <= cur_seq;
                                    crc_tick_r   <= 1'b1;
                                end
                                14'd4: begin
                                    mbox_data_4m <= PAYLOAD_LEN[15:8];
                                    crc_data_in  <= PAYLOAD_LEN[15:8];
                                    crc_tick_r   <= 1'b1;
                                end
                                14'd5: begin
                                    mbox_data_4m <= PAYLOAD_LEN[7:0];
                                    crc_data_in  <= PAYLOAD_LEN[7:0];
                                    crc_tick_r   <= 1'b1;
                                end
                                default: mbox_data_4m <= 8'h00;
                            endcase
                            mbox_req_4m <= 1'b1;
                            if (payload_pos == 14'd5) begin
                                payload_pos <= 14'd0;
                                state <= S_TX_PAYLOAD;
                            end else begin
                                payload_pos <= payload_pos + 1'b1;
                            end
                        end
                    end

                    S_TX_PAYLOAD: begin
                        if (!mbox_req_4m) begin
                            mbox_data_4m <= curr_byte;
                            mbox_req_4m  <= 1'b1;
                            crc_data_in  <= curr_byte;
                            crc_tick_r   <= 1'b1;
                            if (payload_pos == PAYLOAD_LEN - 1) begin
                                payload_pos <= 14'd0;
                                state <= S_TX_CRC;
                            end else begin
                                payload_pos <= payload_pos + 1'b1;
                            end
                        end
                    end

                    S_TX_CRC: begin
                        if (!mbox_req_4m) begin
                            if (payload_pos == 14'd0) begin
                                mbox_data_4m <= crc_out_w[15:8];
                                mbox_req_4m  <= 1'b1;
                                payload_pos  <= 14'd1;
                            end else begin
                                mbox_data_4m <= crc_out_w[7:0];
                                mbox_req_4m  <= 1'b1;
                                payload_pos  <= 14'd0;
                                state <= S_WAIT_TX;
                            end
                        end
                    end

                    S_WAIT_TX: begin
                        if (!mbox_req_4m && !tx_busy_sync) begin
                            ack_to_cnt <= 18'd0;
                            state <= S_WAIT_ACK;
                        end
                    end

                    S_WAIT_ACK: begin
                        if (ack_to_cnt >= ACK_TIMEOUT_CYCLES - 1'b1) begin
                            if (resend_n < MAX_RESEND) begin
                                resend_n <= resend_n + 1'b1;
                                payload_pos <= 14'd0;
                                crc_init_r <= 1'b1;
                                ack_to_cnt <= 18'd0;
                                state <= S_TX_HEADER;
                            end else begin
                                error_state_r <= 1'b1;
                                busy_r <= 1'b0;
                                state <= S_ERROR;
                            end
                        end else begin
                            ack_to_cnt <= ack_to_cnt + 1'b1;
                        end
                    end

                    S_ERROR: begin
                        error_state_r <= 1'b1;
                        busy_r <= 1'b0;
                    end

                    default: begin
                        state <= S_IDLE;
                        busy_r <= 1'b0;
                    end
                endcase
            end
        end
    end

    assign wave_rd_idx   = wave_rd_idx_r;
    assign spec_rd_idx   = spec_rd_idx_r;
    assign snapshot_pulse = snapshot_pulse_r;
    assign error_state   = error_state_r;
    assign busy          = busy_r;

    wire _unused = &{1'b0, cmd_mode_sync, tx_data_uart, rx_error_uart} & 1'b0;

endmodule
`default_nettype wire
