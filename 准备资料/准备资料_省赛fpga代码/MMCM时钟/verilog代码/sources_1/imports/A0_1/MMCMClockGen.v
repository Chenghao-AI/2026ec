`timescale 1ns / 1ps
module DividerByCount(
  input   clock,
  input   reset,
  input   io_rst_in, // @[src/main/scala/A2_1/MMCMClockGen.scala 59:14]
  output  io_clk_out // @[src/main/scala/A2_1/MMCMClockGen.scala 59:14]
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
`endif // RANDOMIZE_REG_INIT
  reg [15:0] cnt; // @[src/main/scala/A2_1/MMCMClockGen.scala 65:21]
  reg  out; // @[src/main/scala/A2_1/MMCMClockGen.scala 66:21]
  wire [15:0] _cnt_T_1 = cnt + 16'h1; // @[src/main/scala/A2_1/MMCMClockGen.scala 73:16]
  assign io_clk_out = out; // @[src/main/scala/A2_1/MMCMClockGen.scala 79:14]
  
always @(posedge clock) begin
  if (reset) begin // @[src/main/scala/A2_1/MMCMClockGen.scala 65:21]
    cnt <= 16'h0; // @[src/main/scala/A2_1/MMCMClockGen.scala 65:21]
  end else if (io_rst_in) begin // @[src/main/scala/A2_1/MMCMClockGen.scala 69:19]
    cnt <= 16'h0; // @[src/main/scala/A2_1/MMCMClockGen.scala 70:9]
  end else if (cnt == 16'h61a7) begin // 【此处修改为 16'h61a7】
    cnt <= 16'h0; // @[src/main/scala/A2_1/MMCMClockGen.scala 75:11]
  end else begin
    cnt <= _cnt_T_1; // @[src/main/scala/A2_1/MMCMClockGen.scala 73:9]
  end
  if (reset) begin // @[src/main/scala/A2_1/MMCMClockGen.scala 66:21]
    out <= 1'h0; // @[src/main/scala/A2_1/MMCMClockGen.scala 66:21]
  end else if (io_rst_in) begin // @[src/main/scala/A2_1/MMCMClockGen.scala 69:19]
    out <= 1'h0; // @[src/main/scala/A2_1/MMCMClockGen.scala 71:9]
  end else if (cnt == 16'h61a7) begin 
    out <= ~out; // @[src/main/scala/A2_1/MMCMClockGen.scala 76:11]
  end
end
// Register and memory initialization
`ifdef RANDOMIZE_GARBAGE_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_INVALID_ASSIGN
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_REG_INIT
`define RANDOMIZE
`endif
`ifdef RANDOMIZE_MEM_INIT
`define RANDOMIZE
`endif
`ifndef RANDOM
`define RANDOM $random
`endif
`ifdef RANDOMIZE_MEM_INIT
  integer initvar;
`endif
`ifndef SYNTHESIS
`ifdef FIRRTL_BEFORE_INITIAL
`FIRRTL_BEFORE_INITIAL
`endif
initial begin
  `ifdef RANDOMIZE
    `ifdef INIT_RANDOM
      `INIT_RANDOM
    `endif
    `ifndef VERILATOR
      `ifdef RANDOMIZE_DELAY
        #`RANDOMIZE_DELAY begin end
      `else
        #0.002 begin end
      `endif
    `endif
`ifdef RANDOMIZE_REG_INIT
  _RAND_0 = {1{`RANDOM}};
  cnt = _RAND_0[15:0];
  _RAND_1 = {1{`RANDOM}};
  out = _RAND_1[0:0];
`endif // RANDOMIZE_REG_INIT
  `endif // RANDOMIZE
end // initial
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif // SYNTHESIS
endmodule
module Divider1kHz(
  input   clock,
  input   reset,
  input   io_rst_in, // @[src/main/scala/A2_1/MMCMClockGen.scala 86:14]
  output  io_clk_out // @[src/main/scala/A2_1/MMCMClockGen.scala 86:14]
);
  wire  d_clock; // @[src/main/scala/A2_1/MMCMClockGen.scala 90:17]
  wire  d_reset; // @[src/main/scala/A2_1/MMCMClockGen.scala 90:17]
  wire  d_io_rst_in; // @[src/main/scala/A2_1/MMCMClockGen.scala 90:17]
  wire  d_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 90:17]
  DividerByCount d ( // @[src/main/scala/A2_1/MMCMClockGen.scala 90:17]
    .clock(d_clock),
    .reset(d_reset),
    .io_rst_in(d_io_rst_in),
    .io_clk_out(d_io_clk_out)
  );
  assign io_clk_out = d_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 92:15]
  assign d_clock = clock;
  assign d_reset = reset;
  assign d_io_rst_in = io_rst_in; // @[src/main/scala/A2_1/MMCMClockGen.scala 91:15]
