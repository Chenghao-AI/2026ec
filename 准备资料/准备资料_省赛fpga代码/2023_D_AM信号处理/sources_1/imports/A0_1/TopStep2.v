`timescale 1ns/1ps

//=================================================================================
// TopStep2.v
// AM ���?? (���� 2)
//
// ��·:
//   MixerIQ -> CIC5 dec=200 x2 (I/Q) -> FIR x2 -> CORDIC atan2 -> R
//   -> AMClassifier (m_a + F) -> DisplayMux -> SevenSegDriver
//
// ����:
//   - PL LED ��ʾ���������?? (AM=000, FM=001, ...), ��ǰ�����֧��?? AM
//   - Ĭ����ʾ F (1~5 kHz), KEY1 �е� m_a, KEY2 �л� F
//=================================================================================
module MixerIQ(
    input         clock,
    input         reset,
    input  [11:0] io_x_in,
    output [12:0] io_I_out,
    output [12:0] io_Q_out
);
    parameter PHASE_STEP = 24'h0CCCCD; // 2 MHz / 40 MHz * 2^24

    reg [23:0] phase_acc;
    reg signed [12:0] x_signed;
    reg signed [11:0] cos_val;
    reg signed [11:0] sin_val;

    wire signed [25:0] i_mult;
    wire signed [25:0] q_mult;

    assign i_mult = x_signed * $signed({cos_val[11], cos_val});
    assign q_mult = x_signed * $signed({sin_val[11], sin_val});

    reg signed [11:0] cos_lut [0:255];
    reg signed [11:0] sin_lut [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            cos_lut[i] = $rtoi(2047.0 * $cos(2.0 * 3.1415926535 * i / 256.0));
            sin_lut[i] = $rtoi(2047.0 * $sin(2.0 * 3.1415926535 * i / 256.0));
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            phase_acc <= 24'h0;
            x_signed  <= 13'h0;
            cos_val   <= 12'h0;
            sin_val   <= 12'h0;
        end else begin
            phase_acc <= phase_acc + PHASE_STEP;
            x_signed  <= {1'b0, io_x_in} - 13'h800;
            cos_val   <= cos_lut[phase_acc[23:16]];
            sin_val   <= sin_lut[phase_acc[23:16]];
        end
    end

    assign io_I_out = i_mult[25:13];
    assign io_Q_out = q_mult[25:13];
endmodule


//=================================================================================
// CICDecimator: 5-stage CIC dec=200 (40 MHz -> 200 kHz)
//=================================================================================
module CICDecimator(
    input         clock,
    input         reset,
    input  [12:0] io_x_in,
    output reg [23:0] io_y_out,
    output reg        io_y_valid
);
    reg signed [51:0] int1, int2, int3, int4, int5;
    reg signed [51:0] c0_d, c1_d, c2_d, c3_d, c4_d;
    reg signed [51:0] c1, c2, c3, c4, c5;

    reg [7:0] dec_cnt;
    wire comb_en = (dec_cnt == 8'd199);

    always @(posedge clock) begin
        if (reset) begin
            int1    <= 52'h0;
            int2    <= 52'h0;
            int3    <= 52'h0;
            int4    <= 52'h0;
            int5    <= 52'h0;
            dec_cnt <= 8'h0;
        end else begin
            int1 <= int1 + {{39{io_x_in[12]}}, io_x_in};
            int2 <= int2 + int1;
            int3 <= int3 + int2;
            int4 <= int4 + int3;
            int5 <= int5 + int4;

            if (dec_cnt == 8'd199)
                dec_cnt <= 8'h0;
            else
                dec_cnt <= dec_cnt + 8'h1;
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            c0_d       <= 52'h0;
            c1_d       <= 52'h0; c2_d       <= 52'h0; c3_d       <= 52'h0; c4_d       <= 52'h0;
            c1         <= 52'h0; c2         <= 52'h0; c3         <= 52'h0; c4         <= 52'h0; c5         <= 52'h0;
            io_y_out   <= 24'h0;
            io_y_valid <= 1'b0;
        end else if (comb_en) begin
            c0_d <= int5;
            c1   <= int5 - c0_d;
            c1_d <= c1;
            c2   <= c1 - c1_d;
            c2_d <= c2;
            c3   <= c2 - c2_d;
            c3_d <= c3;
            c4   <= c3 - c3_d;
            c4_d <= c4;
            c5   <= c4 - c4_d;

            io_y_out   <= c5[51:28];
            io_y_valid <= 1'b1;
        end else begin
            io_y_valid <= 1'b0;
        end
    end
endmodule


//=================================================================================
// FIRCompensator: 5-tap (0x05, 0x2B, 0x5A, 0x2B, 0x05) CIC-compensation
//=================================================================================
module FIRCompensator(
    input         clock,
    input         reset,
    input         io_x_valid,
    input  [23:0] io_x_in,
    output reg [23:0] io_y_out,
    output reg        io_y_valid
);
    reg [23:0] delay0, delay1, delay2, delay3, delay4;
    reg signed [42:0] sum;

    always @(posedge clock) begin
        if (reset) begin
            delay0     <= 24'h0; delay1 <= 24'h0; delay2 <= 24'h0; delay3 <= 24'h0; delay4 <= 24'h0;
            sum        <= 43'h0;
            io_y_out   <= 24'h0;
            io_y_valid <= 1'b0;
        end else if (io_x_valid) begin
            delay0 <= io_x_in;
            delay1 <= delay0;
            delay2 <= delay1;
            delay3 <= delay2;
            delay4 <= delay3;

            sum <= $signed({delay0[23], delay0}) * 18'sh05 +
                   $signed({delay1[23], delay1}) * 18'sh2B +
                   $signed({delay2[23], delay2}) * 18'sh5A +
                   $signed({delay3[23], delay3}) * 18'sh2B +
                   $signed({delay4[23], delay4}) * 18'sh05;

            io_y_out   <= sum[31:8];
            io_y_valid <= 1'b1;
        end else begin
            io_y_valid <= 1'b0;
        end
    end
endmodule


//=================================================================================
// CordicAtan2: 16 �ε����� R = sqrt(I^2 + Q^2)
//=================================================================================
module CordicAtan2(
    input         clock,
    input         reset,
    input         io_valid_in,
    input  [23:0] io_I_in,
    input  [23:0] io_Q_in,
    output reg [23:0] io_R_out,
    output reg        io_valid_out
);
    reg signed [27:0] x_iter, y_iter;
    reg [4:0] iter_cnt;
    reg signed [27:0] x_next, y_next;

    always @(*) begin
        if (y_iter < 0) begin
            x_next = x_iter - (y_iter >>> (iter_cnt - 1));
            y_next = y_iter + (x_iter >>> (iter_cnt - 1));
        end else begin
            x_next = x_iter + (y_iter >>> (iter_cnt - 1));
            y_next = y_iter - (x_iter >>> (iter_cnt - 1));
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            x_iter       <= 28'h0;
            y_iter       <= 28'h0;
            iter_cnt     <= 5'd16;
            io_R_out     <= 24'h0;
            io_valid_out <= 1'b0;
        end else begin
            if (io_valid_in) begin
                if (io_I_in[23] == 1'b1) begin
                    x_iter <= {{4{~io_I_in[23]}}, ~io_I_in + 1'b1, 1'b0};
                    y_iter <= {{4{~io_Q_in[23]}}, ~io_Q_in + 1'b1, 1'b0};
                end else begin
                    x_iter <= {{4{io_I_in[23]}}, io_I_in, 1'b0};
                    y_iter <= {{4{io_Q_in[23]}}, io_Q_in, 1'b0};
                end
                iter_cnt     <= 5'h1;
                io_valid_out <= 1'b0;
            end else if (iter_cnt < 16) begin
                x_iter   <= x_next;
                y_iter   <= y_next;
                iter_cnt <= iter_cnt + 5'h1;
                if (iter_cnt == 5'd15) begin
                    io_R_out     <= x_next[27:4];
                    io_valid_out <= 1'b1;
                end
            end else begin
                io_valid_out <= 1'b0;
            end
        end
    end
endmodule


//=================================================================================
// AMClassifier: ͬʱ���� m_a �� F
//
//   m_a:  �� 2048 �� R ���� (10 ms @ 200 kHz) ��ȡ R_max / R_min
//         m_a_raw = (R_max - R_min) * 256 / (R_max + R_min)
//
//   F:    ���?? R �������������� (R >= DC)
//         �����ڹ������?? dt ������ 5 �� bin:
//           bin 0 = 5 kHz  (dt = 36..46)
//           bin 1 = 4 kHz  (dt = 47..58)
//           bin 2 = 3 kHz  (dt = 59..83)
//           bin 3 = 2 kHz  (dt = 84..150)
//           bin 4 = 1 kHz  (dt = 151..250)
//         ֱ��ͼ���?? bin ��Ӧ�� F ���??
//=================================================================================
module AMClassifier(
    input         clock,
    input         reset,
    input  [23:0] io_R_in,
    input         io_R_valid,
    output reg        io_is_am,
    output reg [7:0]  io_ma,
    output reg [2:0]  io_mod_freq
);
    parameter AM_THRESHOLD = 8'h40; // 0.25 * 256

    localparam ST_ACQUIRE  = 3'd0;
    localparam ST_CALC     = 3'd1;
    localparam ST_DIV      = 3'd2;
    localparam ST_HIST_MAX = 3'd3;
    localparam ST_OUTPUT   = 3'd4;

    reg [2:0] state;

    reg [10:0] wptr;
    reg [23:0] r_max;
    reg [23:0] r_min;
    reg [11:0] acq_cnt;

    reg [23:0] diff;
    reg [24:0] sum_val;
    reg [56:0] div_temp;
    reg [5:0]  div_count;
    wire [56:0] shifted_temp = div_temp << 1;

    reg [23:0] DC_est;

    reg        prev_above;
    reg [10:0] prev_zc_loc;
    reg [5:0]  zc_count;

    reg [15:0] hist [0:4];

    reg [2:0]  hist_idx;
    reg [15:0] max_cnt;
    reg [2:0]  best_bin;

    wire [10:0] diff_loc = wptr - prev_zc_loc;
    
    integer k;

    always @(posedge clock) begin
        if (reset) begin
            state       <= ST_ACQUIRE;
            wptr        <= 11'h0;
            acq_cnt     <= 12'h0;
            io_is_am    <= 1'b0;
            io_ma       <= 8'h0;
            io_mod_freq <= 3'h0;
            r_max       <= 24'h0;
            r_min       <= 24'hFFFFFF;
            diff        <= 24'h0;
            sum_val     <= 25'h0;
            div_temp    <= 57'h0;
            div_count   <= 6'h0;
            DC_est      <= 24'h0;
            prev_above  <= 1'b0;
            prev_zc_loc <= 11'h0;
            zc_count    <= 6'h0;
            hist_idx    <= 3'h0;
            max_cnt     <= 16'h0;
            best_bin    <= 3'h0;
            for (k = 0; k < 5; k = k + 1) hist[k] <= 16'h0;
        end else begin
            case (state)
                ST_ACQUIRE: begin
                    if (io_R_valid) begin
                        if (io_R_in > r_max) r_max <= io_R_in;
                        if (io_R_in < r_min) r_min <= io_R_in;

                        DC_est <= (r_max + r_min) >> 1;

                        
                        if (!prev_above && (io_R_in >= DC_est) && (acq_cnt > 0)) begin
                        
    if (zc_count > 0) begin
        // bin 0 = F=5kHz (diff_loc~20), bin 4 = F=1kHz (diff_loc~100)
        // mod_freq = 5 - best_bin
        if (diff_loc >= 11'd25 && diff_loc <= 11'd40) begin
            hist[0] <= hist[0] + 16'h1;//�ж�Ϊ5kHz
        end
        else if (diff_loc >= 11'd41 && diff_loc <= 11'd60) begin
            hist[1] <= hist[1] + 16'h1;//�ж�Ϊ4kHz
        end
        else if (diff_loc >= 11'd61 && diff_loc <= 11'd90) begin
            hist[2] <= hist[2] + 16'h1;//�ж�Ϊ3kHz
        end
        else if (diff_loc >= 11'd91 && diff_loc <= 11'd175) begin
            hist[3] <= hist[3] + 16'h1;//�ж�Ϊ2kHz
        end
        else if (diff_loc >= 11'd176 && diff_loc <= 11'd300) begin
            hist[4] <= hist[4] + 16'h1;//�ж�Ϊ1kHz
        end
    end
    
                            prev_zc_loc <= wptr;
                            zc_count    <= zc_count + 6'h1;
                        end
                        prev_above <= (io_R_in >= DC_est);

                        if (wptr == 11'd2047) begin
                            wptr    <= 11'h0;
                            acq_cnt <= 12'h0;
                            state   <= ST_CALC;
                        end else begin
                            wptr    <= wptr + 11'h1;
                            acq_cnt <= acq_cnt + 12'h1;
                        end
                    end
                end

                ST_CALC: begin
                    if (r_max > r_min) begin
                        diff    <= r_max - r_min;
                        sum_val <= {1'b0, r_max} + {1'b0, r_min};
                    end else begin
                        diff    <= 24'h0;
                        sum_val <= 25'h1;
                    end
                    div_count <= 6'd32;
                    div_temp  <= {25'h0, diff, 8'h0};
                    state     <= ST_DIV;
                end

                ST_DIV: begin
                    if (div_count == 6'd0) begin
                        state    <= ST_HIST_MAX;
                        hist_idx <= 3'h0;
                        max_cnt  <= 16'h0;
                        best_bin <= 3'h0;
                    end else begin
                        if (shifted_temp[56:32] >= sum_val) begin
                            div_temp <= {shifted_temp[56:32] - sum_val, shifted_temp[31:1], 1'b1};
                        end else begin
                            div_temp <= shifted_temp;
                        end
                        div_count <= div_count - 6'd1;
                    end
                end

                ST_HIST_MAX: begin
                    if (hist_idx == 3'd5) begin
                        // bin 0 = 5 kHz, ..., bin 4 = 1 kHz
                        state      <= ST_OUTPUT;
                        io_mod_freq <= 3'h5 - best_bin;
                    end else begin
                        if (hist[hist_idx] > max_cnt) begin
                            max_cnt  <= hist[hist_idx];
                            best_bin <= hist_idx;
                        end
                        hist_idx <= hist_idx + 3'h1;
                    end
                end

                ST_OUTPUT: begin
                    if (sum_val > 0) begin
                        io_ma    <= (div_temp[31:0] > 32'd255) ? 8'd255 : div_temp[31:0];
                        io_is_am <= (div_temp[31:0] > AM_THRESHOLD);
                    end else begin
                        io_ma    <= 8'h0;
                        io_is_am <= 1'b0;
                    end

                    // ������һ��
                    state      <= ST_ACQUIRE;
                    wptr       <= 11'h0;
                    acq_cnt    <= 12'h0;
                    r_max      <= 24'h0;
                    r_min      <= 24'hFFFFFF;
                    zc_count   <= 6'h0;
                    prev_above <= 1'b0;
                    prev_zc_loc <= 11'h0;
                    hist_idx   <= 3'h0;
                    max_cnt    <= 16'h0;
                    best_bin   <= 3'h0;
                    for (k = 0; k < 5; k = k + 1) hist[k] <= 16'h0;
                end

                default: state <= ST_ACQUIRE;
            endcase
        end
    end
endmodule


//=================================================================================
// KeyDebounce: 4-key debounce
//=================================================================================
module KeyDebounce(
    input  wire       clock,
    input  wire       reset,
    input  wire       io_key_raw_0,
    input  wire       io_key_raw_1,
    input  wire       io_key_raw_2,
    input  wire       io_key_raw_3,
    output reg        io_key_stable_0,
    output reg        io_key_stable_1,
    output reg        io_key_stable_2,
    output reg        io_key_stable_3
);
    parameter DEBOUNCE_MAX = 19'h61A80;
    parameter DEBOUNCE_THRESHOLD = 19'h61A7F;

    reg [18:0] cnt_0, cnt_1, cnt_2, cnt_3;
    reg stable_0, stable_1, stable_2, stable_3;

    always @(posedge clock) begin
        if (reset) begin
            cnt_0 <= 19'h0; cnt_1 <= 19'h0; cnt_2 <= 19'h0; cnt_3 <= 19'h0;
            stable_0 <= 1'b0; stable_1 <= 1'b0; stable_2 <= 1'b0; stable_3 <= 1'b0;
            io_key_stable_0 <= 1'b0; io_key_stable_1 <= 1'b0;
            io_key_stable_2 <= 1'b0; io_key_stable_3 <= 1'b0;
        end else begin
            if (io_key_raw_0) begin
                if (cnt_0 != DEBOUNCE_MAX) cnt_0 <= cnt_0 + 19'h1;
            end else cnt_0 <= 19'h0;
            stable_0 <= io_key_raw_0 & (cnt_0 == DEBOUNCE_THRESHOLD | stable_0);
            io_key_stable_0 <= stable_0;

            if (io_key_raw_1) begin
                if (cnt_1 != DEBOUNCE_MAX) cnt_1 <= cnt_1 + 19'h1;
            end else cnt_1 <= 19'h0;
            stable_1 <= io_key_raw_1 & (cnt_1 == DEBOUNCE_THRESHOLD | stable_1);
            io_key_stable_1 <= stable_1;

            if (io_key_raw_2) begin
                if (cnt_2 != DEBOUNCE_MAX) cnt_2 <= cnt_2 + 19'h1;
            end else cnt_2 <= 19'h0;
            stable_2 <= io_key_raw_2 & (cnt_2 == DEBOUNCE_THRESHOLD | stable_2);
            io_key_stable_2 <= stable_2;

            if (io_key_raw_3) begin
                if (cnt_3 != DEBOUNCE_MAX) cnt_3 <= cnt_3 + 19'h1;
            end else cnt_3 <= 19'h0;
            stable_3 <= io_key_raw_3 & (cnt_3 == DEBOUNCE_THRESHOLD | stable_3);
            io_key_stable_3 <= stable_3;
        end
    end
endmodule


//=================================================================================
// DisplayMux: �� KEY1/KEY2 �л���ʾ m_a �� F
//
//   display_mode = 0:  ��ʾ F (Ĭ��)
//   display_mode = 1:  ��ʾ m_a (�� KEY1 �л�)
//   �� KEY2 ֱ���л� F (�����??)
//=================================================================================
module DisplayMux(
    input         clock,
    input         reset,
    input  [2:0]  io_mod_freq,
    input  [7:0]  io_ma,
    input         io_key_stable_0,
    input         io_key_stable_1,
    input         io_key_stable_2,
    input         io_key_stable_3,
    output reg [15:0] io_displayValue,
    output reg [3:0]  io_dpMask
);
    reg [1:0] display_mode;
    reg key0_d1, key0_d2, key1_d1, key1_d2;
    wire key0_press = io_key_stable_0 & ~key0_d2;
    wire key1_press = io_key_stable_1 & ~key1_d2;

    always @(posedge clock) begin
        if (reset) begin
            display_mode <= 2'd0;
            key0_d1 <= 1'b0; key0_d2 <= 1'b0;
            key1_d1 <= 1'b0; key1_d2 <= 1'b0;
        end else begin
            key0_d1 <= io_key_stable_0;
            key0_d2 <= key0_d1;
            key1_d1 <= io_key_stable_1;
            key1_d2 <= key1_d1;
            if (key0_press) display_mode <= 2'd1; // KEY1 -> ma
            if (key1_press) display_mode <= 2'd0; // KEY2 -> F
        end
    end

    // m_a ����: (ma * 101) >> 8 -> ��Χ 0..100
    wire [15:0] ma_scale_mult = io_ma * 8'd101;
    wire [7:0]  ma_scaled     = ma_scale_mult[15:8];

    reg [3:0] tens, ones;
    always @(*) begin
        if (ma_scaled >= 8'd90) begin tens = 4'd9; ones = ma_scaled - 8'd90; end
        else if (ma_scaled >= 8'd80) begin tens = 4'd8; ones = ma_scaled - 8'd80; end
        else if (ma_scaled >= 8'd70) begin tens = 4'd7; ones = ma_scaled - 8'd70; end
        else if (ma_scaled >= 8'd60) begin tens = 4'd6; ones = ma_scaled - 8'd60; end
        else if (ma_scaled >= 8'd50) begin tens = 4'd5; ones = ma_scaled - 8'd50; end
        else if (ma_scaled >= 8'd40) begin tens = 4'd4; ones = ma_scaled - 8'd40; end
        else if (ma_scaled >= 8'd30) begin tens = 4'd3; ones = ma_scaled - 8'd30; end
        else if (ma_scaled >= 8'd20) begin tens = 4'd2; ones = ma_scaled - 8'd20; end
        else if (ma_scaled >= 8'd10) begin tens = 4'd1; ones = ma_scaled - 8'd10; end
        else begin tens = 4'd0; ones = ma_scaled; end
    end

    always @(*) begin
        if (display_mode == 2'd1) begin
            // ��ʾ m_a
            if (ma_scaled >= 8'd100) begin
                io_displayValue = {4'hF, 4'h1, 4'h0, 4'h0};
                io_dpMask       = 4'b0100; // DIG3 С���� -> "1.00"
            end else begin
                io_displayValue = {4'hF, 4'h0, tens, ones};
                io_dpMask       = 4'b0100; // DIG3 С���� -> "0.XX"
            end
        end else begin
            // ��ʾ F
            io_displayValue = (io_mod_freq == 3'h0) ? 16'hFFFF : {io_mod_freq, 4'hF, 4'hF, 4'hF};
            io_dpMask       = 4'b0000;
        end
    end
endmodule


//=================================================================================
// SevenSegDriver: 4 λ�����ɨ��?? (������, ����Ч)
//=================================================================================
module SevenSegDriver(
    input         clock,
    input         reset,
    input  [15:0] io_displayValue,
    input  [3:0]  io_dpMask,
    output reg [7:0] io_seg,
    output reg [3:0] io_dig_sel
);
    parameter SCAN_MAX = 16'h9C40;

    reg [15:0] scan_cnt;
    reg [1:0]  digit_idx;
    reg [3:0]  current_digit;
    reg        current_dp;

    wire [3:0] digit0, digit1, digit2, digit3;
    wire       dp0, dp1, dp2, dp3;

    assign digit3 = io_displayValue[15:12];
    assign digit2 = io_displayValue[11:8];
    assign digit1 = io_displayValue[7:4];
    assign digit0 = io_displayValue[3:0];
    assign {dp3, dp2, dp1, dp0} = io_dpMask;

    function [7:0] seg_encode;
        input [3:0] digit;
        case(digit)
            4'h0: seg_encode = 8'b11000000;
            4'h1: seg_encode = 8'b11111001;
            4'h2: seg_encode = 8'b10100100;
            4'h3: seg_encode = 8'b10110000;
            4'h4: seg_encode = 8'b10011001;
            4'h5: seg_encode = 8'b10010010;
            4'h6: seg_encode = 8'b10000010;
            4'h7: seg_encode = 8'b11111000;
            4'h8: seg_encode = 8'b10000000;
            4'h9: seg_encode = 8'b10010000;
            default: seg_encode = 8'b11111111;
        endcase
    endfunction

    always @(*) begin
        case(digit_idx)
            2'b11: begin current_digit = digit0; current_dp = dp0; end
            2'b10: begin current_digit = digit1; current_dp = dp1; end
            2'b01: begin current_digit = digit2; current_dp = dp2; end
            2'b00: begin current_digit = digit3; current_dp = dp3; end
        endcase
    end

    always @(posedge clock) begin
        if (reset) begin
            scan_cnt   <= 16'h0;
            digit_idx  <= 2'b00;
            io_seg     <= 8'hFF;
            io_dig_sel <= 4'h0;
        end else begin
            if (scan_cnt == SCAN_MAX) begin
                scan_cnt  <= 16'h0;
                digit_idx <= digit_idx + 2'b01;
            end else begin
                scan_cnt  <= scan_cnt + 16'h1;
            end

            io_seg <= seg_encode(current_digit);
            io_seg[7] <= current_dp ? 1'b0 : 1'b1;

            case(digit_idx)
                2'b00: io_dig_sel <= 4'b0001;
                2'b01: io_dig_sel <= 4'b0010;
                2'b10: io_dig_sel <= 4'b0100;
                2'b11: io_dig_sel <= 4'b1000;
            endcase
        end
    end
endmodule


//=================================================================================
// TopStep2: ����ģ��
//=================================================================================
module TopStep2(
    input         clock,
    input         reset,
    input  [11:0] io_adc_a_data,
    input         io_key_raw_0,
    input         io_key_raw_1,
    input         io_key_raw_2,
    input         io_key_raw_3,
    output [3:0]  io_pl_led,
    output [7:0]  io_seg,
    output [3:0]  io_dig_sel,
    output        io_uo_ana,
    output        io_is_am,
    output [7:0]  io_ma,
    output [2:0]  io_mod_freq
);
    wire [12:0] mixer_I, mixer_Q;
    wire [23:0] cic_I_out, cic_Q_out;
    wire        cic_I_valid, cic_Q_valid;
    wire [23:0] fir_I_out, fir_Q_out;
    wire        fir_I_valid, fir_Q_valid;
    wire [23:0] cordic_R;
    wire        cordic_valid;
    wire [3:0]  key_stable;
    wire [15:0] display_value;
    wire [3:0]  dp_mask;
    wire        is_am;
    wire [7:0]  ma;
    wire [2:0]  mod_freq;

    MixerIQ u_mixer (
        .clock(clock), .reset(reset),
        .io_x_in(io_adc_a_data),
        .io_I_out(mixer_I), .io_Q_out(mixer_Q)
    );

    CICDecimator u_cic_I (
        .clock(clock), .reset(reset),
        .io_x_in(mixer_I),
        .io_y_out(cic_I_out), .io_y_valid(cic_I_valid)
    );

    CICDecimator u_cic_Q (
        .clock(clock), .reset(reset),
        .io_x_in(mixer_Q),
        .io_y_out(cic_Q_out), .io_y_valid(cic_Q_valid)
    );

    FIRCompensator u_fir_I (
        .clock(clock), .reset(reset),
        .io_x_valid(cic_I_valid),
        .io_x_in(cic_I_out),
        .io_y_out(fir_I_out), .io_y_valid(fir_I_valid)
    );

    FIRCompensator u_fir_Q (
        .clock(clock), .reset(reset),
        .io_x_valid(cic_Q_valid),
        .io_x_in(cic_Q_out),
        .io_y_out(fir_Q_out), .io_y_valid(fir_Q_valid)
    );

    CordicAtan2 u_cordic (
        .clock(clock), .reset(reset),
        .io_valid_in(fir_I_valid),
        .io_I_in(fir_I_out), .io_Q_in(fir_Q_out),
        .io_R_out(cordic_R), .io_valid_out(cordic_valid)
    );

    AMClassifier u_classifier (
        .clock(clock), .reset(reset),
        .io_R_in(cordic_R), .io_R_valid(cordic_valid),
        .io_is_am(is_am), .io_ma(ma), .io_mod_freq(mod_freq)
    );

    KeyDebounce u_key (
        .clock(clock), .reset(reset),
        .io_key_raw_0(io_key_raw_0),
        .io_key_raw_1(io_key_raw_1),
        .io_key_raw_2(io_key_raw_2),
        .io_key_raw_3(io_key_raw_3),
        .io_key_stable_0(key_stable[0]),
        .io_key_stable_1(key_stable[1]),
        .io_key_stable_2(key_stable[2]),
        .io_key_stable_3(key_stable[3])
    );

    DisplayMux u_display (
        .clock(clock), .reset(reset),
        .io_mod_freq(mod_freq), .io_ma(ma),
        .io_key_stable_0(key_stable[0]),
        .io_key_stable_1(key_stable[1]),
        .io_key_stable_2(key_stable[2]),
        .io_key_stable_3(key_stable[3]),
        .io_displayValue(display_value), .io_dpMask(dp_mask)
    );

    SevenSegDriver u_seg (
        .clock(clock), .reset(reset),
        .io_displayValue(display_value), .io_dpMask(dp_mask),
        .io_seg(io_seg), .io_dig_sel(io_dig_sel)
    );

    // PWM ���?? (J20)
    reg [7:0] pwm_cnt;
    always @(posedge clock) begin
        if (reset) pwm_cnt <= 8'd0;
        else pwm_cnt <= pwm_cnt + 8'd1;
    end
    assign io_uo_ana = (cordic_R[23:16] > pwm_cnt);

    // ----- PL LED -----
    // �����?? (����Ч, top.v ȡ��): AM=000 -> �������� 3'b111 -> 3 ��ȫ��
    // ��ǰ�� AM ģʽ, PL LED ���?? 3'b000
    assign io_pl_led = is_am ? 4'b0111 : 4'b1111;

    assign io_is_am    = is_am;
    assign io_ma       = ma;
    assign io_mod_freq = mod_freq;
endmodule