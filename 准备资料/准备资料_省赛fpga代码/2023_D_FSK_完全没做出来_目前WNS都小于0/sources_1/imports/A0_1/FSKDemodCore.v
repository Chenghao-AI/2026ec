`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// FSK Demodulation Core - Fixed Version
// Fixed Issues:
// 1. Proper parameter estimation with correct thresholds
// 2. Correct LED encoding (1=LED on in software logic)
// 3. Continuous DAC output
// ============================================================================

// ========================================================================
// 1. FskNco - 30-sample LUT for 2.0 MHz @ 60MSPS
// ========================================================================
module FskNco(
    input  wire        clock,
    input  wire        reset,
    output wire signed [15:0] io_outSin,
    output wire signed [15:0] io_outCos
);
    reg [4:0] phase_idx;
    
    // 2MHz @ 60MHz -> phase increment = 2M/60M * 2^5 = 16/32
    always @(posedge clock) begin
        if (reset)
            phase_idx <= 5'h0;
        else if (phase_idx == 5'd29)
            phase_idx <= 5'h0;
        else
            phase_idx <= phase_idx + 5'h1;
    end

    // 30-point sin/cos lookup table (amplitude 16383)
    reg signed [15:0] sin_r, cos_r;
    always @(*) begin
        case (phase_idx)
            5'd0:  begin sin_r = 16'sd0;      cos_r =  16'sd16383; end
            5'd1:  begin sin_r = 16'sd3406;   cos_r =  16'sd16026; end
            5'd2:  begin sin_r = 16'sd6663;   cos_r =  16'sd14984; end
            5'd3:  begin sin_r = 16'sd9630;   cos_r =  16'sd13254; end
            5'd4:  begin sin_r = 16'sd12175;  cos_r =  16'sd10888; end
            5'd5:  begin sin_r = 16'sd14189;  cos_r =  16'sd8192;  end
            5'd6:  begin sin_r = 16'sd15582;  cos_r =  16'sd5236;  end
            5'd7:  begin sin_r = 16'sd16293;  cos_r =  16'sd2140;  end
            5'd8:  begin sin_r = 16'sd16293;  cos_r = -16'sd2140;  end
            5'd9:  begin sin_r = 16'sd15582;  cos_r = -16'sd5236;  end
            5'd10: begin sin_r = 16'sd14189;  cos_r = -16'sd8192;  end
            5'd11: begin sin_r = 16'sd12175;  cos_r = -16'sd10888; end
            5'd12: begin sin_r = 16'sd9630;   cos_r = -16'sd13254; end
            5'd13: begin sin_r = 16'sd6663;   cos_r = -16'sd14984; end
            5'd14: begin sin_r = 16'sd3406;   cos_r = -16'sd16026; end
            5'd15: begin sin_r = 16'sd0;      cos_r = -16'sd16383; end
            5'd16: begin sin_r = -16'sd3406;  cos_r = -16'sd16026; end
            5'd17: begin sin_r = -16'sd6663;  cos_r = -16'sd14984; end
            5'd18: begin sin_r = -16'sd9630;  cos_r = -16'sd13254; end
            5'd19: begin sin_r = -16'sd12175; cos_r = -16'sd10888; end
            5'd20: begin sin_r = -16'sd14189; cos_r = -16'sd8192;  end
            5'd21: begin sin_r = -16'sd15582; cos_r = -16'sd5236;  end
            5'd22: begin sin_r = -16'sd16293; cos_r = -16'sd2140;  end
            5'd23: begin sin_r = -16'sd16293; cos_r =  16'sd2140;  end
            5'd24: begin sin_r = -16'sd15582; cos_r =  16'sd5236;  end
            5'd25: begin sin_r = -16'sd14189; cos_r =  16'sd8192;  end
            5'd26: begin sin_r = -16'sd12175; cos_r =  16'sd10888; end
            5'd27: begin sin_r = -16'sd9630;  cos_r =  16'sd13254; end
            5'd28: begin sin_r = -16'sd6663;  cos_r =  16'sd14984; end
            5'd29: begin sin_r = -16'sd3406;  cos_r =  16'sd16026; end
            default: begin sin_r = 16'sd0;    cos_r =  16'sd0;     end
        endcase
    end

    assign io_outSin = sin_r;
    assign io_outCos = cos_r;
endmodule

// ========================================================================
// 2. FskDdc - Digital Down-Conversion (60MSPS -> 2MSPS, 30:1 decimation)
// ========================================================================
module FskDdc(
    input  wire        clock,
    input  wire        reset,
    input  wire [11:0] io_adcIn,
    input  wire        io_adcOra,
    output reg  signed [15:0] io_outI,
    output reg  signed [15:0] io_outQ,
    output reg          io_outValid
);
    wire signed [15:0] nco_sin, nco_cos;
    FskNco nco (
        .clock(clock),
        .reset(reset),
        .io_outSin(nco_sin),
        .io_outCos(nco_cos)
    );

    // AD9226 offset binary conversion
    wire signed [11:0] adc_signed = {io_adcIn[11] ^ 1'b1, io_adcIn[10:0]};
    wire signed [15:0] sample_s16 = io_adcOra ? 16'sh0 : {adc_signed, 4'b0};

    // Mixer (multiplication)
    wire signed [31:0] i_prod = sample_s16 * nco_sin;
    wire signed [31:0] q_prod = sample_s16 * nco_cos;

    // Accumulator with 30-cycle dump
    reg signed [37:0] i_acc;
    reg signed [37:0] q_acc;
    reg [4:0] sample_cnt;
    
    always @(posedge clock) begin
        if (reset) begin
            i_acc       <= 38'sh0;
            q_acc       <= 38'sh0;
            sample_cnt  <= 5'h0;
            io_outValid <= 1'b0;
            io_outI <= 16'sh0;
            io_outQ <= 16'sh0;
        end else begin
            sample_cnt <= sample_cnt + 5'h1;
            i_acc <= i_acc + i_prod;
            q_acc <= q_acc + q_prod;
            io_outValid <= 1'b0;
            
            if (sample_cnt == 5'd29) begin
                io_outI <= i_acc[37:22];
                io_outQ <= q_acc[37:22];
                io_outValid <= 1'b1;
                i_acc <= 38'sh0;
                q_acc <= 38'sh0;
                sample_cnt <= 5'h0;
            end
        end
    end
endmodule

// ========================================================================
// 3. FskDecim - 8x Decimation (2MSPS -> 250kHz)
// ========================================================================
module FskDecim(
    input  wire        clock,
    input  wire        reset,
    input  wire signed [15:0] io_inI,
    input  wire signed [15:0] io_inQ,
    input  wire        io_inValid,
    output reg  signed [15:0] io_outI,
    output reg  signed [15:0] io_outQ,
    output reg          io_outValid
);
    reg signed [19:0] i_sum, q_sum;
    reg [2:0] cnt;

    always @(posedge clock) begin
        if (reset) begin
            i_sum       <= 20'sh0;
            q_sum       <= 20'sh0;
            cnt         <= 3'b0;
            io_outI     <= 16'sh0;
            io_outQ     <= 16'sh0;
            io_outValid <= 1'b0;
        end else if (io_inValid) begin
            if (cnt == 3'd7) begin
                io_outI <= (i_sum + io_inI) >>> 3;
                io_outQ <= (q_sum + io_inQ) >>> 3;
                i_sum   <= 20'sh0;
                q_sum   <= 20'sh0;
                cnt     <= 3'b0;
                io_outValid <= 1'b1;
            end else begin
                i_sum <= i_sum + io_inI;
                q_sum <= q_sum + io_inQ;
                cnt   <= cnt + 3'h1;
                io_outValid <= 1'b0;
            end
        end else begin
            io_outValid <= 1'b0;
        end
    end
endmodule

// ========================================================================
// 4. FskDiscriminator - Frequency Discriminator + Hysteresis Comparator
// ========================================================================
module FskDiscriminator(
    input  wire        clock,
    input  wire        reset,
    input  wire signed [15:0] io_inI,
    input  wire signed [15:0] io_inQ,
    input  wire        io_inValid,
    output reg         io_outBit,
    output reg         io_outValid,
    output reg [29:0]  io_outAbsDiff
);
    // Delayed samples
    reg signed [15:0] i_d1, q_d1;
    reg inValid_d1;
    reg ioValid_d2;

    always @(posedge clock) begin
        if (reset) begin
            i_d1 <= 16'sh0; 
            q_d1 <= 16'sh0;
            inValid_d1 <= 1'b0;
            ioValid_d2 <= 1'b0;
        end else begin
            inValid_d1 <= io_inValid;
            ioValid_d2 <= inValid_d1;
            if (io_inValid) begin
                i_d1 <= io_inI;
                q_d1 <= io_inQ;
            end
        end
    end

    // Differential algorithm
    wire signed [15:0] delta_i = io_inI - i_d1;
    wire signed [15:0] delta_q = io_inQ - q_d1;
    wire signed [31:0] mult1 = io_inI * delta_q;
    wire signed [31:0] mult2 = io_inQ * delta_i;
    wire signed [33:0] d_raw = mult1 - mult2;

    // 8-point moving average filter
    reg signed [31:0] shift_reg[0:7];
    integer k;
    reg signed [34:0] filter_sum;
    
    always @(posedge clock) begin
        if (reset) begin
            for (k=0; k<8; k=k+1) shift_reg[k] <= 32'sh0;
            filter_sum <= 35'sh0;
        end else if (inValid_d1) begin
            shift_reg[0] <= d_raw;
            for (k=1; k<8; k=k+1) shift_reg[k] <= shift_reg[k-1];
            filter_sum <= shift_reg[0] + shift_reg[1] + shift_reg[2] + shift_reg[3] +
                          shift_reg[4] + shift_reg[5] + shift_reg[6] + shift_reg[7];
        end
    end
    
    wire signed [31:0] d_smoothed = filter_sum >>> 3;

    // Hysteresis Comparator - adjusted thresholds for FSK detection
    parameter signed [31:0] TH_HIGH = 32'sd100;
    parameter signed [31:0] TH_LOW  = -32'sd100;

    always @(posedge clock) begin
        if (reset) begin
            io_outBit <= 1'b0;
        end else if (ioValid_d2) begin
            if (d_smoothed > TH_HIGH)
                io_outBit <= 1'b1;
            else if (d_smoothed < TH_LOW)
                io_outBit <= 1'b0;
        end
    end

    // Amplitude statistics for h estimation
    reg signed [47:0] absAcc;
    reg [7:0] absCnt;

    always @(posedge clock) begin
        if (reset) begin
            absAcc        <= 48'sh0;
            absCnt        <= 8'h0;
            io_outAbsDiff <= 30'h0;
            io_outValid  <= 1'b0;
        end else begin
            io_outValid <= ioValid_d2;
            
            if (ioValid_d2) begin
                if (absCnt == 8'd255) begin
                    absAcc        <= 48'sh0;
                    absCnt        <= 8'h0;
                    io_outAbsDiff <= absAcc[44:15];
                end else begin
                    absCnt <= absCnt + 8'h1;
                    absAcc <= absAcc + (d_smoothed[31] ? (-d_smoothed) : d_smoothed);
                end
            end
        end
    end
endmodule

// ========================================================================
// 5. FskParamEstimator - Rc and h Estimation
// ========================================================================
module FskParamEstimator(
    input  wire        clock,
    input  wire        reset,
    input  wire        io_bit,
    input  wire        io_bitValid,
    input  wire [29:0] io_absDiff,
    output reg  [1:0]  io_rcCode,
    output reg  [1:0]  io_hCode
);
    reg [15:0] pulseCnt;
    reg [15:0] minPulse;
    reg [19:0] winTimer;
    reg lastBit;
    reg bit_valid_d1;

    // 250kHz clock period = 4us
    // 6k -> 166.7us -> ~42 cycles
    // 8k -> 125.0us -> ~31 cycles
    // 10k -> 100.0us -> ~25 cycles

    always @(posedge clock) begin
        if (reset) begin
            pulseCnt  <= 16'h0;
            minPulse  <= 16'hFFFF;
            winTimer  <= 20'h0;
            lastBit   <= 1'b0;
            bit_valid_d1 <= 1'b0;
            io_rcCode <= 2'b01;  // Default 8k
        end else begin
            bit_valid_d1 <= io_bitValid;
            
            if (io_bitValid) begin
                winTimer <= winTimer + 1'b1;

                if (io_bit != lastBit) begin
                    // Filter out glitches < 10 cycles
                    if (pulseCnt > 16'd10 && pulseCnt < minPulse) begin
                        minPulse <= pulseCnt;
                    end
                    pulseCnt <= 16'h0;
                    lastBit <= io_bit;
                end else begin
                    pulseCnt <= pulseCnt + 1'b1;
                end

                // Update every 10ms (2500 cycles @ 250kHz) for faster convergence
                if (winTimer >= 20'd2500) begin
                    winTimer <= 20'h0;
                    
                    // Rc thresholds adjusted for 250kHz processing
                    if (minPulse > 16'd36)
                        io_rcCode <= 2'b00;  // 6k
                    else if (minPulse > 16'd28)
                        io_rcCode <= 2'b01;  // 8k
                    else
                        io_rcCode <= 2'b10;  // 10k

                    minPulse <= 16'hFFFF;
                end
            end
        end
    end

    // h estimation based on normalized amplitude diff
    wire [19:0] normDiff = io_absDiff[29:10];
    always @(posedge clock) begin
        if (reset) begin
            io_hCode <= 2'b00;  // Default h=2
        end else begin
            // Thresholds adjusted for expected amplitude ranges
            if (normDiff < 20'd15)
                io_hCode <= 2'b00;  // h=2
            else if (normDiff < 20'd25)
                io_hCode <= 2'b01;  // h=3
            else if (normDiff < 20'd40)
                io_hCode <= 2'b10;  // h=4
            else
                io_hCode <= 2'b11;  // h=5
        end
    end
endmodule

// ========================================================================
// 6. FskUi - User Interface
// ========================================================================
module FskUi(
    input  wire        clock,
    input  wire        reset,
    input  wire        io_key1,        // Low-active
    input  wire        io_key2,        // Low-active
    input  wire [1:0] io_rcCode,
    input  wire [1:0] io_hCode,
    input  wire        io_demodBit,
    input  wire        io_valid,
    output wire [3:0] io_led,
    output reg  [13:0] io_dacData
);
    // Continuous DAC output based on demodulated bit
    reg bit_sync;
    reg [15:0] baseband_cnt;
    
    always @(posedge clock) begin
        if (reset) begin
            io_dacData <= 14'h2000;  // Mid-scale (0V)
            bit_sync <= 1'b0;
            baseband_cnt <= 16'h0;
        end else begin
            bit_sync <= io_demodBit;
            
            if (io_valid) begin
                baseband_cnt <= baseband_cnt + 16'h1;
                io_dacData <= io_demodBit ? 14'h3FFF : 14'h0000;
            end
        end
    end

    // LED encoding (1=LED on in software logic)
    // LED assignment: [LED4, LED3, LED2, LED1] = [J16, K16, M15, M14]
    // LED1=M14, LED2=M15, LED3=K16, LED4=J16
    
    // Rc display (when key2_n=1, i.e., not pressed):
    //   6k  -> LED2,3 ON -> 0110
    //   8k  -> LED4 ON -> 1000
    //   10k -> LED4,2 ON -> 1010
    wire [3:0] rcLedCode = (io_rcCode == 2'd0) ? 4'b0110 :   // 6k
                           (io_rcCode == 2'd1) ? 4'b1000 :   // 8k
                           4'b1010;                           // 10k

    // h display (when key2_n=0, i.e., pressed):
    //   h=2 -> LED2 ON -> 0010
    //   h=3 -> LED1,2 ON -> 0011
    //   h=4 -> LED3 ON -> 0100
    //   h=5 -> LED1,3 ON -> 0101
    wire [3:0] hLedCode = (io_hCode == 2'd0) ? 4'b0010 :   // h=2
                          (io_hCode == 2'd1) ? 4'b0011 :   // h=3
                          (io_hCode == 2'd2) ? 4'b0100 :   // h=4
                          4'b0101;                          // h=5

    // KEY2 (io_key2=0 when pressed) shows h, otherwise shows Rc
    // When key2_n=0 (pressed), show_h=1
    wire show_h = (io_key2 == 1'b0);
    assign io_led = show_h ? hLedCode : rcLedCode;
endmodule

// ========================================================================
// 7. FskDemodCore - Complete Assembly
// ========================================================================
module FskDemodCore(
    input  wire        io_clkAdc,
    input  wire        io_rstAdcAsync,
    input  wire [11:0] io_inAdcA,
    input  wire        io_inAdcOra,
    input  wire        io_inKey1,
    input  wire        io_inKey2,
    output wire        io_outDemodBit,
    output wire        io_outDemodValid,
    output wire        io_outDemodLocked,
    output wire [1:0] io_outRcCode,
    output wire [1:0] io_outHCode,
    output wire [3:0] io_outLed,
    output wire [13:0] io_outDacData,
    output wire [29:0] io_outAbsDiff
);
    wire [15:0] ddc_i, ddc_q;
    wire ddc_valid;
    FskDdc ddc (
        .clock(io_clkAdc),
        .reset(io_rstAdcAsync),
        .io_adcIn(io_inAdcA),
        .io_adcOra(io_inAdcOra),
        .io_outI(ddc_i),
        .io_outQ(ddc_q),
        .io_outValid(ddc_valid)
    );

    wire [15:0] decim_i, decim_q;
    wire decim_valid;
    FskDecim decim (
        .clock(io_clkAdc),
        .reset(io_rstAdcAsync),
        .io_inI(ddc_i),
        .io_inQ(ddc_q),
        .io_inValid(ddc_valid),
        .io_outI(decim_i),
        .io_outQ(decim_q),
        .io_outValid(decim_valid)
    );

    wire disc_bit, disc_valid;
    wire [29:0] disc_absDiff;
    FskDiscriminator disc (
        .clock(io_clkAdc),
        .reset(io_rstAdcAsync),
        .io_inI(decim_i),
        .io_inQ(decim_q),
        .io_inValid(decim_valid),
        .io_outBit(disc_bit),
        .io_outValid(disc_valid),
        .io_outAbsDiff(disc_absDiff)
    );

    wire [1:0] parm_rcCode, parm_hCode;
    FskParamEstimator parm (
        .clock(io_clkAdc),
        .reset(io_rstAdcAsync),
        .io_bit(disc_bit),
        .io_bitValid(disc_valid),
        .io_absDiff(disc_absDiff),
        .io_rcCode(parm_rcCode),
        .io_hCode(parm_hCode)
    );

    wire [3:0] ui_led;
    wire [13:0] ui_dacData;
    FskUi ui (
        .clock      (io_clkAdc),
        .reset      (io_rstAdcAsync),
        .io_key1    (io_inKey1),
        .io_key2    (io_inKey2),
        .io_rcCode  (parm_rcCode),
        .io_hCode   (parm_hCode),
        .io_demodBit(disc_bit),
        .io_valid   (disc_valid),
        .io_led     (ui_led),
        .io_dacData (ui_dacData)
    );

    assign io_outDemodBit    = disc_bit;
    assign io_outDemodValid  = disc_valid;
    assign io_outDemodLocked = 1'b1;
    assign io_outRcCode      = parm_rcCode;
    assign io_outHCode       = parm_hCode;
    assign io_outLed         = ui_led;
    assign io_outDacData     = ui_dacData;
    assign io_outAbsDiff     = disc_absDiff;
endmodule

`default_nettype wire