endmodule
module MMCMClockGen(
  input   clock,
  input   reset,
  input   io_clk_50m, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  input   io_reset_n, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_clk_1khz, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_clk_2khz, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_clk_half_khz, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_mmcm_locked, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_led_locked, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_led_1khz, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_led_2khz, // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
  output  io_led_half_khz // @[src/main/scala/A2_1/MMCMClockGen.scala 160:14]
);
  wire  mmcm_CLKIN1; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  mmcm_CLKFBOUT; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  mmcm_CLKOUT0; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  mmcm_CLKOUT1; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  mmcm_RESETN; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  mmcm_LOCKED; // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
  wire  div1kHz_clock; // @[src/main/scala/A2_1/MMCMClockGen.scala 189:54]
  wire  div1kHz_reset; // @[src/main/scala/A2_1/MMCMClockGen.scala 189:54]
  wire  div1kHz_io_rst_in; // @[src/main/scala/A2_1/MMCMClockGen.scala 189:54]
  wire  div1kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 189:54]
  wire  div2kHz_clock; // @[src/main/scala/A2_1/MMCMClockGen.scala 192:54]
  wire  div2kHz_reset; // @[src/main/scala/A2_1/MMCMClockGen.scala 192:54]
  wire  div2kHz_io_rst_in; // @[src/main/scala/A2_1/MMCMClockGen.scala 192:54]
  wire  div2kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 192:54]
  wire  divHalf_clock; // @[src/main/scala/A2_1/MMCMClockGen.scala 195:54]
  wire  divHalf_reset; // @[src/main/scala/A2_1/MMCMClockGen.scala 195:54]
  wire  divHalf_io_rst_in; // @[src/main/scala/A2_1/MMCMClockGen.scala 195:54]
  wire  divHalf_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 195:54]
  MMCM_Wrapper mmcm ( // @[src/main/scala/A2_1/MMCMClockGen.scala 182:20]
    .CLKIN1(mmcm_CLKIN1),
    .CLKFBOUT(mmcm_CLKFBOUT),
    .CLKOUT0(mmcm_CLKOUT0),
    .CLKOUT1(mmcm_CLKOUT1),
    .RESETN(mmcm_RESETN),
    .LOCKED(mmcm_LOCKED)
  );
  Divider1kHz div1kHz ( // @[src/main/scala/A2_1/MMCMClockGen.scala 189:54]
    .clock(div1kHz_clock),
    .reset(div1kHz_reset),
    .io_rst_in(div1kHz_io_rst_in),
    .io_clk_out(div1kHz_io_clk_out)
  );
  Divider1kHz div2kHz ( // @[src/main/scala/A2_1/MMCMClockGen.scala 192:54]
    .clock(div2kHz_clock),
    .reset(div2kHz_reset),
    .io_rst_in(div2kHz_io_rst_in),
    .io_clk_out(div2kHz_io_clk_out)
  );
  Divider1kHz divHalf ( // @[src/main/scala/A2_1/MMCMClockGen.scala 195:54]
    .clock(divHalf_clock),
    .reset(divHalf_reset),
    .io_rst_in(divHalf_io_rst_in),
    .io_clk_out(divHalf_io_clk_out)
  );
  assign io_clk_1khz = div1kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 201:19]
  assign io_clk_2khz = div2kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 202:19]
  assign io_clk_half_khz = divHalf_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 203:19]
  assign io_mmcm_locked = mmcm_LOCKED; // @[src/main/scala/A2_1/MMCMClockGen.scala 204:19]
  assign io_led_locked = ~mmcm_LOCKED; // @[src/main/scala/A2_1/MMCMClockGen.scala 207:22]
  assign io_led_1khz = ~div1kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 208:22]
  assign io_led_2khz = ~div2kHz_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 209:22]
  assign io_led_half_khz = ~divHalf_io_clk_out; // @[src/main/scala/A2_1/MMCMClockGen.scala 210:22]
  assign mmcm_CLKIN1 = io_clk_50m; // @[src/main/scala/A2_1/MMCMClockGen.scala 183:18]
  assign mmcm_RESETN = io_reset_n; // @[src/main/scala/A2_1/MMCMClockGen.scala 184:18]
  assign div1kHz_clock = io_clk_50m;
  assign div1kHz_reset = reset;
  assign div1kHz_io_rst_in = ~io_reset_n; // @[src/main/scala/A2_1/MMCMClockGen.scala 190:24]
  assign div2kHz_clock = mmcm_CLKOUT0;
  assign div2kHz_reset = reset;
  assign div2kHz_io_rst_in = ~io_reset_n; // @[src/main/scala/A2_1/MMCMClockGen.scala 193:24]
  assign divHalf_clock = mmcm_CLKOUT1;
  assign divHalf_reset = reset;
  assign divHalf_io_rst_in = ~io_reset_n; // @[src/main/scala/A2_1/MMCMClockGen.scala 196:24]
endmodule
