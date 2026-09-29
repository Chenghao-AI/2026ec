`timescale 1ns/1ps
module DualAdcCapture(
  input         clock,
  input         reset,
  input  [11:0] io_io_adc_data_a_raw,
  input  [11:0] io_io_adc_data_b_raw,
  input         io_io_ora_raw,
  input         io_io_orb_raw,
  output [11:0] io_io_adc_data_a,
  output [11:0] io_io_adc_data_b,
  output        io_io_ora,
  output        io_io_orb
);

  reg [11:0] aReg;
  reg [11:0] bReg;
  reg        oraReg;
  reg        orbReg;

  always @(posedge clock) begin
    if (reset) begin
      aReg   <= 12'h0;
      bReg   <= 12'h0;
      oraReg <= 1'h0;
      orbReg <= 1'h0;
    end else begin
      aReg   <= io_io_adc_data_a_raw;
      bReg   <= io_io_adc_data_b_raw;
      oraReg <= io_io_ora_raw;
      orbReg <= io_io_orb_raw;
    end
  end

  assign io_io_adc_data_a = aReg;
  assign io_io_adc_data_b = bReg;
  assign io_io_ora        = oraReg;
  assign io_io_orb        = orbReg;

endmodule