`timescale 1ns / 1ps

module top (
    input  wire clk_50m,    // 50MHz PL clock (U18)

    // DAC8571 I2C
    inout  wire sda,        // I2C data (H16)
    output wire scl,        // I2C clock (H15)

    // PL keys (active-low)
    input  wire key1,       // N15
    input  wire key2,       // N16
    input  wire key3,       // T17
    input  wire key4,       // R17

    // PL LEDs (active-low)
    output wire [3:0] led
);

    // ---- BUFG ----
    wire clk_50m_bufg;
    BUFG bufg_clk_50m (.I(clk_50m), .O(clk_50m_bufg));

    // ---- power-on reset ----
    reg [15:0] rst_cnt = 16'h0000;
    wire rst_n = rst_cnt[15];
    always @(posedge clk_50m_bufg) begin
        if (rst_cnt[15] == 1'b0) rst_cnt <= rst_cnt + 1;
    end

    // ---- ?? + AM ???? (Step 2-1 ???) ----
    wire        mode_sel;
    wire [3:0]  atten_idx;
    wire [2:0]  mod_idx;
    wire [2:0]  delay_idx;
    wire [3:0]  fsm_led;
    wire [15:0] am_dac_data;
    wire        am_write_req;

    Step2Top u_step2 (
        .clock        (clk_50m_bufg),
        .reset        (~rst_n),
        .io_keyRaw_0  (key1),
        .io_keyRaw_1  (key2),
        .io_keyRaw_2  (key3),
        .io_keyRaw_3  (key4),
        .io_modeSel   (mode_sel),
        .io_attenIdx  (atten_idx),
        .io_modIdx    (mod_idx),
        .io_delayIdx  (delay_idx),
        .io_led_0     (fsm_led[0]),
        .io_led_1     (fsm_led[1]),
        .io_led_2     (fsm_led[2]),
        .io_led_3     (fsm_led[3]),
        .io_dacData   (am_dac_data),
        .io_dacWriteReq (am_write_req)
    );

    // ---- I2C DAC ?? ----
    wire i2c_sda_out;
    wire i2c_sda_en;
    wire i2c_scl;
    wire i2c_busy;
    wire i2c_done;
    wire i2c_ack_error;
    wire sda_in;

    I2C_DAC8571 u_i2c (
        .clock        (clk_50m_bufg),
        .reset        (~rst_n),
        .io_start     (am_write_req),
        .io_data_in   (am_dac_data),
        .io_sda_in    (sda_in),
        .io_busy      (i2c_busy),
        .io_done      (i2c_done),
        .io_ack_error (i2c_ack_error),
        .io_scl       (i2c_scl),
        .io_sda_out   (i2c_sda_out),
        .io_sda_en    (i2c_sda_en)
    );

    // ---- I2C SDA ?? ----
    IOBUF #(
        .DRIVE(12),
        .SLEW("SLOW")
    ) IOBUF_sda (
        .O  (sda_in),
        .IO (sda),
        .I  (1'b0),
        .T  (~i2c_sda_en | i2c_sda_out)
    );

    OBUF OBUF_scl (.O(scl), .I(i2c_scl));

    // ---- LED ?? (active-low) ----
    assign led[0] = ~fsm_led[0];
    assign led[1] = ~fsm_led[1];
    assign led[2] = ~fsm_led[2];
    assign led[3] = ~fsm_led[3];

endmodule