`timescale 1ns / 1ps

(* KEEP = "true" *)
module top (
    input  wire clk_50m,    // 50MHz PL clock (U18)

    // DAC8571 I2C鎺ュ彛
    inout  wire sda,        // I2C data (H16)
    output wire scl,        // I2C clock (H15)
    output wire dac_led,    
    output wire ack_led     
);

    reg [15:0] rst_cnt = 16'h0000;
    wire rst_n = rst_cnt[15];

    always @(posedge clk_50m) begin
        if (rst_cnt[15] == 1'b0) begin
            rst_cnt <= rst_cnt + 1;
        end
    end

    wire        sine_write_req;
    wire [15:0] sine_dac_data;

    SineWaveGenerator u_sine (
        .clock     (clk_50m),
        .reset     (~rst_n),
        .io_enable (1'b1),
        .io_dac_data (sine_dac_data),
        .io_write_req(sine_write_req)
    );

    wire i2c_sda_out;
    wire i2c_sda_en;
    wire i2c_scl;
    wire i2c_busy;
    wire i2c_done;
    wire i2c_ack_error;
    wire sda_in;  

    I2C_DAC8571 u_i2c (
        .clock     (clk_50m),
        .reset     (~rst_n),
        .io_start  (sine_write_req),
        .io_data_in(sine_dac_data),
        .io_sda_in (sda_in),
        .io_busy   (i2c_busy),
        .io_done   (i2c_done),
        .io_ack_error(i2c_ack_error),
        .io_scl    (i2c_scl),
        .io_sda_out(i2c_sda_out),
        .io_sda_en (i2c_sda_en)
    );

    IOBUF #(
        .DRIVE(12),
        .SLEW("SLOW")
    ) IOBUF_sda (
        .O  (sda_in),       
        .IO (sda),           
        .I  (1'b0),                      // 始终只往总线驱动低电平 0
        .T  (~i2c_sda_en | i2c_sda_out)  // 只有当使能且控制器想输出0时，才使能Buffer拉低；其余时间自动释放为高阻态
    );

    OBUF OBUF_scl (
        .O (scl),
        .I (i2c_scl)
    );

    OBUF OBUF_dac_led (
        .O (dac_led),
        .I (i2c_busy)
    );

    OBUF OBUF_ack_led (
        .O (ack_led),
        .I (i2c_ack_error)
    );

endmodule
