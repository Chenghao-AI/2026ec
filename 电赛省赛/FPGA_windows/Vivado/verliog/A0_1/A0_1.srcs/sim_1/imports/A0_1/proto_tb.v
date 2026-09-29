`timescale 1ns / 1ps
`default_nettype none

// End-to-end protocol test:
//   full framed START -> framed RESULT -> framed ACK
//   second START uses a non-consecutive SEQ and must be echoed
//   framed RESEND must reproduce the identical result
module proto_tb;

    localparam integer NW = 8;
    localparam integer NK = 8;
    localparam integer RESULT_PAYLOAD_LEN = 21 + 2*NW + 2*NK;
    localparam integer RESULT_FRAME_LEN = 8 + RESULT_PAYLOAD_LEN;
    localparam integer UART_BIT_NS = 2176;

    reg clk_4m = 1'b0;
    reg clk_uart = 1'b0;
    reg rst = 1'b1;
    always #125 clk_4m = ~clk_4m;
    always #34  clk_uart = ~clk_uart;

    reg rx_serial = 1'b1;
    wire tx_serial;

    reg signed [11:0] wave_max = 12'sd100;
    reg signed [11:0] wave_min = -12'sd100;
    wire [10:0] wave_rd_idx;
    reg signed [11:0] wave_rd_data = 12'sd0;
    wire [10:0] spec_rd_idx;
    reg [15:0] spec_rd_data = 16'd0;
    wire snapshot_pulse;
    wire error_state;
    wire busy;

    always @(posedge clk_4m) begin
        wave_rd_data <= $signed({1'b0, wave_rd_idx});
        spec_rd_data <= 16'd100 + spec_rd_idx;
    end

    protocol_engine #(
        .N_WAVEFORM (NW),
        .N_SPECTRUM (NK)
    ) u_dut (
        .clk_4m        (clk_4m),
        .clk_uart      (clk_uart),
        .rst           (rst),
        .rx_serial     (rx_serial),
        .tx_serial     (tx_serial),
        .wave_max      (wave_max),
        .wave_min      (wave_min),
        .wave_rd_idx   (wave_rd_idx),
        .wave_rd_data  (wave_rd_data),
        .spec_rd_idx   (spec_rd_idx),
        .spec_rd_data  (spec_rd_data),
        .data_ready    (1'b1),
        .snapshot_pulse(snapshot_pulse),
        .error_state   (error_state),
        .busy          (busy)
    );

    function [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] data_in;
        integer j;
        reg [15:0] c;
        begin
            c = crc_in ^ {data_in, 8'h00};
            for (j = 0; j < 8; j = j + 1) begin
                if (c[15])
                    c = (c << 1) ^ 16'h1021;
                else
                    c = c << 1;
            end
            crc16_next = c;
        end
    endfunction

    task uart_send_byte;
        input [7:0] value;
        integer bit_number;
        begin
            rx_serial = 1'b0;
            #(UART_BIT_NS);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                rx_serial = value[bit_number];
                #(UART_BIT_NS);
            end
            rx_serial = 1'b1;
            #(UART_BIT_NS);
        end
    endtask

    task send_start;
        input [7:0] sequence;
        reg [15:0] crc;
        begin
            crc = 16'hFFFF;
            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);
            uart_send_byte(8'h01); crc = crc16_next(crc, 8'h01);
            uart_send_byte(sequence); crc = crc16_next(crc, sequence);
            uart_send_byte(8'h00); crc = crc16_next(crc, 8'h00);
            uart_send_byte(8'h01); crc = crc16_next(crc, 8'h01);
            uart_send_byte(8'h01); crc = crc16_next(crc, 8'h01);
            uart_send_byte(crc[15:8]);
            uart_send_byte(crc[7:0]);
        end
    endtask

    task send_zero_payload_command;
        input [7:0] command_type;
        input [7:0] sequence;
        reg [15:0] crc;
        begin
            crc = 16'hFFFF;
            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);
            uart_send_byte(command_type); crc = crc16_next(crc, command_type);
            uart_send_byte(sequence); crc = crc16_next(crc, sequence);
            uart_send_byte(8'h00); crc = crc16_next(crc, 8'h00);
            uart_send_byte(8'h00); crc = crc16_next(crc, 8'h00);
            uart_send_byte(crc[15:8]);
            uart_send_byte(crc[7:0]);
        end
    endtask

    reg tx_busy_previous = 1'b0;
    reg [7:0] tx_bytes [0:511];
    integer tx_count = 0;
    always @(posedge clk_uart) begin
        tx_busy_previous <= u_dut.tx_busy_uart;
        if (u_dut.tx_busy_uart && !tx_busy_previous) begin
            tx_bytes[tx_count] = u_dut.tx_data_uart;
            tx_count = tx_count + 1;
        end
    end

    integer i;
    integer first_offset;
    integer second_offset;
    integer resend_offset;
    reg [15:0] result_crc;

    initial begin
        repeat (20) @(posedge clk_uart);
        rst = 1'b0;
        repeat (20) @(posedge clk_uart);

        // First complete transaction.
        send_start(8'h2A);
        wait (tx_count >= RESULT_FRAME_LEN);

        if (tx_bytes[0] !== 8'hAA || tx_bytes[1] !== 8'h55
            || tx_bytes[2] !== 8'h20 || tx_bytes[3] !== 8'h2A)
            $fatal(1, "Bad result header or START SEQ was not echoed");
        if ({tx_bytes[4], tx_bytes[5]} !== RESULT_PAYLOAD_LEN)
            $fatal(1, "Bad result payload length");

        result_crc = 16'hFFFF;
        for (i = 2; i < RESULT_FRAME_LEN-2; i = i + 1)
            result_crc = crc16_next(result_crc, tx_bytes[i]);
        if ({tx_bytes[RESULT_FRAME_LEN-2], tx_bytes[RESULT_FRAME_LEN-1]}
            !== result_crc)
            $fatal(1, "Bad result CRC");

        send_zero_payload_command(8'h10, 8'h2A);
        wait (!busy);

        // Non-consecutive SEQ proves that FPGA echoes STM32 rather than using
        // an independent local counter.
        first_offset = tx_count;
        send_start(8'hA5);
        wait (tx_count >= first_offset + RESULT_FRAME_LEN);
        if (tx_bytes[first_offset+3] !== 8'hA5)
            $fatal(1, "Second START SEQ was not echoed");

        // RESEND must return byte-for-byte identical data.
        second_offset = first_offset;
        resend_offset = tx_count;
        send_zero_payload_command(8'h03, 8'hA5);
        wait (tx_count >= resend_offset + RESULT_FRAME_LEN);
        for (i = 0; i < RESULT_FRAME_LEN; i = i + 1) begin
            if (tx_bytes[second_offset+i] !== tx_bytes[resend_offset+i])
                $fatal(1, "RESEND differs at byte %0d", i);
        end

        send_zero_payload_command(8'h10, 8'hA5);
        wait (!busy);
        if (error_state)
            $fatal(1, "Unexpected protocol error");

        $display("PASS: framed START/RESULT/ACK/RESEND protocol");
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "Protocol test timeout");
    end

endmodule
`default_nettype wire
