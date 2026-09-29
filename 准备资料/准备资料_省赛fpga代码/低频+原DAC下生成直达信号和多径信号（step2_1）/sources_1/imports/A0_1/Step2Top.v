module KeyDebounce(
  input   clock,
  input   reset,
  input   io_raw_in,
  output  io_pulse,
  output  io_stable
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
  reg [31:0] _RAND_2;
  reg [31:0] _RAND_3;
  reg [31:0] _RAND_4;
`endif
  reg  sync0;
  reg  sync1;
  reg [18:0] cnt;
  reg  stable;
  wire  _T = sync1 == stable;
  wire  _T_1 = cnt == 19'h7a11f;
  wire  _pulseNow_T = ~stable;
  wire  _pulseNow_T_1 = ~stable & sync1;
  wire [19:0] _cnt_T = cnt + 19'h1;
  wire [18:0] _cnt_T_1 = cnt + 19'h1;
  wire [18:0] _GEN_0 = cnt == 19'h7a11f ? 19'h0 : _cnt_T_1;
  wire  _GEN_1 = cnt == 19'h7a11f ? sync1 : stable;
  wire  _GEN_2 = cnt == 19'h7a11f & (~stable & sync1);
  wire [18:0] _GEN_3 = sync1 == stable ? 19'h0 : _GEN_0;
  wire  _GEN_4 = sync1 == stable ? stable : _GEN_1;
  wire  pulseNow = sync1 == stable ? 1'h0 : _GEN_2;
  reg  pulseReg;
  wire  _GEN_5 = pulseNow;
  assign io_pulse = pulseReg;
  assign io_stable = stable;
  always @(posedge clock) begin
    if (reset) begin
      sync0 <= 1'h0;
    end else begin
      sync0 <= io_raw_in;
    end
    if (reset) begin
      sync1 <= 1'h0;
    end else begin
      sync1 <= sync0;
    end
    if (reset) begin
      cnt <= 19'h0;
    end else if (sync1 == stable) begin
      cnt <= 19'h0;
    end else if (cnt == 19'h7a11f) begin
      cnt <= 19'h0;
    end else begin
      cnt <= _cnt_T_1;
    end
    if (reset) begin
      stable <= 1'h0;
    end else if (!(sync1 == stable)) begin
      if (cnt == 19'h7a11f) begin
        stable <= sync1;
      end
    end
    if (reset) begin
      pulseReg <= 1'h0;
    end else if (sync1 == stable) begin
      pulseReg <= 1'h0;
    end else begin
      pulseReg <= _GEN_2;
    end
  end
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
  sync0 = _RAND_0[0:0];
  _RAND_1 = {1{`RANDOM}};
  sync1 = _RAND_1[0:0];
  _RAND_2 = {1{`RANDOM}};
  cnt = _RAND_2[18:0];
  _RAND_3 = {1{`RANDOM}};
  stable = _RAND_3[0:0];
  _RAND_4 = {1{`RANDOM}};
  pulseReg = _RAND_4[0:0];
`endif
  `endif
end
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif
endmodule
module ParamControlFSM(
  input        clock,
  input        reset,
  input        io_key1Pulse,
  input        io_key2Pulse,
  input        io_key3Pulse,
  input        io_key4Pulse,
  output       io_modeSel,
  output [3:0] io_attenIdx,
  output [2:0] io_modIdx,
  output [2:0] io_delayIdx,
  output       io_led_0,
  output       io_led_1,
  output       io_led_2,
  output       io_led_3
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
  reg [31:0] _RAND_2;
  reg [31:0] _RAND_3;
`endif
  reg  modeSel;
  reg [3:0] attenIdx;
  reg [2:0] modIdx;
  reg [2:0] delayIdx;
  wire  _modeSel_T = ~modeSel;
  wire  _GEN_0 = io_key1Pulse ? ~modeSel : modeSel;
  wire  _T = io_key2Pulse & modeSel;
  wire  _attenIdx_T = attenIdx == 4'ha;
  wire [4:0] _attenIdx_T_1 = attenIdx + 4'h1;
  wire [3:0] _attenIdx_T_2 = attenIdx + 4'h1;
  wire [3:0] _attenIdx_T_3 = attenIdx == 4'ha ? 4'h0 : _attenIdx_T_2;
  wire [3:0] _GEN_1 = io_key2Pulse & modeSel ? _attenIdx_T_3 : attenIdx;
  wire  _modIdx_T = modIdx == 3'h6;
  wire [3:0] _modIdx_T_1 = modIdx + 3'h1;
  wire [2:0] _modIdx_T_2 = modIdx + 3'h1;
  wire [2:0] _modIdx_T_3 = modIdx == 3'h6 ? 3'h0 : _modIdx_T_2;
  wire [2:0] _GEN_2 = io_key3Pulse ? _modIdx_T_3 : modIdx;
  wire  _T_1 = io_key4Pulse & modeSel;
  wire  _delayIdx_T = delayIdx == 3'h5;
  wire [3:0] _delayIdx_T_1 = delayIdx + 3'h1;
  wire [2:0] _delayIdx_T_2 = delayIdx + 3'h1;
  wire [2:0] _delayIdx_T_3 = delayIdx == 3'h5 ? 3'h0 : _delayIdx_T_2;
  wire [2:0] _GEN_3 = io_key4Pulse & modeSel ? _delayIdx_T_3 : delayIdx;
  wire  _io_led_0_T = ~modeSel;
  assign io_modeSel = modeSel;
  assign io_attenIdx = attenIdx;
  assign io_modIdx = modIdx;
  assign io_delayIdx = delayIdx;
  assign io_led_0 = ~modeSel;
  assign io_led_1 = modeSel;
  assign io_led_2 = 1'h0;
  assign io_led_3 = 1'h0;
  always @(posedge clock) begin
    if (reset) begin
      modeSel <= 1'h0;
    end else if (io_key1Pulse) begin
      modeSel <= ~modeSel;
    end
    if (reset) begin
      attenIdx <= 4'h0;
    end else if (io_key2Pulse & modeSel) begin
      if (attenIdx == 4'ha) begin
        attenIdx <= 4'h0;
      end else begin
        attenIdx <= _attenIdx_T_2;
      end
    end
    if (reset) begin
      modIdx <= 3'h0;
    end else if (io_key3Pulse) begin
      if (modIdx == 3'h6) begin
        modIdx <= 3'h0;
      end else begin
        modIdx <= _modIdx_T_2;
      end
    end
    if (reset) begin
      delayIdx <= 3'h0;
    end else if (io_key4Pulse & modeSel) begin
      if (delayIdx == 3'h5) begin
        delayIdx <= 3'h0;
      end else begin
        delayIdx <= _delayIdx_T_2;
      end
    end
  end
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
  modeSel = _RAND_0[0:0];
  _RAND_1 = {1{`RANDOM}};
  attenIdx = _RAND_1[3:0];
  _RAND_2 = {1{`RANDOM}};
  modIdx = _RAND_2[2:0];
  _RAND_3 = {1{`RANDOM}};
  delayIdx = _RAND_3[2:0];
`endif
  `endif
end
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif
endmodule
module AMStep2Generator(
  input         clock,
  input         reset,
  input         io_modeSel,
  input  [3:0]  io_attenIdx,
  input  [2:0]  io_modIdx,
  input  [2:0]  io_delayIdx,
  output [15:0] io_dacData,
  output        io_dacWriteReq
);
`ifdef RANDOMIZE_REG_INIT
  reg [31:0] _RAND_0;
  reg [31:0] _RAND_1;
  reg [31:0] _RAND_2;
  reg [31:0] _RAND_3;
  reg [31:0] _RAND_4;
  reg [31:0] _RAND_5;
  reg [31:0] _RAND_6;
  reg [31:0] _RAND_7;
  reg [31:0] _RAND_8;
  reg [31:0] _RAND_9;
  reg [31:0] _RAND_10;
  reg [31:0] _RAND_11;
  reg [31:0] _RAND_12;
  reg [31:0] _RAND_13;
  reg [31:0] _RAND_14;
  reg [31:0] _RAND_15;
  reg [31:0] _RAND_16;
  reg [31:0] _RAND_17;
  reg [31:0] _RAND_18;
  reg [31:0] _RAND_19;
  reg [31:0] _RAND_20;
  reg [31:0] _RAND_21;
  reg [31:0] _RAND_22;
  reg [31:0] _RAND_23;
  reg [31:0] _RAND_24;
  reg [31:0] _RAND_25;
  reg [31:0] _RAND_26;
  reg [31:0] _RAND_27;
  reg [31:0] _RAND_28;
  reg [31:0] _RAND_29;
  reg [31:0] _RAND_30;
  reg [31:0] _RAND_31;
  reg [31:0] _RAND_32;
  reg [31:0] _RAND_33;
  reg [31:0] _RAND_34;
  reg [31:0] _RAND_35;
  reg [31:0] _RAND_36;
  reg [31:0] _RAND_37;
  reg [31:0] _RAND_38;
  reg [31:0] _RAND_39;
  reg [31:0] _RAND_40;
  reg [31:0] _RAND_41;
  reg [31:0] _RAND_42;
  reg [31:0] _RAND_43;
  reg [31:0] _RAND_44;
  reg [31:0] _RAND_45;
  reg [31:0] _RAND_46;
  reg [31:0] _RAND_47;
  reg [31:0] _RAND_48;
  reg [31:0] _RAND_49;
  reg [31:0] _RAND_50;
  reg [31:0] _RAND_51;
  reg [31:0] _RAND_52;
  reg [31:0] _RAND_53;
  reg [31:0] _RAND_54;
  reg [31:0] _RAND_55;
  reg [31:0] _RAND_56;
  reg [31:0] _RAND_57;
  reg [31:0] _RAND_58;
  reg [31:0] _RAND_59;
  reg [31:0] _RAND_60;
  reg [31:0] _RAND_61;
  reg [31:0] _RAND_62;
  reg [31:0] _RAND_63;
  reg [31:0] _RAND_64;
  reg [31:0] _RAND_65;
  reg [31:0] _RAND_66;
  reg [31:0] _RAND_67;
  reg [31:0] _RAND_68;
  reg [31:0] _RAND_69;
  reg [31:0] _RAND_70;
  reg [31:0] _RAND_71;
  reg [31:0] _RAND_72;
  reg [31:0] _RAND_73;
  reg [31:0] _RAND_74;
  reg [31:0] _RAND_75;
  reg [31:0] _RAND_76;
  reg [31:0] _RAND_77;
  reg [31:0] _RAND_78;
  reg [31:0] _RAND_79;
  reg [31:0] _RAND_80;
  reg [31:0] _RAND_81;
  reg [31:0] _RAND_82;
  reg [31:0] _RAND_83;
  reg [31:0] _RAND_84;
  reg [31:0] _RAND_85;
  reg [31:0] _RAND_86;
  reg [31:0] _RAND_87;
  reg [31:0] _RAND_88;
  reg [31:0] _RAND_89;
  reg [31:0] _RAND_90;
  reg [31:0] _RAND_91;
  reg [31:0] _RAND_92;
  reg [31:0] _RAND_93;
  reg [31:0] _RAND_94;
  reg [31:0] _RAND_95;
  reg [31:0] _RAND_96;
  reg [31:0] _RAND_97;
  reg [31:0] _RAND_98;
  reg [31:0] _RAND_99;
  reg [31:0] _RAND_100;
  reg [31:0] _RAND_101;
  reg [31:0] _RAND_102;
  reg [31:0] _RAND_103;
  reg [31:0] _RAND_104;
  reg [31:0] _RAND_105;
  reg [31:0] _RAND_106;
  reg [31:0] _RAND_107;
  reg [31:0] _RAND_108;
  reg [31:0] _RAND_109;
  reg [31:0] _RAND_110;
  reg [31:0] _RAND_111;
  reg [31:0] _RAND_112;
  reg [31:0] _RAND_113;
  reg [31:0] _RAND_114;
  reg [31:0] _RAND_115;
  reg [31:0] _RAND_116;
  reg [31:0] _RAND_117;
  reg [31:0] _RAND_118;
  reg [31:0] _RAND_119;
  reg [31:0] _RAND_120;
  reg [31:0] _RAND_121;
  reg [31:0] _RAND_122;
  reg [31:0] _RAND_123;
  reg [31:0] _RAND_124;
  reg [31:0] _RAND_125;
  reg [31:0] _RAND_126;
  reg [31:0] _RAND_127;
  reg [31:0] _RAND_128;
  reg [31:0] _RAND_129;
  reg [31:0] _RAND_130;
  reg [31:0] _RAND_131;
  reg [31:0] _RAND_132;
  reg [31:0] _RAND_133;
  reg [31:0] _RAND_134;
  reg [31:0] _RAND_135;
  reg [31:0] _RAND_136;
  reg [31:0] _RAND_137;
  reg [31:0] _RAND_138;
  reg [31:0] _RAND_139;
  reg [31:0] _RAND_140;
  reg [31:0] _RAND_141;
  reg [31:0] _RAND_142;
  reg [31:0] _RAND_143;
  reg [31:0] _RAND_144;
  reg [31:0] _RAND_145;
  reg [31:0] _RAND_146;
  reg [31:0] _RAND_147;
  reg [31:0] _RAND_148;
  reg [31:0] _RAND_149;
  reg [31:0] _RAND_150;
  reg [31:0] _RAND_151;
  reg [31:0] _RAND_152;
  reg [31:0] _RAND_153;
  reg [31:0] _RAND_154;
  reg [31:0] _RAND_155;
  reg [31:0] _RAND_156;
  reg [31:0] _RAND_157;
  reg [31:0] _RAND_158;
  reg [31:0] _RAND_159;
  reg [31:0] _RAND_160;
  reg [31:0] _RAND_161;
  reg [31:0] _RAND_162;
  reg [31:0] _RAND_163;
  reg [31:0] _RAND_164;
  reg [31:0] _RAND_165;
  reg [31:0] _RAND_166;
  reg [31:0] _RAND_167;
  reg [31:0] _RAND_168;
  reg [31:0] _RAND_169;
  reg [31:0] _RAND_170;
  reg [31:0] _RAND_171;
  reg [31:0] _RAND_172;
  reg [31:0] _RAND_173;
  reg [31:0] _RAND_174;
  reg [31:0] _RAND_175;
  reg [31:0] _RAND_176;
  reg [31:0] _RAND_177;
  reg [31:0] _RAND_178;
  reg [31:0] _RAND_179;
  reg [31:0] _RAND_180;
  reg [31:0] _RAND_181;
  reg [31:0] _RAND_182;
  reg [31:0] _RAND_183;
  reg [31:0] _RAND_184;
  reg [31:0] _RAND_185;
  reg [31:0] _RAND_186;
  reg [31:0] _RAND_187;
  reg [31:0] _RAND_188;
  reg [31:0] _RAND_189;
  reg [31:0] _RAND_190;
  reg [31:0] _RAND_191;
  reg [31:0] _RAND_192;
  reg [31:0] _RAND_193;
  reg [31:0] _RAND_194;
  reg [31:0] _RAND_195;
  reg [31:0] _RAND_196;
  reg [31:0] _RAND_197;
  reg [31:0] _RAND_198;
  reg [31:0] _RAND_199;
  reg [31:0] _RAND_200;
  reg [31:0] _RAND_201;
  reg [31:0] _RAND_202;
  reg [31:0] _RAND_203;
  reg [31:0] _RAND_204;
  reg [31:0] _RAND_205;
  reg [31:0] _RAND_206;
`endif
  reg [19:0] phase;
  wire [20:0] _phase_T = phase + 20'h1;
  wire [19:0] _phase_T_1 = phase + 20'h1;
  wire [7:0] cosIdx = phase[19:12];
  wire  _cosQ16_T = cosIdx == 8'h0;
  wire  _cosQ16_T_1 = cosIdx == 8'h1;
  wire  _cosQ16_T_2 = cosIdx == 8'h2;
  wire  _cosQ16_T_3 = cosIdx == 8'h3;
  wire  _cosQ16_T_4 = cosIdx == 8'h4;
  wire  _cosQ16_T_5 = cosIdx == 8'h5;
  wire  _cosQ16_T_6 = cosIdx == 8'h6;
  wire  _cosQ16_T_7 = cosIdx == 8'h7;
  wire  _cosQ16_T_8 = cosIdx == 8'h8;
  wire  _cosQ16_T_9 = cosIdx == 8'h9;
  wire  _cosQ16_T_10 = cosIdx == 8'ha;
  wire  _cosQ16_T_11 = cosIdx == 8'hb;
  wire  _cosQ16_T_12 = cosIdx == 8'hc;
  wire  _cosQ16_T_13 = cosIdx == 8'hd;
  wire  _cosQ16_T_14 = cosIdx == 8'he;
  wire  _cosQ16_T_15 = cosIdx == 8'hf;
  wire  _cosQ16_T_16 = cosIdx == 8'h10;
  wire  _cosQ16_T_17 = cosIdx == 8'h11;
  wire  _cosQ16_T_18 = cosIdx == 8'h12;
  wire  _cosQ16_T_19 = cosIdx == 8'h13;
  wire  _cosQ16_T_20 = cosIdx == 8'h14;
  wire  _cosQ16_T_21 = cosIdx == 8'h15;
  wire  _cosQ16_T_22 = cosIdx == 8'h16;
  wire  _cosQ16_T_23 = cosIdx == 8'h17;
  wire  _cosQ16_T_24 = cosIdx == 8'h18;
  wire  _cosQ16_T_25 = cosIdx == 8'h19;
  wire  _cosQ16_T_26 = cosIdx == 8'h1a;
  wire  _cosQ16_T_27 = cosIdx == 8'h1b;
  wire  _cosQ16_T_28 = cosIdx == 8'h1c;
  wire  _cosQ16_T_29 = cosIdx == 8'h1d;
  wire  _cosQ16_T_30 = cosIdx == 8'h1e;
  wire  _cosQ16_T_31 = cosIdx == 8'h1f;
  wire  _cosQ16_T_32 = cosIdx == 8'h20;
  wire  _cosQ16_T_33 = cosIdx == 8'h21;
  wire  _cosQ16_T_34 = cosIdx == 8'h22;
  wire  _cosQ16_T_35 = cosIdx == 8'h23;
  wire  _cosQ16_T_36 = cosIdx == 8'h24;
  wire  _cosQ16_T_37 = cosIdx == 8'h25;
  wire  _cosQ16_T_38 = cosIdx == 8'h26;
  wire  _cosQ16_T_39 = cosIdx == 8'h27;
  wire  _cosQ16_T_40 = cosIdx == 8'h28;
  wire  _cosQ16_T_41 = cosIdx == 8'h29;
  wire  _cosQ16_T_42 = cosIdx == 8'h2a;
  wire  _cosQ16_T_43 = cosIdx == 8'h2b;
  wire  _cosQ16_T_44 = cosIdx == 8'h2c;
  wire  _cosQ16_T_45 = cosIdx == 8'h2d;
  wire  _cosQ16_T_46 = cosIdx == 8'h2e;
  wire  _cosQ16_T_47 = cosIdx == 8'h2f;
  wire  _cosQ16_T_48 = cosIdx == 8'h30;
  wire  _cosQ16_T_49 = cosIdx == 8'h31;
  wire  _cosQ16_T_50 = cosIdx == 8'h32;
  wire  _cosQ16_T_51 = cosIdx == 8'h33;
  wire  _cosQ16_T_52 = cosIdx == 8'h34;
  wire  _cosQ16_T_53 = cosIdx == 8'h35;
  wire  _cosQ16_T_54 = cosIdx == 8'h36;
  wire  _cosQ16_T_55 = cosIdx == 8'h37;
  wire  _cosQ16_T_56 = cosIdx == 8'h38;
  wire  _cosQ16_T_57 = cosIdx == 8'h39;
  wire  _cosQ16_T_58 = cosIdx == 8'h3a;
  wire  _cosQ16_T_59 = cosIdx == 8'h3b;
  wire  _cosQ16_T_60 = cosIdx == 8'h3c;
  wire  _cosQ16_T_61 = cosIdx == 8'h3d;
  wire  _cosQ16_T_62 = cosIdx == 8'h3e;
  wire  _cosQ16_T_63 = cosIdx == 8'h3f;
  wire  _cosQ16_T_64 = cosIdx == 8'h40;
  wire  _cosQ16_T_65 = cosIdx == 8'h41;
  wire  _cosQ16_T_66 = cosIdx == 8'h42;
  wire  _cosQ16_T_67 = cosIdx == 8'h43;
  wire  _cosQ16_T_68 = cosIdx == 8'h44;
  wire  _cosQ16_T_69 = cosIdx == 8'h45;
  wire  _cosQ16_T_70 = cosIdx == 8'h46;
  wire  _cosQ16_T_71 = cosIdx == 8'h47;
  wire  _cosQ16_T_72 = cosIdx == 8'h48;
  wire  _cosQ16_T_73 = cosIdx == 8'h49;
  wire  _cosQ16_T_74 = cosIdx == 8'h4a;
  wire  _cosQ16_T_75 = cosIdx == 8'h4b;
  wire  _cosQ16_T_76 = cosIdx == 8'h4c;
  wire  _cosQ16_T_77 = cosIdx == 8'h4d;
  wire  _cosQ16_T_78 = cosIdx == 8'h4e;
  wire  _cosQ16_T_79 = cosIdx == 8'h4f;
  wire  _cosQ16_T_80 = cosIdx == 8'h50;
  wire  _cosQ16_T_81 = cosIdx == 8'h51;
  wire  _cosQ16_T_82 = cosIdx == 8'h52;
  wire  _cosQ16_T_83 = cosIdx == 8'h53;
  wire  _cosQ16_T_84 = cosIdx == 8'h54;
  wire  _cosQ16_T_85 = cosIdx == 8'h55;
  wire  _cosQ16_T_86 = cosIdx == 8'h56;
  wire  _cosQ16_T_87 = cosIdx == 8'h57;
  wire  _cosQ16_T_88 = cosIdx == 8'h58;
  wire  _cosQ16_T_89 = cosIdx == 8'h59;
  wire  _cosQ16_T_90 = cosIdx == 8'h5a;
  wire  _cosQ16_T_91 = cosIdx == 8'h5b;
  wire  _cosQ16_T_92 = cosIdx == 8'h5c;
  wire  _cosQ16_T_93 = cosIdx == 8'h5d;
  wire  _cosQ16_T_94 = cosIdx == 8'h5e;
  wire  _cosQ16_T_95 = cosIdx == 8'h5f;
  wire  _cosQ16_T_96 = cosIdx == 8'h60;
  wire  _cosQ16_T_97 = cosIdx == 8'h61;
  wire  _cosQ16_T_98 = cosIdx == 8'h62;
  wire  _cosQ16_T_99 = cosIdx == 8'h63;
  wire  _cosQ16_T_100 = cosIdx == 8'h64;
  wire  _cosQ16_T_101 = cosIdx == 8'h65;
  wire  _cosQ16_T_102 = cosIdx == 8'h66;
  wire  _cosQ16_T_103 = cosIdx == 8'h67;
  wire  _cosQ16_T_104 = cosIdx == 8'h68;
  wire  _cosQ16_T_105 = cosIdx == 8'h69;
  wire  _cosQ16_T_106 = cosIdx == 8'h6a;
  wire  _cosQ16_T_107 = cosIdx == 8'h6b;
  wire  _cosQ16_T_108 = cosIdx == 8'h6c;
  wire  _cosQ16_T_109 = cosIdx == 8'h6d;
  wire  _cosQ16_T_110 = cosIdx == 8'h6e;
  wire  _cosQ16_T_111 = cosIdx == 8'h6f;
  wire  _cosQ16_T_112 = cosIdx == 8'h70;
  wire  _cosQ16_T_113 = cosIdx == 8'h71;
  wire  _cosQ16_T_114 = cosIdx == 8'h72;
  wire  _cosQ16_T_115 = cosIdx == 8'h73;
  wire  _cosQ16_T_116 = cosIdx == 8'h74;
  wire  _cosQ16_T_117 = cosIdx == 8'h75;
  wire  _cosQ16_T_118 = cosIdx == 8'h76;
  wire  _cosQ16_T_119 = cosIdx == 8'h77;
  wire  _cosQ16_T_120 = cosIdx == 8'h78;
  wire  _cosQ16_T_121 = cosIdx == 8'h79;
  wire  _cosQ16_T_122 = cosIdx == 8'h7a;
  wire  _cosQ16_T_123 = cosIdx == 8'h7b;
  wire  _cosQ16_T_124 = cosIdx == 8'h7c;
  wire  _cosQ16_T_125 = cosIdx == 8'h7d;
  wire  _cosQ16_T_126 = cosIdx == 8'h7e;
  wire  _cosQ16_T_127 = cosIdx == 8'h7f;
  wire  _cosQ16_T_128 = cosIdx == 8'h80;
  wire  _cosQ16_T_129 = cosIdx == 8'h81;
  wire  _cosQ16_T_130 = cosIdx == 8'h82;
  wire  _cosQ16_T_131 = cosIdx == 8'h83;
  wire  _cosQ16_T_132 = cosIdx == 8'h84;
  wire  _cosQ16_T_133 = cosIdx == 8'h85;
  wire  _cosQ16_T_134 = cosIdx == 8'h86;
  wire  _cosQ16_T_135 = cosIdx == 8'h87;
  wire  _cosQ16_T_136 = cosIdx == 8'h88;
  wire  _cosQ16_T_137 = cosIdx == 8'h89;
  wire  _cosQ16_T_138 = cosIdx == 8'h8a;
  wire  _cosQ16_T_139 = cosIdx == 8'h8b;
  wire  _cosQ16_T_140 = cosIdx == 8'h8c;
  wire  _cosQ16_T_141 = cosIdx == 8'h8d;
  wire  _cosQ16_T_142 = cosIdx == 8'h8e;
  wire  _cosQ16_T_143 = cosIdx == 8'h8f;
  wire  _cosQ16_T_144 = cosIdx == 8'h90;
  wire  _cosQ16_T_145 = cosIdx == 8'h91;
  wire  _cosQ16_T_146 = cosIdx == 8'h92;
  wire  _cosQ16_T_147 = cosIdx == 8'h93;
  wire  _cosQ16_T_148 = cosIdx == 8'h94;
  wire  _cosQ16_T_149 = cosIdx == 8'h95;
  wire  _cosQ16_T_150 = cosIdx == 8'h96;
  wire  _cosQ16_T_151 = cosIdx == 8'h97;
  wire  _cosQ16_T_152 = cosIdx == 8'h98;
  wire  _cosQ16_T_153 = cosIdx == 8'h99;
  wire  _cosQ16_T_154 = cosIdx == 8'h9a;
  wire  _cosQ16_T_155 = cosIdx == 8'h9b;
  wire  _cosQ16_T_156 = cosIdx == 8'h9c;
  wire  _cosQ16_T_157 = cosIdx == 8'h9d;
  wire  _cosQ16_T_158 = cosIdx == 8'h9e;
  wire  _cosQ16_T_159 = cosIdx == 8'h9f;
  wire  _cosQ16_T_160 = cosIdx == 8'ha0;
  wire  _cosQ16_T_161 = cosIdx == 8'ha1;
  wire  _cosQ16_T_162 = cosIdx == 8'ha2;
  wire  _cosQ16_T_163 = cosIdx == 8'ha3;
  wire  _cosQ16_T_164 = cosIdx == 8'ha4;
  wire  _cosQ16_T_165 = cosIdx == 8'ha5;
  wire  _cosQ16_T_166 = cosIdx == 8'ha6;
  wire  _cosQ16_T_167 = cosIdx == 8'ha7;
  wire  _cosQ16_T_168 = cosIdx == 8'ha8;
  wire  _cosQ16_T_169 = cosIdx == 8'ha9;
  wire  _cosQ16_T_170 = cosIdx == 8'haa;
  wire  _cosQ16_T_171 = cosIdx == 8'hab;
  wire  _cosQ16_T_172 = cosIdx == 8'hac;
  wire  _cosQ16_T_173 = cosIdx == 8'had;
  wire  _cosQ16_T_174 = cosIdx == 8'hae;
  wire  _cosQ16_T_175 = cosIdx == 8'haf;
  wire  _cosQ16_T_176 = cosIdx == 8'hb0;
  wire  _cosQ16_T_177 = cosIdx == 8'hb1;
  wire  _cosQ16_T_178 = cosIdx == 8'hb2;
  wire  _cosQ16_T_179 = cosIdx == 8'hb3;
  wire  _cosQ16_T_180 = cosIdx == 8'hb4;
  wire  _cosQ16_T_181 = cosIdx == 8'hb5;
  wire  _cosQ16_T_182 = cosIdx == 8'hb6;
  wire  _cosQ16_T_183 = cosIdx == 8'hb7;
  wire  _cosQ16_T_184 = cosIdx == 8'hb8;
  wire  _cosQ16_T_185 = cosIdx == 8'hb9;
  wire  _cosQ16_T_186 = cosIdx == 8'hba;
  wire  _cosQ16_T_187 = cosIdx == 8'hbb;
  wire  _cosQ16_T_188 = cosIdx == 8'hbc;
  wire  _cosQ16_T_189 = cosIdx == 8'hbd;
  wire  _cosQ16_T_190 = cosIdx == 8'hbe;
  wire  _cosQ16_T_191 = cosIdx == 8'hbf;
  wire  _cosQ16_T_192 = cosIdx == 8'hc0;
  wire  _cosQ16_T_193 = cosIdx == 8'hc1;
  wire  _cosQ16_T_194 = cosIdx == 8'hc2;
  wire  _cosQ16_T_195 = cosIdx == 8'hc3;
  wire  _cosQ16_T_196 = cosIdx == 8'hc4;
  wire  _cosQ16_T_197 = cosIdx == 8'hc5;
  wire  _cosQ16_T_198 = cosIdx == 8'hc6;
  wire  _cosQ16_T_199 = cosIdx == 8'hc7;
  wire  _cosQ16_T_200 = cosIdx == 8'hc8;
  wire  _cosQ16_T_201 = cosIdx == 8'hc9;
  wire  _cosQ16_T_202 = cosIdx == 8'hca;
  wire  _cosQ16_T_203 = cosIdx == 8'hcb;
  wire  _cosQ16_T_204 = cosIdx == 8'hcc;
  wire  _cosQ16_T_205 = cosIdx == 8'hcd;
  wire  _cosQ16_T_206 = cosIdx == 8'hce;
  wire  _cosQ16_T_207 = cosIdx == 8'hcf;
  wire  _cosQ16_T_208 = cosIdx == 8'hd0;
  wire  _cosQ16_T_209 = cosIdx == 8'hd1;
  wire  _cosQ16_T_210 = cosIdx == 8'hd2;
  wire  _cosQ16_T_211 = cosIdx == 8'hd3;
  wire  _cosQ16_T_212 = cosIdx == 8'hd4;
  wire  _cosQ16_T_213 = cosIdx == 8'hd5;
  wire  _cosQ16_T_214 = cosIdx == 8'hd6;
  wire  _cosQ16_T_215 = cosIdx == 8'hd7;
  wire  _cosQ16_T_216 = cosIdx == 8'hd8;
  wire  _cosQ16_T_217 = cosIdx == 8'hd9;
  wire  _cosQ16_T_218 = cosIdx == 8'hda;
  wire  _cosQ16_T_219 = cosIdx == 8'hdb;
  wire  _cosQ16_T_220 = cosIdx == 8'hdc;
  wire  _cosQ16_T_221 = cosIdx == 8'hdd;
  wire  _cosQ16_T_222 = cosIdx == 8'hde;
  wire  _cosQ16_T_223 = cosIdx == 8'hdf;
  wire  _cosQ16_T_224 = cosIdx == 8'he0;
  wire  _cosQ16_T_225 = cosIdx == 8'he1;
  wire  _cosQ16_T_226 = cosIdx == 8'he2;
  wire  _cosQ16_T_227 = cosIdx == 8'he3;
  wire  _cosQ16_T_228 = cosIdx == 8'he4;
  wire  _cosQ16_T_229 = cosIdx == 8'he5;
  wire  _cosQ16_T_230 = cosIdx == 8'he6;
  wire  _cosQ16_T_231 = cosIdx == 8'he7;
  wire  _cosQ16_T_232 = cosIdx == 8'he8;
  wire  _cosQ16_T_233 = cosIdx == 8'he9;
  wire  _cosQ16_T_234 = cosIdx == 8'hea;
  wire  _cosQ16_T_235 = cosIdx == 8'heb;
  wire  _cosQ16_T_236 = cosIdx == 8'hec;
  wire  _cosQ16_T_237 = cosIdx == 8'hed;
  wire  _cosQ16_T_238 = cosIdx == 8'hee;
  wire  _cosQ16_T_239 = cosIdx == 8'hef;
  wire  _cosQ16_T_240 = cosIdx == 8'hf0;
  wire  _cosQ16_T_241 = cosIdx == 8'hf1;
  wire  _cosQ16_T_242 = cosIdx == 8'hf2;
  wire  _cosQ16_T_243 = cosIdx == 8'hf3;
  wire  _cosQ16_T_244 = cosIdx == 8'hf4;
  wire  _cosQ16_T_245 = cosIdx == 8'hf5;
  wire  _cosQ16_T_246 = cosIdx == 8'hf6;
  wire  _cosQ16_T_247 = cosIdx == 8'hf7;
  wire  _cosQ16_T_248 = cosIdx == 8'hf8;
  wire  _cosQ16_T_249 = cosIdx == 8'hf9;
  wire  _cosQ16_T_250 = cosIdx == 8'hfa;
  wire  _cosQ16_T_251 = cosIdx == 8'hfb;
  wire  _cosQ16_T_252 = cosIdx == 8'hfc;
  wire  _cosQ16_T_253 = cosIdx == 8'hfd;
  wire  _cosQ16_T_254 = cosIdx == 8'hfe;
  wire  _cosQ16_T_255 = cosIdx == 8'hff;
  wire [15:0] _cosQ16_T_256 = 16'h7fff;
  wire [15:0] _cosQ16_T_257 = 16'sh7fff;
  wire [15:0] _cosQ16_T_258 = 16'h7ff5;
  wire [15:0] _cosQ16_T_259 = 16'sh7ff5;
  wire [15:0] _cosQ16_T_260 = 16'h7fd8;
  wire [15:0] _cosQ16_T_261 = 16'sh7fd8;
  wire [15:0] _cosQ16_T_262 = 16'h7fa6;
  wire [15:0] _cosQ16_T_263 = 16'sh7fa6;
  wire [15:0] _cosQ16_T_264 = 16'h7f61;
  wire [15:0] _cosQ16_T_265 = 16'sh7f61;
  wire [15:0] _cosQ16_T_266 = 16'h7f09;
  wire [15:0] _cosQ16_T_267 = 16'sh7f09;
  wire [15:0] _cosQ16_T_268 = 16'h7e9c;
  wire [15:0] _cosQ16_T_269 = 16'sh7e9c;
  wire [15:0] _cosQ16_T_270 = 16'h7e1d;
  wire [15:0] _cosQ16_T_271 = 16'sh7e1d;
  wire [15:0] _cosQ16_T_272 = 16'h7d89;
  wire [15:0] _cosQ16_T_273 = 16'sh7d89;
  wire [15:0] _cosQ16_T_274 = 16'h7ce3;
  wire [15:0] _cosQ16_T_275 = 16'sh7ce3;
  wire [15:0] _cosQ16_T_276 = 16'h7c29;
  wire [15:0] _cosQ16_T_277 = 16'sh7c29;
  wire [15:0] _cosQ16_T_278 = 16'h7b5c;
  wire [15:0] _cosQ16_T_279 = 16'sh7b5c;
  wire [15:0] _cosQ16_T_280 = 16'h7a7c;
  wire [15:0] _cosQ16_T_281 = 16'sh7a7c;
  wire [15:0] _cosQ16_T_282 = 16'h7989;
  wire [15:0] _cosQ16_T_283 = 16'sh7989;
  wire [15:0] _cosQ16_T_284 = 16'h7884;
  wire [15:0] _cosQ16_T_285 = 16'sh7884;
  wire [15:0] _cosQ16_T_286 = 16'h776b;
  wire [15:0] _cosQ16_T_287 = 16'sh776b;
  wire [15:0] _cosQ16_T_288 = 16'h7641;
  wire [15:0] _cosQ16_T_289 = 16'sh7641;
  wire [15:0] _cosQ16_T_290 = 16'h7504;
  wire [15:0] _cosQ16_T_291 = 16'sh7504;
  wire [15:0] _cosQ16_T_292 = 16'h73b5;
  wire [15:0] _cosQ16_T_293 = 16'sh73b5;
  wire [15:0] _cosQ16_T_294 = 16'h7254;
  wire [15:0] _cosQ16_T_295 = 16'sh7254;
  wire [15:0] _cosQ16_T_296 = 16'h70e2;
  wire [15:0] _cosQ16_T_297 = 16'sh70e2;
  wire [15:0] _cosQ16_T_298 = 16'h6f5e;
  wire [15:0] _cosQ16_T_299 = 16'sh6f5e;
  wire [15:0] _cosQ16_T_300 = 16'h6dc9;
  wire [15:0] _cosQ16_T_301 = 16'sh6dc9;
  wire [15:0] _cosQ16_T_302 = 16'h6c23;
  wire [15:0] _cosQ16_T_303 = 16'sh6c23;
  wire [15:0] _cosQ16_T_304 = 16'h6a6d;
  wire [15:0] _cosQ16_T_305 = 16'sh6a6d;
  wire [15:0] _cosQ16_T_306 = 16'h68a6;
  wire [15:0] _cosQ16_T_307 = 16'sh68a6;
  wire [15:0] _cosQ16_T_308 = 16'h66cf;
  wire [15:0] _cosQ16_T_309 = 16'sh66cf;
  wire [15:0] _cosQ16_T_310 = 16'h64e8;
  wire [15:0] _cosQ16_T_311 = 16'sh64e8;
  wire [15:0] _cosQ16_T_312 = 16'h62f1;
  wire [15:0] _cosQ16_T_313 = 16'sh62f1;
  wire [15:0] _cosQ16_T_314 = 16'h60eb;
  wire [15:0] _cosQ16_T_315 = 16'sh60eb;
  wire [15:0] _cosQ16_T_316 = 16'h5ed7;
  wire [15:0] _cosQ16_T_317 = 16'sh5ed7;
  wire [15:0] _cosQ16_T_318 = 16'h5cb3;
  wire [15:0] _cosQ16_T_319 = 16'sh5cb3;
  wire [15:0] _cosQ16_T_320 = 16'h5a82;
  wire [15:0] _cosQ16_T_321 = 16'sh5a82;
  wire [15:0] _cosQ16_T_322 = 16'h5842;
  wire [15:0] _cosQ16_T_323 = 16'sh5842;
  wire [15:0] _cosQ16_T_324 = 16'h55f5;
  wire [15:0] _cosQ16_T_325 = 16'sh55f5;
  wire [15:0] _cosQ16_T_326 = 16'h539b;
  wire [15:0] _cosQ16_T_327 = 16'sh539b;
  wire [15:0] _cosQ16_T_328 = 16'h5133;
  wire [15:0] _cosQ16_T_329 = 16'sh5133;
  wire [15:0] _cosQ16_T_330 = 16'h4ebf;
  wire [15:0] _cosQ16_T_331 = 16'sh4ebf;
  wire [15:0] _cosQ16_T_332 = 16'h4c3f;
  wire [15:0] _cosQ16_T_333 = 16'sh4c3f;
  wire [15:0] _cosQ16_T_334 = 16'h49b4;
  wire [15:0] _cosQ16_T_335 = 16'sh49b4;
  wire [15:0] _cosQ16_T_336 = 16'h471c;
  wire [15:0] _cosQ16_T_337 = 16'sh471c;
  wire [15:0] _cosQ16_T_338 = 16'h447a;
  wire [15:0] _cosQ16_T_339 = 16'sh447a;
  wire [15:0] _cosQ16_T_340 = 16'h41ce;
  wire [15:0] _cosQ16_T_341 = 16'sh41ce;
  wire [15:0] _cosQ16_T_342 = 16'h3f17;
  wire [15:0] _cosQ16_T_343 = 16'sh3f17;
  wire [15:0] _cosQ16_T_344 = 16'h3c56;
  wire [15:0] _cosQ16_T_345 = 16'sh3c56;
  wire [15:0] _cosQ16_T_346 = 16'h398c;
  wire [15:0] _cosQ16_T_347 = 16'sh398c;
  wire [15:0] _cosQ16_T_348 = 16'h36ba;
  wire [15:0] _cosQ16_T_349 = 16'sh36ba;
  wire [15:0] _cosQ16_T_350 = 16'h33df;
  wire [15:0] _cosQ16_T_351 = 16'sh33df;
  wire [15:0] _cosQ16_T_352 = 16'h30fb;
  wire [15:0] _cosQ16_T_353 = 16'sh30fb;
  wire [15:0] _cosQ16_T_354 = 16'h2e11;
  wire [15:0] _cosQ16_T_355 = 16'sh2e11;
  wire [15:0] _cosQ16_T_356 = 16'h2b1f;
  wire [15:0] _cosQ16_T_357 = 16'sh2b1f;
  wire [15:0] _cosQ16_T_358 = 16'h2826;
  wire [15:0] _cosQ16_T_359 = 16'sh2826;
  wire [15:0] _cosQ16_T_360 = 16'h2528;
  wire [15:0] _cosQ16_T_361 = 16'sh2528;
  wire [15:0] _cosQ16_T_362 = 16'h2223;
  wire [15:0] _cosQ16_T_363 = 16'sh2223;
  wire [15:0] _cosQ16_T_364 = 16'h1f1a;
  wire [15:0] _cosQ16_T_365 = 16'sh1f1a;
  wire [15:0] _cosQ16_T_366 = 16'h1c0b;
  wire [15:0] _cosQ16_T_367 = 16'sh1c0b;
  wire [15:0] _cosQ16_T_368 = 16'h18f9;
  wire [15:0] _cosQ16_T_369 = 16'sh18f9;
  wire [15:0] _cosQ16_T_370 = 16'h15e2;
  wire [15:0] _cosQ16_T_371 = 16'sh15e2;
  wire [15:0] _cosQ16_T_372 = 16'h12c8;
  wire [15:0] _cosQ16_T_373 = 16'sh12c8;
  wire [15:0] _cosQ16_T_374 = 16'hfab;
  wire [15:0] _cosQ16_T_375 = 16'shfab;
  wire [15:0] _cosQ16_T_376 = 16'hc8c;
  wire [15:0] _cosQ16_T_377 = 16'shc8c;
  wire [15:0] _cosQ16_T_378 = 16'h96a;
  wire [15:0] _cosQ16_T_379 = 16'sh96a;
  wire [15:0] _cosQ16_T_380 = 16'h648;
  wire [15:0] _cosQ16_T_381 = 16'sh648;
  wire [15:0] _cosQ16_T_382 = 16'h324;
  wire [15:0] _cosQ16_T_383 = 16'sh324;
  wire [15:0] _cosQ16_T_384 = 16'h0;
  wire [15:0] _cosQ16_T_385 = 16'sh0;
  wire [15:0] _cosQ16_T_386 = 16'hfcdc;
  wire [15:0] _cosQ16_T_387 = -16'sh324;
  wire [15:0] _cosQ16_T_388 = 16'hf9b8;
  wire [15:0] _cosQ16_T_389 = -16'sh648;
  wire [15:0] _cosQ16_T_390 = 16'hf696;
  wire [15:0] _cosQ16_T_391 = -16'sh96a;
  wire [15:0] _cosQ16_T_392 = 16'hf374;
  wire [15:0] _cosQ16_T_393 = -16'shc8c;
  wire [15:0] _cosQ16_T_394 = 16'hf055;
  wire [15:0] _cosQ16_T_395 = -16'shfab;
  wire [15:0] _cosQ16_T_396 = 16'hed38;
  wire [15:0] _cosQ16_T_397 = -16'sh12c8;
  wire [15:0] _cosQ16_T_398 = 16'hea1e;
  wire [15:0] _cosQ16_T_399 = -16'sh15e2;
  wire [15:0] _cosQ16_T_400 = 16'he707;
  wire [15:0] _cosQ16_T_401 = -16'sh18f9;
  wire [15:0] _cosQ16_T_402 = 16'he3f5;
  wire [15:0] _cosQ16_T_403 = -16'sh1c0b;
  wire [15:0] _cosQ16_T_404 = 16'he0e6;
  wire [15:0] _cosQ16_T_405 = -16'sh1f1a;
  wire [15:0] _cosQ16_T_406 = 16'hdddd;
  wire [15:0] _cosQ16_T_407 = -16'sh2223;
  wire [15:0] _cosQ16_T_408 = 16'hdad8;
  wire [15:0] _cosQ16_T_409 = -16'sh2528;
  wire [15:0] _cosQ16_T_410 = 16'hd7da;
  wire [15:0] _cosQ16_T_411 = -16'sh2826;
  wire [15:0] _cosQ16_T_412 = 16'hd4e1;
  wire [15:0] _cosQ16_T_413 = -16'sh2b1f;
  wire [15:0] _cosQ16_T_414 = 16'hd1ef;
  wire [15:0] _cosQ16_T_415 = -16'sh2e11;
  wire [15:0] _cosQ16_T_416 = 16'hcf05;
  wire [15:0] _cosQ16_T_417 = -16'sh30fb;
  wire [15:0] _cosQ16_T_418 = 16'hcc21;
  wire [15:0] _cosQ16_T_419 = -16'sh33df;
  wire [15:0] _cosQ16_T_420 = 16'hc946;
  wire [15:0] _cosQ16_T_421 = -16'sh36ba;
  wire [15:0] _cosQ16_T_422 = 16'hc674;
  wire [15:0] _cosQ16_T_423 = -16'sh398c;
  wire [15:0] _cosQ16_T_424 = 16'hc3aa;
  wire [15:0] _cosQ16_T_425 = -16'sh3c56;
  wire [15:0] _cosQ16_T_426 = 16'hc0e9;
  wire [15:0] _cosQ16_T_427 = -16'sh3f17;
  wire [15:0] _cosQ16_T_428 = 16'hbe32;
  wire [15:0] _cosQ16_T_429 = -16'sh41ce;
  wire [15:0] _cosQ16_T_430 = 16'hbb86;
  wire [15:0] _cosQ16_T_431 = -16'sh447a;
  wire [15:0] _cosQ16_T_432 = 16'hb8e4;
  wire [15:0] _cosQ16_T_433 = -16'sh471c;
  wire [15:0] _cosQ16_T_434 = 16'hb64c;
  wire [15:0] _cosQ16_T_435 = -16'sh49b4;
  wire [15:0] _cosQ16_T_436 = 16'hb3c1;
  wire [15:0] _cosQ16_T_437 = -16'sh4c3f;
  wire [15:0] _cosQ16_T_438 = 16'hb141;
  wire [15:0] _cosQ16_T_439 = -16'sh4ebf;
  wire [15:0] _cosQ16_T_440 = 16'haecd;
  wire [15:0] _cosQ16_T_441 = -16'sh5133;
  wire [15:0] _cosQ16_T_442 = 16'hac65;
  wire [15:0] _cosQ16_T_443 = -16'sh539b;
  wire [15:0] _cosQ16_T_444 = 16'haa0b;
  wire [15:0] _cosQ16_T_445 = -16'sh55f5;
  wire [15:0] _cosQ16_T_446 = 16'ha7be;
  wire [15:0] _cosQ16_T_447 = -16'sh5842;
  wire [15:0] _cosQ16_T_448 = 16'ha57e;
  wire [15:0] _cosQ16_T_449 = -16'sh5a82;
  wire [15:0] _cosQ16_T_450 = 16'ha34d;
  wire [15:0] _cosQ16_T_451 = -16'sh5cb3;
  wire [15:0] _cosQ16_T_452 = 16'ha129;
  wire [15:0] _cosQ16_T_453 = -16'sh5ed7;
  wire [15:0] _cosQ16_T_454 = 16'h9f15;
  wire [15:0] _cosQ16_T_455 = -16'sh60eb;
  wire [15:0] _cosQ16_T_456 = 16'h9d0f;
  wire [15:0] _cosQ16_T_457 = -16'sh62f1;
  wire [15:0] _cosQ16_T_458 = 16'h9b18;
  wire [15:0] _cosQ16_T_459 = -16'sh64e8;
  wire [15:0] _cosQ16_T_460 = 16'h9931;
  wire [15:0] _cosQ16_T_461 = -16'sh66cf;
  wire [15:0] _cosQ16_T_462 = 16'h975a;
  wire [15:0] _cosQ16_T_463 = -16'sh68a6;
  wire [15:0] _cosQ16_T_464 = 16'h9593;
  wire [15:0] _cosQ16_T_465 = -16'sh6a6d;
  wire [15:0] _cosQ16_T_466 = 16'h93dd;
  wire [15:0] _cosQ16_T_467 = -16'sh6c23;
  wire [15:0] _cosQ16_T_468 = 16'h9237;
  wire [15:0] _cosQ16_T_469 = -16'sh6dc9;
  wire [15:0] _cosQ16_T_470 = 16'h90a2;
  wire [15:0] _cosQ16_T_471 = -16'sh6f5e;
  wire [15:0] _cosQ16_T_472 = 16'h8f1e;
  wire [15:0] _cosQ16_T_473 = -16'sh70e2;
  wire [15:0] _cosQ16_T_474 = 16'h8dac;
  wire [15:0] _cosQ16_T_475 = -16'sh7254;
  wire [15:0] _cosQ16_T_476 = 16'h8c4b;
  wire [15:0] _cosQ16_T_477 = -16'sh73b5;
  wire [15:0] _cosQ16_T_478 = 16'h8afc;
  wire [15:0] _cosQ16_T_479 = -16'sh7504;
  wire [15:0] _cosQ16_T_480 = 16'h89bf;
  wire [15:0] _cosQ16_T_481 = -16'sh7641;
  wire [15:0] _cosQ16_T_482 = 16'h8895;
  wire [15:0] _cosQ16_T_483 = -16'sh776b;
  wire [15:0] _cosQ16_T_484 = 16'h877c;
  wire [15:0] _cosQ16_T_485 = -16'sh7884;
  wire [15:0] _cosQ16_T_486 = 16'h8677;
  wire [15:0] _cosQ16_T_487 = -16'sh7989;
  wire [15:0] _cosQ16_T_488 = 16'h8584;
  wire [15:0] _cosQ16_T_489 = -16'sh7a7c;
  wire [15:0] _cosQ16_T_490 = 16'h84a4;
  wire [15:0] _cosQ16_T_491 = -16'sh7b5c;
  wire [15:0] _cosQ16_T_492 = 16'h83d7;
  wire [15:0] _cosQ16_T_493 = -16'sh7c29;
  wire [15:0] _cosQ16_T_494 = 16'h831d;
  wire [15:0] _cosQ16_T_495 = -16'sh7ce3;
  wire [15:0] _cosQ16_T_496 = 16'h8277;
  wire [15:0] _cosQ16_T_497 = -16'sh7d89;
  wire [15:0] _cosQ16_T_498 = 16'h81e3;
  wire [15:0] _cosQ16_T_499 = -16'sh7e1d;
  wire [15:0] _cosQ16_T_500 = 16'h8164;
  wire [15:0] _cosQ16_T_501 = -16'sh7e9c;
  wire [15:0] _cosQ16_T_502 = 16'h80f7;
  wire [15:0] _cosQ16_T_503 = -16'sh7f09;
  wire [15:0] _cosQ16_T_504 = 16'h809f;
  wire [15:0] _cosQ16_T_505 = -16'sh7f61;
  wire [15:0] _cosQ16_T_506 = 16'h805a;
  wire [15:0] _cosQ16_T_507 = -16'sh7fa6;
  wire [15:0] _cosQ16_T_508 = 16'h8028;
  wire [15:0] _cosQ16_T_509 = -16'sh7fd8;
  wire [15:0] _cosQ16_T_510 = 16'h800b;
  wire [15:0] _cosQ16_T_511 = -16'sh7ff5;
  wire [15:0] _cosQ16_T_512 = 16'h8001;
  wire [15:0] _cosQ16_T_513 = -16'sh7fff;
  wire [15:0] _cosQ16_T_514 = 16'h800b;
  wire [15:0] _cosQ16_T_515 = -16'sh7ff5;
  wire [15:0] _cosQ16_T_516 = 16'h8028;
  wire [15:0] _cosQ16_T_517 = -16'sh7fd8;
  wire [15:0] _cosQ16_T_518 = 16'h805a;
  wire [15:0] _cosQ16_T_519 = -16'sh7fa6;
  wire [15:0] _cosQ16_T_520 = 16'h809f;
  wire [15:0] _cosQ16_T_521 = -16'sh7f61;
  wire [15:0] _cosQ16_T_522 = 16'h80f7;
  wire [15:0] _cosQ16_T_523 = -16'sh7f09;
  wire [15:0] _cosQ16_T_524 = 16'h8164;
  wire [15:0] _cosQ16_T_525 = -16'sh7e9c;
  wire [15:0] _cosQ16_T_526 = 16'h81e3;
  wire [15:0] _cosQ16_T_527 = -16'sh7e1d;
  wire [15:0] _cosQ16_T_528 = 16'h8277;
  wire [15:0] _cosQ16_T_529 = -16'sh7d89;
  wire [15:0] _cosQ16_T_530 = 16'h831d;
  wire [15:0] _cosQ16_T_531 = -16'sh7ce3;
  wire [15:0] _cosQ16_T_532 = 16'h83d7;
  wire [15:0] _cosQ16_T_533 = -16'sh7c29;
  wire [15:0] _cosQ16_T_534 = 16'h84a4;
  wire [15:0] _cosQ16_T_535 = -16'sh7b5c;
  wire [15:0] _cosQ16_T_536 = 16'h8584;
  wire [15:0] _cosQ16_T_537 = -16'sh7a7c;
  wire [15:0] _cosQ16_T_538 = 16'h8677;
  wire [15:0] _cosQ16_T_539 = -16'sh7989;
  wire [15:0] _cosQ16_T_540 = 16'h877c;
  wire [15:0] _cosQ16_T_541 = -16'sh7884;
  wire [15:0] _cosQ16_T_542 = 16'h8895;
  wire [15:0] _cosQ16_T_543 = -16'sh776b;
  wire [15:0] _cosQ16_T_544 = 16'h89bf;
  wire [15:0] _cosQ16_T_545 = -16'sh7641;
  wire [15:0] _cosQ16_T_546 = 16'h8afc;
  wire [15:0] _cosQ16_T_547 = -16'sh7504;
  wire [15:0] _cosQ16_T_548 = 16'h8c4b;
  wire [15:0] _cosQ16_T_549 = -16'sh73b5;
  wire [15:0] _cosQ16_T_550 = 16'h8dac;
  wire [15:0] _cosQ16_T_551 = -16'sh7254;
  wire [15:0] _cosQ16_T_552 = 16'h8f1e;
  wire [15:0] _cosQ16_T_553 = -16'sh70e2;
  wire [15:0] _cosQ16_T_554 = 16'h90a2;
  wire [15:0] _cosQ16_T_555 = -16'sh6f5e;
  wire [15:0] _cosQ16_T_556 = 16'h9237;
  wire [15:0] _cosQ16_T_557 = -16'sh6dc9;
  wire [15:0] _cosQ16_T_558 = 16'h93dd;
  wire [15:0] _cosQ16_T_559 = -16'sh6c23;
  wire [15:0] _cosQ16_T_560 = 16'h9593;
  wire [15:0] _cosQ16_T_561 = -16'sh6a6d;
  wire [15:0] _cosQ16_T_562 = 16'h975a;
  wire [15:0] _cosQ16_T_563 = -16'sh68a6;
  wire [15:0] _cosQ16_T_564 = 16'h9931;
  wire [15:0] _cosQ16_T_565 = -16'sh66cf;
  wire [15:0] _cosQ16_T_566 = 16'h9b18;
  wire [15:0] _cosQ16_T_567 = -16'sh64e8;
  wire [15:0] _cosQ16_T_568 = 16'h9d0f;
  wire [15:0] _cosQ16_T_569 = -16'sh62f1;
  wire [15:0] _cosQ16_T_570 = 16'h9f15;
  wire [15:0] _cosQ16_T_571 = -16'sh60eb;
  wire [15:0] _cosQ16_T_572 = 16'ha129;
  wire [15:0] _cosQ16_T_573 = -16'sh5ed7;
  wire [15:0] _cosQ16_T_574 = 16'ha34d;
  wire [15:0] _cosQ16_T_575 = -16'sh5cb3;
  wire [15:0] _cosQ16_T_576 = 16'ha57e;
  wire [15:0] _cosQ16_T_577 = -16'sh5a82;
  wire [15:0] _cosQ16_T_578 = 16'ha7be;
  wire [15:0] _cosQ16_T_579 = -16'sh5842;
  wire [15:0] _cosQ16_T_580 = 16'haa0b;
  wire [15:0] _cosQ16_T_581 = -16'sh55f5;
  wire [15:0] _cosQ16_T_582 = 16'hac65;
  wire [15:0] _cosQ16_T_583 = -16'sh539b;
  wire [15:0] _cosQ16_T_584 = 16'haecd;
  wire [15:0] _cosQ16_T_585 = -16'sh5133;
  wire [15:0] _cosQ16_T_586 = 16'hb141;
  wire [15:0] _cosQ16_T_587 = -16'sh4ebf;
  wire [15:0] _cosQ16_T_588 = 16'hb3c1;
  wire [15:0] _cosQ16_T_589 = -16'sh4c3f;
  wire [15:0] _cosQ16_T_590 = 16'hb64c;
  wire [15:0] _cosQ16_T_591 = -16'sh49b4;
  wire [15:0] _cosQ16_T_592 = 16'hb8e4;
  wire [15:0] _cosQ16_T_593 = -16'sh471c;
  wire [15:0] _cosQ16_T_594 = 16'hbb86;
  wire [15:0] _cosQ16_T_595 = -16'sh447a;
  wire [15:0] _cosQ16_T_596 = 16'hbe32;
  wire [15:0] _cosQ16_T_597 = -16'sh41ce;
  wire [15:0] _cosQ16_T_598 = 16'hc0e9;
  wire [15:0] _cosQ16_T_599 = -16'sh3f17;
  wire [15:0] _cosQ16_T_600 = 16'hc3aa;
  wire [15:0] _cosQ16_T_601 = -16'sh3c56;
  wire [15:0] _cosQ16_T_602 = 16'hc674;
  wire [15:0] _cosQ16_T_603 = -16'sh398c;
  wire [15:0] _cosQ16_T_604 = 16'hc946;
  wire [15:0] _cosQ16_T_605 = -16'sh36ba;
  wire [15:0] _cosQ16_T_606 = 16'hcc21;
  wire [15:0] _cosQ16_T_607 = -16'sh33df;
  wire [15:0] _cosQ16_T_608 = 16'hcf05;
  wire [15:0] _cosQ16_T_609 = -16'sh30fb;
  wire [15:0] _cosQ16_T_610 = 16'hd1ef;
  wire [15:0] _cosQ16_T_611 = -16'sh2e11;
  wire [15:0] _cosQ16_T_612 = 16'hd4e1;
  wire [15:0] _cosQ16_T_613 = -16'sh2b1f;
  wire [15:0] _cosQ16_T_614 = 16'hd7da;
  wire [15:0] _cosQ16_T_615 = -16'sh2826;
  wire [15:0] _cosQ16_T_616 = 16'hdad8;
  wire [15:0] _cosQ16_T_617 = -16'sh2528;
  wire [15:0] _cosQ16_T_618 = 16'hdddd;
  wire [15:0] _cosQ16_T_619 = -16'sh2223;
  wire [15:0] _cosQ16_T_620 = 16'he0e6;
  wire [15:0] _cosQ16_T_621 = -16'sh1f1a;
  wire [15:0] _cosQ16_T_622 = 16'he3f5;
  wire [15:0] _cosQ16_T_623 = -16'sh1c0b;
  wire [15:0] _cosQ16_T_624 = 16'he707;
  wire [15:0] _cosQ16_T_625 = -16'sh18f9;
  wire [15:0] _cosQ16_T_626 = 16'hea1e;
  wire [15:0] _cosQ16_T_627 = -16'sh15e2;
  wire [15:0] _cosQ16_T_628 = 16'hed38;
  wire [15:0] _cosQ16_T_629 = -16'sh12c8;
  wire [15:0] _cosQ16_T_630 = 16'hf055;
  wire [15:0] _cosQ16_T_631 = -16'shfab;
  wire [15:0] _cosQ16_T_632 = 16'hf374;
  wire [15:0] _cosQ16_T_633 = -16'shc8c;
  wire [15:0] _cosQ16_T_634 = 16'hf696;
  wire [15:0] _cosQ16_T_635 = -16'sh96a;
  wire [15:0] _cosQ16_T_636 = 16'hf9b8;
  wire [15:0] _cosQ16_T_637 = -16'sh648;
  wire [15:0] _cosQ16_T_638 = 16'hfcdc;
  wire [15:0] _cosQ16_T_639 = -16'sh324;
  wire [15:0] _cosQ16_T_640 = 16'h0;
  wire [15:0] _cosQ16_T_641 = 16'sh0;
  wire [15:0] _cosQ16_T_642 = 16'h324;
  wire [15:0] _cosQ16_T_643 = 16'sh324;
  wire [15:0] _cosQ16_T_644 = 16'h648;
  wire [15:0] _cosQ16_T_645 = 16'sh648;
  wire [15:0] _cosQ16_T_646 = 16'h96a;
  wire [15:0] _cosQ16_T_647 = 16'sh96a;
  wire [15:0] _cosQ16_T_648 = 16'hc8c;
  wire [15:0] _cosQ16_T_649 = 16'shc8c;
  wire [15:0] _cosQ16_T_650 = 16'hfab;
  wire [15:0] _cosQ16_T_651 = 16'shfab;
  wire [15:0] _cosQ16_T_652 = 16'h12c8;
  wire [15:0] _cosQ16_T_653 = 16'sh12c8;
  wire [15:0] _cosQ16_T_654 = 16'h15e2;
  wire [15:0] _cosQ16_T_655 = 16'sh15e2;
  wire [15:0] _cosQ16_T_656 = 16'h18f9;
  wire [15:0] _cosQ16_T_657 = 16'sh18f9;
  wire [15:0] _cosQ16_T_658 = 16'h1c0b;
  wire [15:0] _cosQ16_T_659 = 16'sh1c0b;
  wire [15:0] _cosQ16_T_660 = 16'h1f1a;
  wire [15:0] _cosQ16_T_661 = 16'sh1f1a;
  wire [15:0] _cosQ16_T_662 = 16'h2223;
  wire [15:0] _cosQ16_T_663 = 16'sh2223;
  wire [15:0] _cosQ16_T_664 = 16'h2528;
  wire [15:0] _cosQ16_T_665 = 16'sh2528;
  wire [15:0] _cosQ16_T_666 = 16'h2826;
  wire [15:0] _cosQ16_T_667 = 16'sh2826;
  wire [15:0] _cosQ16_T_668 = 16'h2b1f;
  wire [15:0] _cosQ16_T_669 = 16'sh2b1f;
  wire [15:0] _cosQ16_T_670 = 16'h2e11;
  wire [15:0] _cosQ16_T_671 = 16'sh2e11;
  wire [15:0] _cosQ16_T_672 = 16'h30fb;
  wire [15:0] _cosQ16_T_673 = 16'sh30fb;
  wire [15:0] _cosQ16_T_674 = 16'h33df;
  wire [15:0] _cosQ16_T_675 = 16'sh33df;
  wire [15:0] _cosQ16_T_676 = 16'h36ba;
  wire [15:0] _cosQ16_T_677 = 16'sh36ba;
  wire [15:0] _cosQ16_T_678 = 16'h398c;
  wire [15:0] _cosQ16_T_679 = 16'sh398c;
  wire [15:0] _cosQ16_T_680 = 16'h3c56;
  wire [15:0] _cosQ16_T_681 = 16'sh3c56;
  wire [15:0] _cosQ16_T_682 = 16'h3f17;
  wire [15:0] _cosQ16_T_683 = 16'sh3f17;
  wire [15:0] _cosQ16_T_684 = 16'h41ce;
  wire [15:0] _cosQ16_T_685 = 16'sh41ce;
  wire [15:0] _cosQ16_T_686 = 16'h447a;
  wire [15:0] _cosQ16_T_687 = 16'sh447a;
  wire [15:0] _cosQ16_T_688 = 16'h471c;
  wire [15:0] _cosQ16_T_689 = 16'sh471c;
  wire [15:0] _cosQ16_T_690 = 16'h49b4;
  wire [15:0] _cosQ16_T_691 = 16'sh49b4;
  wire [15:0] _cosQ16_T_692 = 16'h4c3f;
  wire [15:0] _cosQ16_T_693 = 16'sh4c3f;
  wire [15:0] _cosQ16_T_694 = 16'h4ebf;
  wire [15:0] _cosQ16_T_695 = 16'sh4ebf;
  wire [15:0] _cosQ16_T_696 = 16'h5133;
  wire [15:0] _cosQ16_T_697 = 16'sh5133;
  wire [15:0] _cosQ16_T_698 = 16'h539b;
  wire [15:0] _cosQ16_T_699 = 16'sh539b;
  wire [15:0] _cosQ16_T_700 = 16'h55f5;
  wire [15:0] _cosQ16_T_701 = 16'sh55f5;
  wire [15:0] _cosQ16_T_702 = 16'h5842;
  wire [15:0] _cosQ16_T_703 = 16'sh5842;
  wire [15:0] _cosQ16_T_704 = 16'h5a82;
  wire [15:0] _cosQ16_T_705 = 16'sh5a82;
  wire [15:0] _cosQ16_T_706 = 16'h5cb3;
  wire [15:0] _cosQ16_T_707 = 16'sh5cb3;
  wire [15:0] _cosQ16_T_708 = 16'h5ed7;
  wire [15:0] _cosQ16_T_709 = 16'sh5ed7;
  wire [15:0] _cosQ16_T_710 = 16'h60eb;
  wire [15:0] _cosQ16_T_711 = 16'sh60eb;
  wire [15:0] _cosQ16_T_712 = 16'h62f1;
  wire [15:0] _cosQ16_T_713 = 16'sh62f1;
  wire [15:0] _cosQ16_T_714 = 16'h64e8;
  wire [15:0] _cosQ16_T_715 = 16'sh64e8;
  wire [15:0] _cosQ16_T_716 = 16'h66cf;
  wire [15:0] _cosQ16_T_717 = 16'sh66cf;
  wire [15:0] _cosQ16_T_718 = 16'h68a6;
  wire [15:0] _cosQ16_T_719 = 16'sh68a6;
  wire [15:0] _cosQ16_T_720 = 16'h6a6d;
  wire [15:0] _cosQ16_T_721 = 16'sh6a6d;
  wire [15:0] _cosQ16_T_722 = 16'h6c23;
  wire [15:0] _cosQ16_T_723 = 16'sh6c23;
  wire [15:0] _cosQ16_T_724 = 16'h6dc9;
  wire [15:0] _cosQ16_T_725 = 16'sh6dc9;
  wire [15:0] _cosQ16_T_726 = 16'h6f5e;
  wire [15:0] _cosQ16_T_727 = 16'sh6f5e;
  wire [15:0] _cosQ16_T_728 = 16'h70e2;
  wire [15:0] _cosQ16_T_729 = 16'sh70e2;
  wire [15:0] _cosQ16_T_730 = 16'h7254;
  wire [15:0] _cosQ16_T_731 = 16'sh7254;
  wire [15:0] _cosQ16_T_732 = 16'h73b5;
  wire [15:0] _cosQ16_T_733 = 16'sh73b5;
  wire [15:0] _cosQ16_T_734 = 16'h7504;
  wire [15:0] _cosQ16_T_735 = 16'sh7504;
  wire [15:0] _cosQ16_T_736 = 16'h7641;
  wire [15:0] _cosQ16_T_737 = 16'sh7641;
  wire [15:0] _cosQ16_T_738 = 16'h776b;
  wire [15:0] _cosQ16_T_739 = 16'sh776b;
  wire [15:0] _cosQ16_T_740 = 16'h7884;
  wire [15:0] _cosQ16_T_741 = 16'sh7884;
  wire [15:0] _cosQ16_T_742 = 16'h7989;
  wire [15:0] _cosQ16_T_743 = 16'sh7989;
  wire [15:0] _cosQ16_T_744 = 16'h7a7c;
  wire [15:0] _cosQ16_T_745 = 16'sh7a7c;
  wire [15:0] _cosQ16_T_746 = 16'h7b5c;
  wire [15:0] _cosQ16_T_747 = 16'sh7b5c;
  wire [15:0] _cosQ16_T_748 = 16'h7c29;
  wire [15:0] _cosQ16_T_749 = 16'sh7c29;
  wire [15:0] _cosQ16_T_750 = 16'h7ce3;
  wire [15:0] _cosQ16_T_751 = 16'sh7ce3;
  wire [15:0] _cosQ16_T_752 = 16'h7d89;
  wire [15:0] _cosQ16_T_753 = 16'sh7d89;
  wire [15:0] _cosQ16_T_754 = 16'h7e1d;
  wire [15:0] _cosQ16_T_755 = 16'sh7e1d;
  wire [15:0] _cosQ16_T_756 = 16'h7e9c;
  wire [15:0] _cosQ16_T_757 = 16'sh7e9c;
  wire [15:0] _cosQ16_T_758 = 16'h7f09;
  wire [15:0] _cosQ16_T_759 = 16'sh7f09;
  wire [15:0] _cosQ16_T_760 = 16'h7f61;
  wire [15:0] _cosQ16_T_761 = 16'sh7f61;
  wire [15:0] _cosQ16_T_762 = 16'h7fa6;
  wire [15:0] _cosQ16_T_763 = 16'sh7fa6;
  wire [15:0] _cosQ16_T_764 = 16'h7fd8;
  wire [15:0] _cosQ16_T_765 = 16'sh7fd8;
  wire [15:0] _cosQ16_T_766 = 16'h7ff5;
  wire [15:0] _cosQ16_T_767 = 16'sh7ff5;
  wire [15:0] _cosQ16_WIRE = 16'sh7fff;
  wire [15:0] _cosQ16_T_768 = _cosQ16_T ? $signed(16'sh7fff) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_1 = 16'sh7ff5;
  wire [15:0] _cosQ16_T_769 = _cosQ16_T_1 ? $signed(16'sh7ff5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_2 = 16'sh7fd8;
  wire [15:0] _cosQ16_T_770 = _cosQ16_T_2 ? $signed(16'sh7fd8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_3 = 16'sh7fa6;
  wire [15:0] _cosQ16_T_771 = _cosQ16_T_3 ? $signed(16'sh7fa6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_4 = 16'sh7f61;
  wire [15:0] _cosQ16_T_772 = _cosQ16_T_4 ? $signed(16'sh7f61) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_5 = 16'sh7f09;
  wire [15:0] _cosQ16_T_773 = _cosQ16_T_5 ? $signed(16'sh7f09) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_6 = 16'sh7e9c;
  wire [15:0] _cosQ16_T_774 = _cosQ16_T_6 ? $signed(16'sh7e9c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_7 = 16'sh7e1d;
  wire [15:0] _cosQ16_T_775 = _cosQ16_T_7 ? $signed(16'sh7e1d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_8 = 16'sh7d89;
  wire [15:0] _cosQ16_T_776 = _cosQ16_T_8 ? $signed(16'sh7d89) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_9 = 16'sh7ce3;
  wire [15:0] _cosQ16_T_777 = _cosQ16_T_9 ? $signed(16'sh7ce3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_10 = 16'sh7c29;
  wire [15:0] _cosQ16_T_778 = _cosQ16_T_10 ? $signed(16'sh7c29) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_11 = 16'sh7b5c;
  wire [15:0] _cosQ16_T_779 = _cosQ16_T_11 ? $signed(16'sh7b5c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_12 = 16'sh7a7c;
  wire [15:0] _cosQ16_T_780 = _cosQ16_T_12 ? $signed(16'sh7a7c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_13 = 16'sh7989;
  wire [15:0] _cosQ16_T_781 = _cosQ16_T_13 ? $signed(16'sh7989) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_14 = 16'sh7884;
  wire [15:0] _cosQ16_T_782 = _cosQ16_T_14 ? $signed(16'sh7884) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_15 = 16'sh776b;
  wire [15:0] _cosQ16_T_783 = _cosQ16_T_15 ? $signed(16'sh776b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_16 = 16'sh7641;
  wire [15:0] _cosQ16_T_784 = _cosQ16_T_16 ? $signed(16'sh7641) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_17 = 16'sh7504;
  wire [15:0] _cosQ16_T_785 = _cosQ16_T_17 ? $signed(16'sh7504) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_18 = 16'sh73b5;
  wire [15:0] _cosQ16_T_786 = _cosQ16_T_18 ? $signed(16'sh73b5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_19 = 16'sh7254;
  wire [15:0] _cosQ16_T_787 = _cosQ16_T_19 ? $signed(16'sh7254) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_20 = 16'sh70e2;
  wire [15:0] _cosQ16_T_788 = _cosQ16_T_20 ? $signed(16'sh70e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_21 = 16'sh6f5e;
  wire [15:0] _cosQ16_T_789 = _cosQ16_T_21 ? $signed(16'sh6f5e) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_22 = 16'sh6dc9;
  wire [15:0] _cosQ16_T_790 = _cosQ16_T_22 ? $signed(16'sh6dc9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_23 = 16'sh6c23;
  wire [15:0] _cosQ16_T_791 = _cosQ16_T_23 ? $signed(16'sh6c23) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_24 = 16'sh6a6d;
  wire [15:0] _cosQ16_T_792 = _cosQ16_T_24 ? $signed(16'sh6a6d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_25 = 16'sh68a6;
  wire [15:0] _cosQ16_T_793 = _cosQ16_T_25 ? $signed(16'sh68a6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_26 = 16'sh66cf;
  wire [15:0] _cosQ16_T_794 = _cosQ16_T_26 ? $signed(16'sh66cf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_27 = 16'sh64e8;
  wire [15:0] _cosQ16_T_795 = _cosQ16_T_27 ? $signed(16'sh64e8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_28 = 16'sh62f1;
  wire [15:0] _cosQ16_T_796 = _cosQ16_T_28 ? $signed(16'sh62f1) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_29 = 16'sh60eb;
  wire [15:0] _cosQ16_T_797 = _cosQ16_T_29 ? $signed(16'sh60eb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_30 = 16'sh5ed7;
  wire [15:0] _cosQ16_T_798 = _cosQ16_T_30 ? $signed(16'sh5ed7) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_31 = 16'sh5cb3;
  wire [15:0] _cosQ16_T_799 = _cosQ16_T_31 ? $signed(16'sh5cb3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_32 = 16'sh5a82;
  wire [15:0] _cosQ16_T_800 = _cosQ16_T_32 ? $signed(16'sh5a82) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_33 = 16'sh5842;
  wire [15:0] _cosQ16_T_801 = _cosQ16_T_33 ? $signed(16'sh5842) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_34 = 16'sh55f5;
  wire [15:0] _cosQ16_T_802 = _cosQ16_T_34 ? $signed(16'sh55f5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_35 = 16'sh539b;
  wire [15:0] _cosQ16_T_803 = _cosQ16_T_35 ? $signed(16'sh539b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_36 = 16'sh5133;
  wire [15:0] _cosQ16_T_804 = _cosQ16_T_36 ? $signed(16'sh5133) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_37 = 16'sh4ebf;
  wire [15:0] _cosQ16_T_805 = _cosQ16_T_37 ? $signed(16'sh4ebf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_38 = 16'sh4c3f;
  wire [15:0] _cosQ16_T_806 = _cosQ16_T_38 ? $signed(16'sh4c3f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_39 = 16'sh49b4;
  wire [15:0] _cosQ16_T_807 = _cosQ16_T_39 ? $signed(16'sh49b4) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_40 = 16'sh471c;
  wire [15:0] _cosQ16_T_808 = _cosQ16_T_40 ? $signed(16'sh471c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_41 = 16'sh447a;
  wire [15:0] _cosQ16_T_809 = _cosQ16_T_41 ? $signed(16'sh447a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_42 = 16'sh41ce;
  wire [15:0] _cosQ16_T_810 = _cosQ16_T_42 ? $signed(16'sh41ce) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_43 = 16'sh3f17;
  wire [15:0] _cosQ16_T_811 = _cosQ16_T_43 ? $signed(16'sh3f17) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_44 = 16'sh3c56;
  wire [15:0] _cosQ16_T_812 = _cosQ16_T_44 ? $signed(16'sh3c56) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_45 = 16'sh398c;
  wire [15:0] _cosQ16_T_813 = _cosQ16_T_45 ? $signed(16'sh398c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_46 = 16'sh36ba;
  wire [15:0] _cosQ16_T_814 = _cosQ16_T_46 ? $signed(16'sh36ba) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_47 = 16'sh33df;
  wire [15:0] _cosQ16_T_815 = _cosQ16_T_47 ? $signed(16'sh33df) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_48 = 16'sh30fb;
  wire [15:0] _cosQ16_T_816 = _cosQ16_T_48 ? $signed(16'sh30fb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_49 = 16'sh2e11;
  wire [15:0] _cosQ16_T_817 = _cosQ16_T_49 ? $signed(16'sh2e11) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_50 = 16'sh2b1f;
  wire [15:0] _cosQ16_T_818 = _cosQ16_T_50 ? $signed(16'sh2b1f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_51 = 16'sh2826;
  wire [15:0] _cosQ16_T_819 = _cosQ16_T_51 ? $signed(16'sh2826) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_52 = 16'sh2528;
  wire [15:0] _cosQ16_T_820 = _cosQ16_T_52 ? $signed(16'sh2528) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_53 = 16'sh2223;
  wire [15:0] _cosQ16_T_821 = _cosQ16_T_53 ? $signed(16'sh2223) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_54 = 16'sh1f1a;
  wire [15:0] _cosQ16_T_822 = _cosQ16_T_54 ? $signed(16'sh1f1a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_55 = 16'sh1c0b;
  wire [15:0] _cosQ16_T_823 = _cosQ16_T_55 ? $signed(16'sh1c0b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_56 = 16'sh18f9;
  wire [15:0] _cosQ16_T_824 = _cosQ16_T_56 ? $signed(16'sh18f9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_57 = 16'sh15e2;
  wire [15:0] _cosQ16_T_825 = _cosQ16_T_57 ? $signed(16'sh15e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_58 = 16'sh12c8;
  wire [15:0] _cosQ16_T_826 = _cosQ16_T_58 ? $signed(16'sh12c8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_59 = 16'shfab;
  wire [15:0] _cosQ16_T_827 = _cosQ16_T_59 ? $signed(16'shfab) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_60 = 16'shc8c;
  wire [15:0] _cosQ16_T_828 = _cosQ16_T_60 ? $signed(16'shc8c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_61 = 16'sh96a;
  wire [15:0] _cosQ16_T_829 = _cosQ16_T_61 ? $signed(16'sh96a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_62 = 16'sh648;
  wire [15:0] _cosQ16_T_830 = _cosQ16_T_62 ? $signed(16'sh648) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_63 = 16'sh324;
  wire [15:0] _cosQ16_T_831 = _cosQ16_T_63 ? $signed(16'sh324) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_64 = 16'sh0;
  wire [15:0] _cosQ16_T_832 = 16'sh0;
  wire [15:0] _cosQ16_WIRE_65 = -16'sh324;
  wire [15:0] _cosQ16_T_833 = _cosQ16_T_65 ? $signed(-16'sh324) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_66 = -16'sh648;
  wire [15:0] _cosQ16_T_834 = _cosQ16_T_66 ? $signed(-16'sh648) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_67 = -16'sh96a;
  wire [15:0] _cosQ16_T_835 = _cosQ16_T_67 ? $signed(-16'sh96a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_68 = -16'shc8c;
  wire [15:0] _cosQ16_T_836 = _cosQ16_T_68 ? $signed(-16'shc8c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_69 = -16'shfab;
  wire [15:0] _cosQ16_T_837 = _cosQ16_T_69 ? $signed(-16'shfab) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_70 = -16'sh12c8;
  wire [15:0] _cosQ16_T_838 = _cosQ16_T_70 ? $signed(-16'sh12c8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_71 = -16'sh15e2;
  wire [15:0] _cosQ16_T_839 = _cosQ16_T_71 ? $signed(-16'sh15e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_72 = -16'sh18f9;
  wire [15:0] _cosQ16_T_840 = _cosQ16_T_72 ? $signed(-16'sh18f9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_73 = -16'sh1c0b;
  wire [15:0] _cosQ16_T_841 = _cosQ16_T_73 ? $signed(-16'sh1c0b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_74 = -16'sh1f1a;
  wire [15:0] _cosQ16_T_842 = _cosQ16_T_74 ? $signed(-16'sh1f1a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_75 = -16'sh2223;
  wire [15:0] _cosQ16_T_843 = _cosQ16_T_75 ? $signed(-16'sh2223) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_76 = -16'sh2528;
  wire [15:0] _cosQ16_T_844 = _cosQ16_T_76 ? $signed(-16'sh2528) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_77 = -16'sh2826;
  wire [15:0] _cosQ16_T_845 = _cosQ16_T_77 ? $signed(-16'sh2826) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_78 = -16'sh2b1f;
  wire [15:0] _cosQ16_T_846 = _cosQ16_T_78 ? $signed(-16'sh2b1f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_79 = -16'sh2e11;
  wire [15:0] _cosQ16_T_847 = _cosQ16_T_79 ? $signed(-16'sh2e11) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_80 = -16'sh30fb;
  wire [15:0] _cosQ16_T_848 = _cosQ16_T_80 ? $signed(-16'sh30fb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_81 = -16'sh33df;
  wire [15:0] _cosQ16_T_849 = _cosQ16_T_81 ? $signed(-16'sh33df) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_82 = -16'sh36ba;
  wire [15:0] _cosQ16_T_850 = _cosQ16_T_82 ? $signed(-16'sh36ba) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_83 = -16'sh398c;
  wire [15:0] _cosQ16_T_851 = _cosQ16_T_83 ? $signed(-16'sh398c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_84 = -16'sh3c56;
  wire [15:0] _cosQ16_T_852 = _cosQ16_T_84 ? $signed(-16'sh3c56) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_85 = -16'sh3f17;
  wire [15:0] _cosQ16_T_853 = _cosQ16_T_85 ? $signed(-16'sh3f17) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_86 = -16'sh41ce;
  wire [15:0] _cosQ16_T_854 = _cosQ16_T_86 ? $signed(-16'sh41ce) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_87 = -16'sh447a;
  wire [15:0] _cosQ16_T_855 = _cosQ16_T_87 ? $signed(-16'sh447a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_88 = -16'sh471c;
  wire [15:0] _cosQ16_T_856 = _cosQ16_T_88 ? $signed(-16'sh471c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_89 = -16'sh49b4;
  wire [15:0] _cosQ16_T_857 = _cosQ16_T_89 ? $signed(-16'sh49b4) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_90 = -16'sh4c3f;
  wire [15:0] _cosQ16_T_858 = _cosQ16_T_90 ? $signed(-16'sh4c3f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_91 = -16'sh4ebf;
  wire [15:0] _cosQ16_T_859 = _cosQ16_T_91 ? $signed(-16'sh4ebf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_92 = -16'sh5133;
  wire [15:0] _cosQ16_T_860 = _cosQ16_T_92 ? $signed(-16'sh5133) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_93 = -16'sh539b;
  wire [15:0] _cosQ16_T_861 = _cosQ16_T_93 ? $signed(-16'sh539b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_94 = -16'sh55f5;
  wire [15:0] _cosQ16_T_862 = _cosQ16_T_94 ? $signed(-16'sh55f5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_95 = -16'sh5842;
  wire [15:0] _cosQ16_T_863 = _cosQ16_T_95 ? $signed(-16'sh5842) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_96 = -16'sh5a82;
  wire [15:0] _cosQ16_T_864 = _cosQ16_T_96 ? $signed(-16'sh5a82) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_97 = -16'sh5cb3;
  wire [15:0] _cosQ16_T_865 = _cosQ16_T_97 ? $signed(-16'sh5cb3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_98 = -16'sh5ed7;
  wire [15:0] _cosQ16_T_866 = _cosQ16_T_98 ? $signed(-16'sh5ed7) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_99 = -16'sh60eb;
  wire [15:0] _cosQ16_T_867 = _cosQ16_T_99 ? $signed(-16'sh60eb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_100 = -16'sh62f1;
  wire [15:0] _cosQ16_T_868 = _cosQ16_T_100 ? $signed(-16'sh62f1) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_101 = -16'sh64e8;
  wire [15:0] _cosQ16_T_869 = _cosQ16_T_101 ? $signed(-16'sh64e8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_102 = -16'sh66cf;
  wire [15:0] _cosQ16_T_870 = _cosQ16_T_102 ? $signed(-16'sh66cf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_103 = -16'sh68a6;
  wire [15:0] _cosQ16_T_871 = _cosQ16_T_103 ? $signed(-16'sh68a6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_104 = -16'sh6a6d;
  wire [15:0] _cosQ16_T_872 = _cosQ16_T_104 ? $signed(-16'sh6a6d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_105 = -16'sh6c23;
  wire [15:0] _cosQ16_T_873 = _cosQ16_T_105 ? $signed(-16'sh6c23) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_106 = -16'sh6dc9;
  wire [15:0] _cosQ16_T_874 = _cosQ16_T_106 ? $signed(-16'sh6dc9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_107 = -16'sh6f5e;
  wire [15:0] _cosQ16_T_875 = _cosQ16_T_107 ? $signed(-16'sh6f5e) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_108 = -16'sh70e2;
  wire [15:0] _cosQ16_T_876 = _cosQ16_T_108 ? $signed(-16'sh70e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_109 = -16'sh7254;
  wire [15:0] _cosQ16_T_877 = _cosQ16_T_109 ? $signed(-16'sh7254) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_110 = -16'sh73b5;
  wire [15:0] _cosQ16_T_878 = _cosQ16_T_110 ? $signed(-16'sh73b5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_111 = -16'sh7504;
  wire [15:0] _cosQ16_T_879 = _cosQ16_T_111 ? $signed(-16'sh7504) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_112 = -16'sh7641;
  wire [15:0] _cosQ16_T_880 = _cosQ16_T_112 ? $signed(-16'sh7641) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_113 = -16'sh776b;
  wire [15:0] _cosQ16_T_881 = _cosQ16_T_113 ? $signed(-16'sh776b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_114 = -16'sh7884;
  wire [15:0] _cosQ16_T_882 = _cosQ16_T_114 ? $signed(-16'sh7884) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_115 = -16'sh7989;
  wire [15:0] _cosQ16_T_883 = _cosQ16_T_115 ? $signed(-16'sh7989) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_116 = -16'sh7a7c;
  wire [15:0] _cosQ16_T_884 = _cosQ16_T_116 ? $signed(-16'sh7a7c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_117 = -16'sh7b5c;
  wire [15:0] _cosQ16_T_885 = _cosQ16_T_117 ? $signed(-16'sh7b5c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_118 = -16'sh7c29;
  wire [15:0] _cosQ16_T_886 = _cosQ16_T_118 ? $signed(-16'sh7c29) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_119 = -16'sh7ce3;
  wire [15:0] _cosQ16_T_887 = _cosQ16_T_119 ? $signed(-16'sh7ce3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_120 = -16'sh7d89;
  wire [15:0] _cosQ16_T_888 = _cosQ16_T_120 ? $signed(-16'sh7d89) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_121 = -16'sh7e1d;
  wire [15:0] _cosQ16_T_889 = _cosQ16_T_121 ? $signed(-16'sh7e1d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_122 = -16'sh7e9c;
  wire [15:0] _cosQ16_T_890 = _cosQ16_T_122 ? $signed(-16'sh7e9c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_123 = -16'sh7f09;
  wire [15:0] _cosQ16_T_891 = _cosQ16_T_123 ? $signed(-16'sh7f09) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_124 = -16'sh7f61;
  wire [15:0] _cosQ16_T_892 = _cosQ16_T_124 ? $signed(-16'sh7f61) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_125 = -16'sh7fa6;
  wire [15:0] _cosQ16_T_893 = _cosQ16_T_125 ? $signed(-16'sh7fa6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_126 = -16'sh7fd8;
  wire [15:0] _cosQ16_T_894 = _cosQ16_T_126 ? $signed(-16'sh7fd8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_127 = -16'sh7ff5;
  wire [15:0] _cosQ16_T_895 = _cosQ16_T_127 ? $signed(-16'sh7ff5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_128 = -16'sh7fff;
  wire [15:0] _cosQ16_T_896 = _cosQ16_T_128 ? $signed(-16'sh7fff) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_129 = -16'sh7ff5;
  wire [15:0] _cosQ16_T_897 = _cosQ16_T_129 ? $signed(-16'sh7ff5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_130 = -16'sh7fd8;
  wire [15:0] _cosQ16_T_898 = _cosQ16_T_130 ? $signed(-16'sh7fd8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_131 = -16'sh7fa6;
  wire [15:0] _cosQ16_T_899 = _cosQ16_T_131 ? $signed(-16'sh7fa6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_132 = -16'sh7f61;
  wire [15:0] _cosQ16_T_900 = _cosQ16_T_132 ? $signed(-16'sh7f61) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_133 = -16'sh7f09;
  wire [15:0] _cosQ16_T_901 = _cosQ16_T_133 ? $signed(-16'sh7f09) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_134 = -16'sh7e9c;
  wire [15:0] _cosQ16_T_902 = _cosQ16_T_134 ? $signed(-16'sh7e9c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_135 = -16'sh7e1d;
  wire [15:0] _cosQ16_T_903 = _cosQ16_T_135 ? $signed(-16'sh7e1d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_136 = -16'sh7d89;
  wire [15:0] _cosQ16_T_904 = _cosQ16_T_136 ? $signed(-16'sh7d89) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_137 = -16'sh7ce3;
  wire [15:0] _cosQ16_T_905 = _cosQ16_T_137 ? $signed(-16'sh7ce3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_138 = -16'sh7c29;
  wire [15:0] _cosQ16_T_906 = _cosQ16_T_138 ? $signed(-16'sh7c29) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_139 = -16'sh7b5c;
  wire [15:0] _cosQ16_T_907 = _cosQ16_T_139 ? $signed(-16'sh7b5c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_140 = -16'sh7a7c;
  wire [15:0] _cosQ16_T_908 = _cosQ16_T_140 ? $signed(-16'sh7a7c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_141 = -16'sh7989;
  wire [15:0] _cosQ16_T_909 = _cosQ16_T_141 ? $signed(-16'sh7989) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_142 = -16'sh7884;
  wire [15:0] _cosQ16_T_910 = _cosQ16_T_142 ? $signed(-16'sh7884) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_143 = -16'sh776b;
  wire [15:0] _cosQ16_T_911 = _cosQ16_T_143 ? $signed(-16'sh776b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_144 = -16'sh7641;
  wire [15:0] _cosQ16_T_912 = _cosQ16_T_144 ? $signed(-16'sh7641) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_145 = -16'sh7504;
  wire [15:0] _cosQ16_T_913 = _cosQ16_T_145 ? $signed(-16'sh7504) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_146 = -16'sh73b5;
  wire [15:0] _cosQ16_T_914 = _cosQ16_T_146 ? $signed(-16'sh73b5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_147 = -16'sh7254;
  wire [15:0] _cosQ16_T_915 = _cosQ16_T_147 ? $signed(-16'sh7254) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_148 = -16'sh70e2;
  wire [15:0] _cosQ16_T_916 = _cosQ16_T_148 ? $signed(-16'sh70e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_149 = -16'sh6f5e;
  wire [15:0] _cosQ16_T_917 = _cosQ16_T_149 ? $signed(-16'sh6f5e) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_150 = -16'sh6dc9;
  wire [15:0] _cosQ16_T_918 = _cosQ16_T_150 ? $signed(-16'sh6dc9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_151 = -16'sh6c23;
  wire [15:0] _cosQ16_T_919 = _cosQ16_T_151 ? $signed(-16'sh6c23) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_152 = -16'sh6a6d;
  wire [15:0] _cosQ16_T_920 = _cosQ16_T_152 ? $signed(-16'sh6a6d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_153 = -16'sh68a6;
  wire [15:0] _cosQ16_T_921 = _cosQ16_T_153 ? $signed(-16'sh68a6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_154 = -16'sh66cf;
  wire [15:0] _cosQ16_T_922 = _cosQ16_T_154 ? $signed(-16'sh66cf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_155 = -16'sh64e8;
  wire [15:0] _cosQ16_T_923 = _cosQ16_T_155 ? $signed(-16'sh64e8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_156 = -16'sh62f1;
  wire [15:0] _cosQ16_T_924 = _cosQ16_T_156 ? $signed(-16'sh62f1) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_157 = -16'sh60eb;
  wire [15:0] _cosQ16_T_925 = _cosQ16_T_157 ? $signed(-16'sh60eb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_158 = -16'sh5ed7;
  wire [15:0] _cosQ16_T_926 = _cosQ16_T_158 ? $signed(-16'sh5ed7) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_159 = -16'sh5cb3;
  wire [15:0] _cosQ16_T_927 = _cosQ16_T_159 ? $signed(-16'sh5cb3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_160 = -16'sh5a82;
  wire [15:0] _cosQ16_T_928 = _cosQ16_T_160 ? $signed(-16'sh5a82) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_161 = -16'sh5842;
  wire [15:0] _cosQ16_T_929 = _cosQ16_T_161 ? $signed(-16'sh5842) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_162 = -16'sh55f5;
  wire [15:0] _cosQ16_T_930 = _cosQ16_T_162 ? $signed(-16'sh55f5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_163 = -16'sh539b;
  wire [15:0] _cosQ16_T_931 = _cosQ16_T_163 ? $signed(-16'sh539b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_164 = -16'sh5133;
  wire [15:0] _cosQ16_T_932 = _cosQ16_T_164 ? $signed(-16'sh5133) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_165 = -16'sh4ebf;
  wire [15:0] _cosQ16_T_933 = _cosQ16_T_165 ? $signed(-16'sh4ebf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_166 = -16'sh4c3f;
  wire [15:0] _cosQ16_T_934 = _cosQ16_T_166 ? $signed(-16'sh4c3f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_167 = -16'sh49b4;
  wire [15:0] _cosQ16_T_935 = _cosQ16_T_167 ? $signed(-16'sh49b4) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_168 = -16'sh471c;
  wire [15:0] _cosQ16_T_936 = _cosQ16_T_168 ? $signed(-16'sh471c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_169 = -16'sh447a;
  wire [15:0] _cosQ16_T_937 = _cosQ16_T_169 ? $signed(-16'sh447a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_170 = -16'sh41ce;
  wire [15:0] _cosQ16_T_938 = _cosQ16_T_170 ? $signed(-16'sh41ce) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_171 = -16'sh3f17;
  wire [15:0] _cosQ16_T_939 = _cosQ16_T_171 ? $signed(-16'sh3f17) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_172 = -16'sh3c56;
  wire [15:0] _cosQ16_T_940 = _cosQ16_T_172 ? $signed(-16'sh3c56) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_173 = -16'sh398c;
  wire [15:0] _cosQ16_T_941 = _cosQ16_T_173 ? $signed(-16'sh398c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_174 = -16'sh36ba;
  wire [15:0] _cosQ16_T_942 = _cosQ16_T_174 ? $signed(-16'sh36ba) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_175 = -16'sh33df;
  wire [15:0] _cosQ16_T_943 = _cosQ16_T_175 ? $signed(-16'sh33df) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_176 = -16'sh30fb;
  wire [15:0] _cosQ16_T_944 = _cosQ16_T_176 ? $signed(-16'sh30fb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_177 = -16'sh2e11;
  wire [15:0] _cosQ16_T_945 = _cosQ16_T_177 ? $signed(-16'sh2e11) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_178 = -16'sh2b1f;
  wire [15:0] _cosQ16_T_946 = _cosQ16_T_178 ? $signed(-16'sh2b1f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_179 = -16'sh2826;
  wire [15:0] _cosQ16_T_947 = _cosQ16_T_179 ? $signed(-16'sh2826) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_180 = -16'sh2528;
  wire [15:0] _cosQ16_T_948 = _cosQ16_T_180 ? $signed(-16'sh2528) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_181 = -16'sh2223;
  wire [15:0] _cosQ16_T_949 = _cosQ16_T_181 ? $signed(-16'sh2223) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_182 = -16'sh1f1a;
  wire [15:0] _cosQ16_T_950 = _cosQ16_T_182 ? $signed(-16'sh1f1a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_183 = -16'sh1c0b;
  wire [15:0] _cosQ16_T_951 = _cosQ16_T_183 ? $signed(-16'sh1c0b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_184 = -16'sh18f9;
  wire [15:0] _cosQ16_T_952 = _cosQ16_T_184 ? $signed(-16'sh18f9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_185 = -16'sh15e2;
  wire [15:0] _cosQ16_T_953 = _cosQ16_T_185 ? $signed(-16'sh15e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_186 = -16'sh12c8;
  wire [15:0] _cosQ16_T_954 = _cosQ16_T_186 ? $signed(-16'sh12c8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_187 = -16'shfab;
  wire [15:0] _cosQ16_T_955 = _cosQ16_T_187 ? $signed(-16'shfab) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_188 = -16'shc8c;
  wire [15:0] _cosQ16_T_956 = _cosQ16_T_188 ? $signed(-16'shc8c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_189 = -16'sh96a;
  wire [15:0] _cosQ16_T_957 = _cosQ16_T_189 ? $signed(-16'sh96a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_190 = -16'sh648;
  wire [15:0] _cosQ16_T_958 = _cosQ16_T_190 ? $signed(-16'sh648) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_191 = -16'sh324;
  wire [15:0] _cosQ16_T_959 = _cosQ16_T_191 ? $signed(-16'sh324) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_192 = 16'sh0;
  wire [15:0] _cosQ16_T_960 = 16'sh0;
  wire [15:0] _cosQ16_WIRE_193 = 16'sh324;
  wire [15:0] _cosQ16_T_961 = _cosQ16_T_193 ? $signed(16'sh324) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_194 = 16'sh648;
  wire [15:0] _cosQ16_T_962 = _cosQ16_T_194 ? $signed(16'sh648) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_195 = 16'sh96a;
  wire [15:0] _cosQ16_T_963 = _cosQ16_T_195 ? $signed(16'sh96a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_196 = 16'shc8c;
  wire [15:0] _cosQ16_T_964 = _cosQ16_T_196 ? $signed(16'shc8c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_197 = 16'shfab;
  wire [15:0] _cosQ16_T_965 = _cosQ16_T_197 ? $signed(16'shfab) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_198 = 16'sh12c8;
  wire [15:0] _cosQ16_T_966 = _cosQ16_T_198 ? $signed(16'sh12c8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_199 = 16'sh15e2;
  wire [15:0] _cosQ16_T_967 = _cosQ16_T_199 ? $signed(16'sh15e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_200 = 16'sh18f9;
  wire [15:0] _cosQ16_T_968 = _cosQ16_T_200 ? $signed(16'sh18f9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_201 = 16'sh1c0b;
  wire [15:0] _cosQ16_T_969 = _cosQ16_T_201 ? $signed(16'sh1c0b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_202 = 16'sh1f1a;
  wire [15:0] _cosQ16_T_970 = _cosQ16_T_202 ? $signed(16'sh1f1a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_203 = 16'sh2223;
  wire [15:0] _cosQ16_T_971 = _cosQ16_T_203 ? $signed(16'sh2223) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_204 = 16'sh2528;
  wire [15:0] _cosQ16_T_972 = _cosQ16_T_204 ? $signed(16'sh2528) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_205 = 16'sh2826;
  wire [15:0] _cosQ16_T_973 = _cosQ16_T_205 ? $signed(16'sh2826) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_206 = 16'sh2b1f;
  wire [15:0] _cosQ16_T_974 = _cosQ16_T_206 ? $signed(16'sh2b1f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_207 = 16'sh2e11;
  wire [15:0] _cosQ16_T_975 = _cosQ16_T_207 ? $signed(16'sh2e11) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_208 = 16'sh30fb;
  wire [15:0] _cosQ16_T_976 = _cosQ16_T_208 ? $signed(16'sh30fb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_209 = 16'sh33df;
  wire [15:0] _cosQ16_T_977 = _cosQ16_T_209 ? $signed(16'sh33df) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_210 = 16'sh36ba;
  wire [15:0] _cosQ16_T_978 = _cosQ16_T_210 ? $signed(16'sh36ba) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_211 = 16'sh398c;
  wire [15:0] _cosQ16_T_979 = _cosQ16_T_211 ? $signed(16'sh398c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_212 = 16'sh3c56;
  wire [15:0] _cosQ16_T_980 = _cosQ16_T_212 ? $signed(16'sh3c56) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_213 = 16'sh3f17;
  wire [15:0] _cosQ16_T_981 = _cosQ16_T_213 ? $signed(16'sh3f17) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_214 = 16'sh41ce;
  wire [15:0] _cosQ16_T_982 = _cosQ16_T_214 ? $signed(16'sh41ce) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_215 = 16'sh447a;
  wire [15:0] _cosQ16_T_983 = _cosQ16_T_215 ? $signed(16'sh447a) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_216 = 16'sh471c;
  wire [15:0] _cosQ16_T_984 = _cosQ16_T_216 ? $signed(16'sh471c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_217 = 16'sh49b4;
  wire [15:0] _cosQ16_T_985 = _cosQ16_T_217 ? $signed(16'sh49b4) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_218 = 16'sh4c3f;
  wire [15:0] _cosQ16_T_986 = _cosQ16_T_218 ? $signed(16'sh4c3f) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_219 = 16'sh4ebf;
  wire [15:0] _cosQ16_T_987 = _cosQ16_T_219 ? $signed(16'sh4ebf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_220 = 16'sh5133;
  wire [15:0] _cosQ16_T_988 = _cosQ16_T_220 ? $signed(16'sh5133) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_221 = 16'sh539b;
  wire [15:0] _cosQ16_T_989 = _cosQ16_T_221 ? $signed(16'sh539b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_222 = 16'sh55f5;
  wire [15:0] _cosQ16_T_990 = _cosQ16_T_222 ? $signed(16'sh55f5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_223 = 16'sh5842;
  wire [15:0] _cosQ16_T_991 = _cosQ16_T_223 ? $signed(16'sh5842) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_224 = 16'sh5a82;
  wire [15:0] _cosQ16_T_992 = _cosQ16_T_224 ? $signed(16'sh5a82) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_225 = 16'sh5cb3;
  wire [15:0] _cosQ16_T_993 = _cosQ16_T_225 ? $signed(16'sh5cb3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_226 = 16'sh5ed7;
  wire [15:0] _cosQ16_T_994 = _cosQ16_T_226 ? $signed(16'sh5ed7) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_227 = 16'sh60eb;
  wire [15:0] _cosQ16_T_995 = _cosQ16_T_227 ? $signed(16'sh60eb) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_228 = 16'sh62f1;
  wire [15:0] _cosQ16_T_996 = _cosQ16_T_228 ? $signed(16'sh62f1) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_229 = 16'sh64e8;
  wire [15:0] _cosQ16_T_997 = _cosQ16_T_229 ? $signed(16'sh64e8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_230 = 16'sh66cf;
  wire [15:0] _cosQ16_T_998 = _cosQ16_T_230 ? $signed(16'sh66cf) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_231 = 16'sh68a6;
  wire [15:0] _cosQ16_T_999 = _cosQ16_T_231 ? $signed(16'sh68a6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_232 = 16'sh6a6d;
  wire [15:0] _cosQ16_T_1000 = _cosQ16_T_232 ? $signed(16'sh6a6d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_233 = 16'sh6c23;
  wire [15:0] _cosQ16_T_1001 = _cosQ16_T_233 ? $signed(16'sh6c23) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_234 = 16'sh6dc9;
  wire [15:0] _cosQ16_T_1002 = _cosQ16_T_234 ? $signed(16'sh6dc9) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_235 = 16'sh6f5e;
  wire [15:0] _cosQ16_T_1003 = _cosQ16_T_235 ? $signed(16'sh6f5e) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_236 = 16'sh70e2;
  wire [15:0] _cosQ16_T_1004 = _cosQ16_T_236 ? $signed(16'sh70e2) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_237 = 16'sh7254;
  wire [15:0] _cosQ16_T_1005 = _cosQ16_T_237 ? $signed(16'sh7254) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_238 = 16'sh73b5;
  wire [15:0] _cosQ16_T_1006 = _cosQ16_T_238 ? $signed(16'sh73b5) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_239 = 16'sh7504;
  wire [15:0] _cosQ16_T_1007 = _cosQ16_T_239 ? $signed(16'sh7504) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_240 = 16'sh7641;
  wire [15:0] _cosQ16_T_1008 = _cosQ16_T_240 ? $signed(16'sh7641) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_241 = 16'sh776b;
  wire [15:0] _cosQ16_T_1009 = _cosQ16_T_241 ? $signed(16'sh776b) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_242 = 16'sh7884;
  wire [15:0] _cosQ16_T_1010 = _cosQ16_T_242 ? $signed(16'sh7884) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_243 = 16'sh7989;
  wire [15:0] _cosQ16_T_1011 = _cosQ16_T_243 ? $signed(16'sh7989) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_244 = 16'sh7a7c;
  wire [15:0] _cosQ16_T_1012 = _cosQ16_T_244 ? $signed(16'sh7a7c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_245 = 16'sh7b5c;
  wire [15:0] _cosQ16_T_1013 = _cosQ16_T_245 ? $signed(16'sh7b5c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_246 = 16'sh7c29;
  wire [15:0] _cosQ16_T_1014 = _cosQ16_T_246 ? $signed(16'sh7c29) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_247 = 16'sh7ce3;
  wire [15:0] _cosQ16_T_1015 = _cosQ16_T_247 ? $signed(16'sh7ce3) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_248 = 16'sh7d89;
  wire [15:0] _cosQ16_T_1016 = _cosQ16_T_248 ? $signed(16'sh7d89) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_249 = 16'sh7e1d;
  wire [15:0] _cosQ16_T_1017 = _cosQ16_T_249 ? $signed(16'sh7e1d) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_250 = 16'sh7e9c;
  wire [15:0] _cosQ16_T_1018 = _cosQ16_T_250 ? $signed(16'sh7e9c) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_251 = 16'sh7f09;
  wire [15:0] _cosQ16_T_1019 = _cosQ16_T_251 ? $signed(16'sh7f09) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_252 = 16'sh7f61;
  wire [15:0] _cosQ16_T_1020 = _cosQ16_T_252 ? $signed(16'sh7f61) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_253 = 16'sh7fa6;
  wire [15:0] _cosQ16_T_1021 = _cosQ16_T_253 ? $signed(16'sh7fa6) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_254 = 16'sh7fd8;
  wire [15:0] _cosQ16_T_1022 = _cosQ16_T_254 ? $signed(16'sh7fd8) : $signed(16'sh0);
  wire [15:0] _cosQ16_WIRE_255 = 16'sh7ff5;
  wire [15:0] _cosQ16_T_1023 = _cosQ16_T_255 ? $signed(16'sh7ff5) : $signed(16'sh0);
  wire [15:0] _cosQ16_T_1024 = $signed(_cosQ16_T_768) | $signed(_cosQ16_T_769);
  wire [15:0] _cosQ16_T_1025 = $signed(_cosQ16_T_768) | $signed(_cosQ16_T_769);
  wire [15:0] _cosQ16_T_1026 = $signed(_cosQ16_T_1025) | $signed(_cosQ16_T_770);
  wire [15:0] _cosQ16_T_1027 = $signed(_cosQ16_T_1025) | $signed(_cosQ16_T_770);
  wire [15:0] _cosQ16_T_1028 = $signed(_cosQ16_T_1027) | $signed(_cosQ16_T_771);
  wire [15:0] _cosQ16_T_1029 = $signed(_cosQ16_T_1027) | $signed(_cosQ16_T_771);
  wire [15:0] _cosQ16_T_1030 = $signed(_cosQ16_T_1029) | $signed(_cosQ16_T_772);
  wire [15:0] _cosQ16_T_1031 = $signed(_cosQ16_T_1029) | $signed(_cosQ16_T_772);
  wire [15:0] _cosQ16_T_1032 = $signed(_cosQ16_T_1031) | $signed(_cosQ16_T_773);
  wire [15:0] _cosQ16_T_1033 = $signed(_cosQ16_T_1031) | $signed(_cosQ16_T_773);
  wire [15:0] _cosQ16_T_1034 = $signed(_cosQ16_T_1033) | $signed(_cosQ16_T_774);
  wire [15:0] _cosQ16_T_1035 = $signed(_cosQ16_T_1033) | $signed(_cosQ16_T_774);
  wire [15:0] _cosQ16_T_1036 = $signed(_cosQ16_T_1035) | $signed(_cosQ16_T_775);
  wire [15:0] _cosQ16_T_1037 = $signed(_cosQ16_T_1035) | $signed(_cosQ16_T_775);
  wire [15:0] _cosQ16_T_1038 = $signed(_cosQ16_T_1037) | $signed(_cosQ16_T_776);
  wire [15:0] _cosQ16_T_1039 = $signed(_cosQ16_T_1037) | $signed(_cosQ16_T_776);
  wire [15:0] _cosQ16_T_1040 = $signed(_cosQ16_T_1039) | $signed(_cosQ16_T_777);
  wire [15:0] _cosQ16_T_1041 = $signed(_cosQ16_T_1039) | $signed(_cosQ16_T_777);
  wire [15:0] _cosQ16_T_1042 = $signed(_cosQ16_T_1041) | $signed(_cosQ16_T_778);
  wire [15:0] _cosQ16_T_1043 = $signed(_cosQ16_T_1041) | $signed(_cosQ16_T_778);
  wire [15:0] _cosQ16_T_1044 = $signed(_cosQ16_T_1043) | $signed(_cosQ16_T_779);
  wire [15:0] _cosQ16_T_1045 = $signed(_cosQ16_T_1043) | $signed(_cosQ16_T_779);
  wire [15:0] _cosQ16_T_1046 = $signed(_cosQ16_T_1045) | $signed(_cosQ16_T_780);
  wire [15:0] _cosQ16_T_1047 = $signed(_cosQ16_T_1045) | $signed(_cosQ16_T_780);
  wire [15:0] _cosQ16_T_1048 = $signed(_cosQ16_T_1047) | $signed(_cosQ16_T_781);
  wire [15:0] _cosQ16_T_1049 = $signed(_cosQ16_T_1047) | $signed(_cosQ16_T_781);
  wire [15:0] _cosQ16_T_1050 = $signed(_cosQ16_T_1049) | $signed(_cosQ16_T_782);
  wire [15:0] _cosQ16_T_1051 = $signed(_cosQ16_T_1049) | $signed(_cosQ16_T_782);
  wire [15:0] _cosQ16_T_1052 = $signed(_cosQ16_T_1051) | $signed(_cosQ16_T_783);
  wire [15:0] _cosQ16_T_1053 = $signed(_cosQ16_T_1051) | $signed(_cosQ16_T_783);
  wire [15:0] _cosQ16_T_1054 = $signed(_cosQ16_T_1053) | $signed(_cosQ16_T_784);
  wire [15:0] _cosQ16_T_1055 = $signed(_cosQ16_T_1053) | $signed(_cosQ16_T_784);
  wire [15:0] _cosQ16_T_1056 = $signed(_cosQ16_T_1055) | $signed(_cosQ16_T_785);
  wire [15:0] _cosQ16_T_1057 = $signed(_cosQ16_T_1055) | $signed(_cosQ16_T_785);
  wire [15:0] _cosQ16_T_1058 = $signed(_cosQ16_T_1057) | $signed(_cosQ16_T_786);
  wire [15:0] _cosQ16_T_1059 = $signed(_cosQ16_T_1057) | $signed(_cosQ16_T_786);
  wire [15:0] _cosQ16_T_1060 = $signed(_cosQ16_T_1059) | $signed(_cosQ16_T_787);
  wire [15:0] _cosQ16_T_1061 = $signed(_cosQ16_T_1059) | $signed(_cosQ16_T_787);
  wire [15:0] _cosQ16_T_1062 = $signed(_cosQ16_T_1061) | $signed(_cosQ16_T_788);
  wire [15:0] _cosQ16_T_1063 = $signed(_cosQ16_T_1061) | $signed(_cosQ16_T_788);
  wire [15:0] _cosQ16_T_1064 = $signed(_cosQ16_T_1063) | $signed(_cosQ16_T_789);
  wire [15:0] _cosQ16_T_1065 = $signed(_cosQ16_T_1063) | $signed(_cosQ16_T_789);
  wire [15:0] _cosQ16_T_1066 = $signed(_cosQ16_T_1065) | $signed(_cosQ16_T_790);
  wire [15:0] _cosQ16_T_1067 = $signed(_cosQ16_T_1065) | $signed(_cosQ16_T_790);
  wire [15:0] _cosQ16_T_1068 = $signed(_cosQ16_T_1067) | $signed(_cosQ16_T_791);
  wire [15:0] _cosQ16_T_1069 = $signed(_cosQ16_T_1067) | $signed(_cosQ16_T_791);
  wire [15:0] _cosQ16_T_1070 = $signed(_cosQ16_T_1069) | $signed(_cosQ16_T_792);
  wire [15:0] _cosQ16_T_1071 = $signed(_cosQ16_T_1069) | $signed(_cosQ16_T_792);
  wire [15:0] _cosQ16_T_1072 = $signed(_cosQ16_T_1071) | $signed(_cosQ16_T_793);
  wire [15:0] _cosQ16_T_1073 = $signed(_cosQ16_T_1071) | $signed(_cosQ16_T_793);
  wire [15:0] _cosQ16_T_1074 = $signed(_cosQ16_T_1073) | $signed(_cosQ16_T_794);
  wire [15:0] _cosQ16_T_1075 = $signed(_cosQ16_T_1073) | $signed(_cosQ16_T_794);
  wire [15:0] _cosQ16_T_1076 = $signed(_cosQ16_T_1075) | $signed(_cosQ16_T_795);
  wire [15:0] _cosQ16_T_1077 = $signed(_cosQ16_T_1075) | $signed(_cosQ16_T_795);
  wire [15:0] _cosQ16_T_1078 = $signed(_cosQ16_T_1077) | $signed(_cosQ16_T_796);
  wire [15:0] _cosQ16_T_1079 = $signed(_cosQ16_T_1077) | $signed(_cosQ16_T_796);
  wire [15:0] _cosQ16_T_1080 = $signed(_cosQ16_T_1079) | $signed(_cosQ16_T_797);
  wire [15:0] _cosQ16_T_1081 = $signed(_cosQ16_T_1079) | $signed(_cosQ16_T_797);
  wire [15:0] _cosQ16_T_1082 = $signed(_cosQ16_T_1081) | $signed(_cosQ16_T_798);
  wire [15:0] _cosQ16_T_1083 = $signed(_cosQ16_T_1081) | $signed(_cosQ16_T_798);
  wire [15:0] _cosQ16_T_1084 = $signed(_cosQ16_T_1083) | $signed(_cosQ16_T_799);
  wire [15:0] _cosQ16_T_1085 = $signed(_cosQ16_T_1083) | $signed(_cosQ16_T_799);
  wire [15:0] _cosQ16_T_1086 = $signed(_cosQ16_T_1085) | $signed(_cosQ16_T_800);
  wire [15:0] _cosQ16_T_1087 = $signed(_cosQ16_T_1085) | $signed(_cosQ16_T_800);
  wire [15:0] _cosQ16_T_1088 = $signed(_cosQ16_T_1087) | $signed(_cosQ16_T_801);
  wire [15:0] _cosQ16_T_1089 = $signed(_cosQ16_T_1087) | $signed(_cosQ16_T_801);
  wire [15:0] _cosQ16_T_1090 = $signed(_cosQ16_T_1089) | $signed(_cosQ16_T_802);
  wire [15:0] _cosQ16_T_1091 = $signed(_cosQ16_T_1089) | $signed(_cosQ16_T_802);
  wire [15:0] _cosQ16_T_1092 = $signed(_cosQ16_T_1091) | $signed(_cosQ16_T_803);
  wire [15:0] _cosQ16_T_1093 = $signed(_cosQ16_T_1091) | $signed(_cosQ16_T_803);
  wire [15:0] _cosQ16_T_1094 = $signed(_cosQ16_T_1093) | $signed(_cosQ16_T_804);
  wire [15:0] _cosQ16_T_1095 = $signed(_cosQ16_T_1093) | $signed(_cosQ16_T_804);
  wire [15:0] _cosQ16_T_1096 = $signed(_cosQ16_T_1095) | $signed(_cosQ16_T_805);
  wire [15:0] _cosQ16_T_1097 = $signed(_cosQ16_T_1095) | $signed(_cosQ16_T_805);
  wire [15:0] _cosQ16_T_1098 = $signed(_cosQ16_T_1097) | $signed(_cosQ16_T_806);
  wire [15:0] _cosQ16_T_1099 = $signed(_cosQ16_T_1097) | $signed(_cosQ16_T_806);
  wire [15:0] _cosQ16_T_1100 = $signed(_cosQ16_T_1099) | $signed(_cosQ16_T_807);
  wire [15:0] _cosQ16_T_1101 = $signed(_cosQ16_T_1099) | $signed(_cosQ16_T_807);
  wire [15:0] _cosQ16_T_1102 = $signed(_cosQ16_T_1101) | $signed(_cosQ16_T_808);
  wire [15:0] _cosQ16_T_1103 = $signed(_cosQ16_T_1101) | $signed(_cosQ16_T_808);
  wire [15:0] _cosQ16_T_1104 = $signed(_cosQ16_T_1103) | $signed(_cosQ16_T_809);
  wire [15:0] _cosQ16_T_1105 = $signed(_cosQ16_T_1103) | $signed(_cosQ16_T_809);
  wire [15:0] _cosQ16_T_1106 = $signed(_cosQ16_T_1105) | $signed(_cosQ16_T_810);
  wire [15:0] _cosQ16_T_1107 = $signed(_cosQ16_T_1105) | $signed(_cosQ16_T_810);
  wire [15:0] _cosQ16_T_1108 = $signed(_cosQ16_T_1107) | $signed(_cosQ16_T_811);
  wire [15:0] _cosQ16_T_1109 = $signed(_cosQ16_T_1107) | $signed(_cosQ16_T_811);
  wire [15:0] _cosQ16_T_1110 = $signed(_cosQ16_T_1109) | $signed(_cosQ16_T_812);
  wire [15:0] _cosQ16_T_1111 = $signed(_cosQ16_T_1109) | $signed(_cosQ16_T_812);
  wire [15:0] _cosQ16_T_1112 = $signed(_cosQ16_T_1111) | $signed(_cosQ16_T_813);
  wire [15:0] _cosQ16_T_1113 = $signed(_cosQ16_T_1111) | $signed(_cosQ16_T_813);
  wire [15:0] _cosQ16_T_1114 = $signed(_cosQ16_T_1113) | $signed(_cosQ16_T_814);
  wire [15:0] _cosQ16_T_1115 = $signed(_cosQ16_T_1113) | $signed(_cosQ16_T_814);
  wire [15:0] _cosQ16_T_1116 = $signed(_cosQ16_T_1115) | $signed(_cosQ16_T_815);
  wire [15:0] _cosQ16_T_1117 = $signed(_cosQ16_T_1115) | $signed(_cosQ16_T_815);
  wire [15:0] _cosQ16_T_1118 = $signed(_cosQ16_T_1117) | $signed(_cosQ16_T_816);
  wire [15:0] _cosQ16_T_1119 = $signed(_cosQ16_T_1117) | $signed(_cosQ16_T_816);
  wire [15:0] _cosQ16_T_1120 = $signed(_cosQ16_T_1119) | $signed(_cosQ16_T_817);
  wire [15:0] _cosQ16_T_1121 = $signed(_cosQ16_T_1119) | $signed(_cosQ16_T_817);
  wire [15:0] _cosQ16_T_1122 = $signed(_cosQ16_T_1121) | $signed(_cosQ16_T_818);
  wire [15:0] _cosQ16_T_1123 = $signed(_cosQ16_T_1121) | $signed(_cosQ16_T_818);
  wire [15:0] _cosQ16_T_1124 = $signed(_cosQ16_T_1123) | $signed(_cosQ16_T_819);
  wire [15:0] _cosQ16_T_1125 = $signed(_cosQ16_T_1123) | $signed(_cosQ16_T_819);
  wire [15:0] _cosQ16_T_1126 = $signed(_cosQ16_T_1125) | $signed(_cosQ16_T_820);
  wire [15:0] _cosQ16_T_1127 = $signed(_cosQ16_T_1125) | $signed(_cosQ16_T_820);
  wire [15:0] _cosQ16_T_1128 = $signed(_cosQ16_T_1127) | $signed(_cosQ16_T_821);
  wire [15:0] _cosQ16_T_1129 = $signed(_cosQ16_T_1127) | $signed(_cosQ16_T_821);
  wire [15:0] _cosQ16_T_1130 = $signed(_cosQ16_T_1129) | $signed(_cosQ16_T_822);
  wire [15:0] _cosQ16_T_1131 = $signed(_cosQ16_T_1129) | $signed(_cosQ16_T_822);
  wire [15:0] _cosQ16_T_1132 = $signed(_cosQ16_T_1131) | $signed(_cosQ16_T_823);
  wire [15:0] _cosQ16_T_1133 = $signed(_cosQ16_T_1131) | $signed(_cosQ16_T_823);
  wire [15:0] _cosQ16_T_1134 = $signed(_cosQ16_T_1133) | $signed(_cosQ16_T_824);
  wire [15:0] _cosQ16_T_1135 = $signed(_cosQ16_T_1133) | $signed(_cosQ16_T_824);
  wire [15:0] _cosQ16_T_1136 = $signed(_cosQ16_T_1135) | $signed(_cosQ16_T_825);
  wire [15:0] _cosQ16_T_1137 = $signed(_cosQ16_T_1135) | $signed(_cosQ16_T_825);
  wire [15:0] _cosQ16_T_1138 = $signed(_cosQ16_T_1137) | $signed(_cosQ16_T_826);
  wire [15:0] _cosQ16_T_1139 = $signed(_cosQ16_T_1137) | $signed(_cosQ16_T_826);
  wire [15:0] _cosQ16_T_1140 = $signed(_cosQ16_T_1139) | $signed(_cosQ16_T_827);
  wire [15:0] _cosQ16_T_1141 = $signed(_cosQ16_T_1139) | $signed(_cosQ16_T_827);
  wire [15:0] _cosQ16_T_1142 = $signed(_cosQ16_T_1141) | $signed(_cosQ16_T_828);
  wire [15:0] _cosQ16_T_1143 = $signed(_cosQ16_T_1141) | $signed(_cosQ16_T_828);
  wire [15:0] _cosQ16_T_1144 = $signed(_cosQ16_T_1143) | $signed(_cosQ16_T_829);
  wire [15:0] _cosQ16_T_1145 = $signed(_cosQ16_T_1143) | $signed(_cosQ16_T_829);
  wire [15:0] _cosQ16_T_1146 = $signed(_cosQ16_T_1145) | $signed(_cosQ16_T_830);
  wire [15:0] _cosQ16_T_1147 = $signed(_cosQ16_T_1145) | $signed(_cosQ16_T_830);
  wire [15:0] _cosQ16_T_1148 = $signed(_cosQ16_T_1147) | $signed(_cosQ16_T_831);
  wire [15:0] _cosQ16_T_1149 = $signed(_cosQ16_T_1147) | $signed(_cosQ16_T_831);
  wire [15:0] _cosQ16_T_1150 = $signed(_cosQ16_T_1147) | $signed(_cosQ16_T_831);
  wire [15:0] _cosQ16_T_1151 = $signed(_cosQ16_T_1147) | $signed(_cosQ16_T_831);
  wire [15:0] _cosQ16_T_1152 = $signed(_cosQ16_T_1151) | $signed(_cosQ16_T_833);
  wire [15:0] _cosQ16_T_1153 = $signed(_cosQ16_T_1151) | $signed(_cosQ16_T_833);
  wire [15:0] _cosQ16_T_1154 = $signed(_cosQ16_T_1153) | $signed(_cosQ16_T_834);
  wire [15:0] _cosQ16_T_1155 = $signed(_cosQ16_T_1153) | $signed(_cosQ16_T_834);
  wire [15:0] _cosQ16_T_1156 = $signed(_cosQ16_T_1155) | $signed(_cosQ16_T_835);
  wire [15:0] _cosQ16_T_1157 = $signed(_cosQ16_T_1155) | $signed(_cosQ16_T_835);
  wire [15:0] _cosQ16_T_1158 = $signed(_cosQ16_T_1157) | $signed(_cosQ16_T_836);
  wire [15:0] _cosQ16_T_1159 = $signed(_cosQ16_T_1157) | $signed(_cosQ16_T_836);
  wire [15:0] _cosQ16_T_1160 = $signed(_cosQ16_T_1159) | $signed(_cosQ16_T_837);
  wire [15:0] _cosQ16_T_1161 = $signed(_cosQ16_T_1159) | $signed(_cosQ16_T_837);
  wire [15:0] _cosQ16_T_1162 = $signed(_cosQ16_T_1161) | $signed(_cosQ16_T_838);
  wire [15:0] _cosQ16_T_1163 = $signed(_cosQ16_T_1161) | $signed(_cosQ16_T_838);
  wire [15:0] _cosQ16_T_1164 = $signed(_cosQ16_T_1163) | $signed(_cosQ16_T_839);
  wire [15:0] _cosQ16_T_1165 = $signed(_cosQ16_T_1163) | $signed(_cosQ16_T_839);
  wire [15:0] _cosQ16_T_1166 = $signed(_cosQ16_T_1165) | $signed(_cosQ16_T_840);
  wire [15:0] _cosQ16_T_1167 = $signed(_cosQ16_T_1165) | $signed(_cosQ16_T_840);
  wire [15:0] _cosQ16_T_1168 = $signed(_cosQ16_T_1167) | $signed(_cosQ16_T_841);
  wire [15:0] _cosQ16_T_1169 = $signed(_cosQ16_T_1167) | $signed(_cosQ16_T_841);
  wire [15:0] _cosQ16_T_1170 = $signed(_cosQ16_T_1169) | $signed(_cosQ16_T_842);
  wire [15:0] _cosQ16_T_1171 = $signed(_cosQ16_T_1169) | $signed(_cosQ16_T_842);
  wire [15:0] _cosQ16_T_1172 = $signed(_cosQ16_T_1171) | $signed(_cosQ16_T_843);
  wire [15:0] _cosQ16_T_1173 = $signed(_cosQ16_T_1171) | $signed(_cosQ16_T_843);
  wire [15:0] _cosQ16_T_1174 = $signed(_cosQ16_T_1173) | $signed(_cosQ16_T_844);
  wire [15:0] _cosQ16_T_1175 = $signed(_cosQ16_T_1173) | $signed(_cosQ16_T_844);
  wire [15:0] _cosQ16_T_1176 = $signed(_cosQ16_T_1175) | $signed(_cosQ16_T_845);
  wire [15:0] _cosQ16_T_1177 = $signed(_cosQ16_T_1175) | $signed(_cosQ16_T_845);
  wire [15:0] _cosQ16_T_1178 = $signed(_cosQ16_T_1177) | $signed(_cosQ16_T_846);
  wire [15:0] _cosQ16_T_1179 = $signed(_cosQ16_T_1177) | $signed(_cosQ16_T_846);
  wire [15:0] _cosQ16_T_1180 = $signed(_cosQ16_T_1179) | $signed(_cosQ16_T_847);
  wire [15:0] _cosQ16_T_1181 = $signed(_cosQ16_T_1179) | $signed(_cosQ16_T_847);
  wire [15:0] _cosQ16_T_1182 = $signed(_cosQ16_T_1181) | $signed(_cosQ16_T_848);
  wire [15:0] _cosQ16_T_1183 = $signed(_cosQ16_T_1181) | $signed(_cosQ16_T_848);
  wire [15:0] _cosQ16_T_1184 = $signed(_cosQ16_T_1183) | $signed(_cosQ16_T_849);
  wire [15:0] _cosQ16_T_1185 = $signed(_cosQ16_T_1183) | $signed(_cosQ16_T_849);
  wire [15:0] _cosQ16_T_1186 = $signed(_cosQ16_T_1185) | $signed(_cosQ16_T_850);
  wire [15:0] _cosQ16_T_1187 = $signed(_cosQ16_T_1185) | $signed(_cosQ16_T_850);
  wire [15:0] _cosQ16_T_1188 = $signed(_cosQ16_T_1187) | $signed(_cosQ16_T_851);
  wire [15:0] _cosQ16_T_1189 = $signed(_cosQ16_T_1187) | $signed(_cosQ16_T_851);
  wire [15:0] _cosQ16_T_1190 = $signed(_cosQ16_T_1189) | $signed(_cosQ16_T_852);
  wire [15:0] _cosQ16_T_1191 = $signed(_cosQ16_T_1189) | $signed(_cosQ16_T_852);
  wire [15:0] _cosQ16_T_1192 = $signed(_cosQ16_T_1191) | $signed(_cosQ16_T_853);
  wire [15:0] _cosQ16_T_1193 = $signed(_cosQ16_T_1191) | $signed(_cosQ16_T_853);
  wire [15:0] _cosQ16_T_1194 = $signed(_cosQ16_T_1193) | $signed(_cosQ16_T_854);
  wire [15:0] _cosQ16_T_1195 = $signed(_cosQ16_T_1193) | $signed(_cosQ16_T_854);
  wire [15:0] _cosQ16_T_1196 = $signed(_cosQ16_T_1195) | $signed(_cosQ16_T_855);
  wire [15:0] _cosQ16_T_1197 = $signed(_cosQ16_T_1195) | $signed(_cosQ16_T_855);
  wire [15:0] _cosQ16_T_1198 = $signed(_cosQ16_T_1197) | $signed(_cosQ16_T_856);
  wire [15:0] _cosQ16_T_1199 = $signed(_cosQ16_T_1197) | $signed(_cosQ16_T_856);
  wire [15:0] _cosQ16_T_1200 = $signed(_cosQ16_T_1199) | $signed(_cosQ16_T_857);
  wire [15:0] _cosQ16_T_1201 = $signed(_cosQ16_T_1199) | $signed(_cosQ16_T_857);
  wire [15:0] _cosQ16_T_1202 = $signed(_cosQ16_T_1201) | $signed(_cosQ16_T_858);
  wire [15:0] _cosQ16_T_1203 = $signed(_cosQ16_T_1201) | $signed(_cosQ16_T_858);
  wire [15:0] _cosQ16_T_1204 = $signed(_cosQ16_T_1203) | $signed(_cosQ16_T_859);
  wire [15:0] _cosQ16_T_1205 = $signed(_cosQ16_T_1203) | $signed(_cosQ16_T_859);
  wire [15:0] _cosQ16_T_1206 = $signed(_cosQ16_T_1205) | $signed(_cosQ16_T_860);
  wire [15:0] _cosQ16_T_1207 = $signed(_cosQ16_T_1205) | $signed(_cosQ16_T_860);
  wire [15:0] _cosQ16_T_1208 = $signed(_cosQ16_T_1207) | $signed(_cosQ16_T_861);
  wire [15:0] _cosQ16_T_1209 = $signed(_cosQ16_T_1207) | $signed(_cosQ16_T_861);
  wire [15:0] _cosQ16_T_1210 = $signed(_cosQ16_T_1209) | $signed(_cosQ16_T_862);
  wire [15:0] _cosQ16_T_1211 = $signed(_cosQ16_T_1209) | $signed(_cosQ16_T_862);
  wire [15:0] _cosQ16_T_1212 = $signed(_cosQ16_T_1211) | $signed(_cosQ16_T_863);
  wire [15:0] _cosQ16_T_1213 = $signed(_cosQ16_T_1211) | $signed(_cosQ16_T_863);
  wire [15:0] _cosQ16_T_1214 = $signed(_cosQ16_T_1213) | $signed(_cosQ16_T_864);
  wire [15:0] _cosQ16_T_1215 = $signed(_cosQ16_T_1213) | $signed(_cosQ16_T_864);
  wire [15:0] _cosQ16_T_1216 = $signed(_cosQ16_T_1215) | $signed(_cosQ16_T_865);
  wire [15:0] _cosQ16_T_1217 = $signed(_cosQ16_T_1215) | $signed(_cosQ16_T_865);
  wire [15:0] _cosQ16_T_1218 = $signed(_cosQ16_T_1217) | $signed(_cosQ16_T_866);
  wire [15:0] _cosQ16_T_1219 = $signed(_cosQ16_T_1217) | $signed(_cosQ16_T_866);
  wire [15:0] _cosQ16_T_1220 = $signed(_cosQ16_T_1219) | $signed(_cosQ16_T_867);
  wire [15:0] _cosQ16_T_1221 = $signed(_cosQ16_T_1219) | $signed(_cosQ16_T_867);
  wire [15:0] _cosQ16_T_1222 = $signed(_cosQ16_T_1221) | $signed(_cosQ16_T_868);
  wire [15:0] _cosQ16_T_1223 = $signed(_cosQ16_T_1221) | $signed(_cosQ16_T_868);
  wire [15:0] _cosQ16_T_1224 = $signed(_cosQ16_T_1223) | $signed(_cosQ16_T_869);
  wire [15:0] _cosQ16_T_1225 = $signed(_cosQ16_T_1223) | $signed(_cosQ16_T_869);
  wire [15:0] _cosQ16_T_1226 = $signed(_cosQ16_T_1225) | $signed(_cosQ16_T_870);
  wire [15:0] _cosQ16_T_1227 = $signed(_cosQ16_T_1225) | $signed(_cosQ16_T_870);
  wire [15:0] _cosQ16_T_1228 = $signed(_cosQ16_T_1227) | $signed(_cosQ16_T_871);
  wire [15:0] _cosQ16_T_1229 = $signed(_cosQ16_T_1227) | $signed(_cosQ16_T_871);
  wire [15:0] _cosQ16_T_1230 = $signed(_cosQ16_T_1229) | $signed(_cosQ16_T_872);
  wire [15:0] _cosQ16_T_1231 = $signed(_cosQ16_T_1229) | $signed(_cosQ16_T_872);
  wire [15:0] _cosQ16_T_1232 = $signed(_cosQ16_T_1231) | $signed(_cosQ16_T_873);
  wire [15:0] _cosQ16_T_1233 = $signed(_cosQ16_T_1231) | $signed(_cosQ16_T_873);
  wire [15:0] _cosQ16_T_1234 = $signed(_cosQ16_T_1233) | $signed(_cosQ16_T_874);
  wire [15:0] _cosQ16_T_1235 = $signed(_cosQ16_T_1233) | $signed(_cosQ16_T_874);
  wire [15:0] _cosQ16_T_1236 = $signed(_cosQ16_T_1235) | $signed(_cosQ16_T_875);
  wire [15:0] _cosQ16_T_1237 = $signed(_cosQ16_T_1235) | $signed(_cosQ16_T_875);
  wire [15:0] _cosQ16_T_1238 = $signed(_cosQ16_T_1237) | $signed(_cosQ16_T_876);
  wire [15:0] _cosQ16_T_1239 = $signed(_cosQ16_T_1237) | $signed(_cosQ16_T_876);
  wire [15:0] _cosQ16_T_1240 = $signed(_cosQ16_T_1239) | $signed(_cosQ16_T_877);
  wire [15:0] _cosQ16_T_1241 = $signed(_cosQ16_T_1239) | $signed(_cosQ16_T_877);
  wire [15:0] _cosQ16_T_1242 = $signed(_cosQ16_T_1241) | $signed(_cosQ16_T_878);
  wire [15:0] _cosQ16_T_1243 = $signed(_cosQ16_T_1241) | $signed(_cosQ16_T_878);
  wire [15:0] _cosQ16_T_1244 = $signed(_cosQ16_T_1243) | $signed(_cosQ16_T_879);
  wire [15:0] _cosQ16_T_1245 = $signed(_cosQ16_T_1243) | $signed(_cosQ16_T_879);
  wire [15:0] _cosQ16_T_1246 = $signed(_cosQ16_T_1245) | $signed(_cosQ16_T_880);
  wire [15:0] _cosQ16_T_1247 = $signed(_cosQ16_T_1245) | $signed(_cosQ16_T_880);
  wire [15:0] _cosQ16_T_1248 = $signed(_cosQ16_T_1247) | $signed(_cosQ16_T_881);
  wire [15:0] _cosQ16_T_1249 = $signed(_cosQ16_T_1247) | $signed(_cosQ16_T_881);
  wire [15:0] _cosQ16_T_1250 = $signed(_cosQ16_T_1249) | $signed(_cosQ16_T_882);
  wire [15:0] _cosQ16_T_1251 = $signed(_cosQ16_T_1249) | $signed(_cosQ16_T_882);
  wire [15:0] _cosQ16_T_1252 = $signed(_cosQ16_T_1251) | $signed(_cosQ16_T_883);
  wire [15:0] _cosQ16_T_1253 = $signed(_cosQ16_T_1251) | $signed(_cosQ16_T_883);
  wire [15:0] _cosQ16_T_1254 = $signed(_cosQ16_T_1253) | $signed(_cosQ16_T_884);
  wire [15:0] _cosQ16_T_1255 = $signed(_cosQ16_T_1253) | $signed(_cosQ16_T_884);
  wire [15:0] _cosQ16_T_1256 = $signed(_cosQ16_T_1255) | $signed(_cosQ16_T_885);
  wire [15:0] _cosQ16_T_1257 = $signed(_cosQ16_T_1255) | $signed(_cosQ16_T_885);
  wire [15:0] _cosQ16_T_1258 = $signed(_cosQ16_T_1257) | $signed(_cosQ16_T_886);
  wire [15:0] _cosQ16_T_1259 = $signed(_cosQ16_T_1257) | $signed(_cosQ16_T_886);
  wire [15:0] _cosQ16_T_1260 = $signed(_cosQ16_T_1259) | $signed(_cosQ16_T_887);
  wire [15:0] _cosQ16_T_1261 = $signed(_cosQ16_T_1259) | $signed(_cosQ16_T_887);
  wire [15:0] _cosQ16_T_1262 = $signed(_cosQ16_T_1261) | $signed(_cosQ16_T_888);
  wire [15:0] _cosQ16_T_1263 = $signed(_cosQ16_T_1261) | $signed(_cosQ16_T_888);
  wire [15:0] _cosQ16_T_1264 = $signed(_cosQ16_T_1263) | $signed(_cosQ16_T_889);
  wire [15:0] _cosQ16_T_1265 = $signed(_cosQ16_T_1263) | $signed(_cosQ16_T_889);
  wire [15:0] _cosQ16_T_1266 = $signed(_cosQ16_T_1265) | $signed(_cosQ16_T_890);
  wire [15:0] _cosQ16_T_1267 = $signed(_cosQ16_T_1265) | $signed(_cosQ16_T_890);
  wire [15:0] _cosQ16_T_1268 = $signed(_cosQ16_T_1267) | $signed(_cosQ16_T_891);
  wire [15:0] _cosQ16_T_1269 = $signed(_cosQ16_T_1267) | $signed(_cosQ16_T_891);
  wire [15:0] _cosQ16_T_1270 = $signed(_cosQ16_T_1269) | $signed(_cosQ16_T_892);
  wire [15:0] _cosQ16_T_1271 = $signed(_cosQ16_T_1269) | $signed(_cosQ16_T_892);
  wire [15:0] _cosQ16_T_1272 = $signed(_cosQ16_T_1271) | $signed(_cosQ16_T_893);
  wire [15:0] _cosQ16_T_1273 = $signed(_cosQ16_T_1271) | $signed(_cosQ16_T_893);
  wire [15:0] _cosQ16_T_1274 = $signed(_cosQ16_T_1273) | $signed(_cosQ16_T_894);
  wire [15:0] _cosQ16_T_1275 = $signed(_cosQ16_T_1273) | $signed(_cosQ16_T_894);
  wire [15:0] _cosQ16_T_1276 = $signed(_cosQ16_T_1275) | $signed(_cosQ16_T_895);
  wire [15:0] _cosQ16_T_1277 = $signed(_cosQ16_T_1275) | $signed(_cosQ16_T_895);
  wire [15:0] _cosQ16_T_1278 = $signed(_cosQ16_T_1277) | $signed(_cosQ16_T_896);
  wire [15:0] _cosQ16_T_1279 = $signed(_cosQ16_T_1277) | $signed(_cosQ16_T_896);
  wire [15:0] _cosQ16_T_1280 = $signed(_cosQ16_T_1279) | $signed(_cosQ16_T_897);
  wire [15:0] _cosQ16_T_1281 = $signed(_cosQ16_T_1279) | $signed(_cosQ16_T_897);
  wire [15:0] _cosQ16_T_1282 = $signed(_cosQ16_T_1281) | $signed(_cosQ16_T_898);
  wire [15:0] _cosQ16_T_1283 = $signed(_cosQ16_T_1281) | $signed(_cosQ16_T_898);
  wire [15:0] _cosQ16_T_1284 = $signed(_cosQ16_T_1283) | $signed(_cosQ16_T_899);
  wire [15:0] _cosQ16_T_1285 = $signed(_cosQ16_T_1283) | $signed(_cosQ16_T_899);
  wire [15:0] _cosQ16_T_1286 = $signed(_cosQ16_T_1285) | $signed(_cosQ16_T_900);
  wire [15:0] _cosQ16_T_1287 = $signed(_cosQ16_T_1285) | $signed(_cosQ16_T_900);
  wire [15:0] _cosQ16_T_1288 = $signed(_cosQ16_T_1287) | $signed(_cosQ16_T_901);
  wire [15:0] _cosQ16_T_1289 = $signed(_cosQ16_T_1287) | $signed(_cosQ16_T_901);
  wire [15:0] _cosQ16_T_1290 = $signed(_cosQ16_T_1289) | $signed(_cosQ16_T_902);
  wire [15:0] _cosQ16_T_1291 = $signed(_cosQ16_T_1289) | $signed(_cosQ16_T_902);
  wire [15:0] _cosQ16_T_1292 = $signed(_cosQ16_T_1291) | $signed(_cosQ16_T_903);
  wire [15:0] _cosQ16_T_1293 = $signed(_cosQ16_T_1291) | $signed(_cosQ16_T_903);
  wire [15:0] _cosQ16_T_1294 = $signed(_cosQ16_T_1293) | $signed(_cosQ16_T_904);
  wire [15:0] _cosQ16_T_1295 = $signed(_cosQ16_T_1293) | $signed(_cosQ16_T_904);
  wire [15:0] _cosQ16_T_1296 = $signed(_cosQ16_T_1295) | $signed(_cosQ16_T_905);
  wire [15:0] _cosQ16_T_1297 = $signed(_cosQ16_T_1295) | $signed(_cosQ16_T_905);
  wire [15:0] _cosQ16_T_1298 = $signed(_cosQ16_T_1297) | $signed(_cosQ16_T_906);
  wire [15:0] _cosQ16_T_1299 = $signed(_cosQ16_T_1297) | $signed(_cosQ16_T_906);
  wire [15:0] _cosQ16_T_1300 = $signed(_cosQ16_T_1299) | $signed(_cosQ16_T_907);
  wire [15:0] _cosQ16_T_1301 = $signed(_cosQ16_T_1299) | $signed(_cosQ16_T_907);
  wire [15:0] _cosQ16_T_1302 = $signed(_cosQ16_T_1301) | $signed(_cosQ16_T_908);
  wire [15:0] _cosQ16_T_1303 = $signed(_cosQ16_T_1301) | $signed(_cosQ16_T_908);
  wire [15:0] _cosQ16_T_1304 = $signed(_cosQ16_T_1303) | $signed(_cosQ16_T_909);
  wire [15:0] _cosQ16_T_1305 = $signed(_cosQ16_T_1303) | $signed(_cosQ16_T_909);
  wire [15:0] _cosQ16_T_1306 = $signed(_cosQ16_T_1305) | $signed(_cosQ16_T_910);
  wire [15:0] _cosQ16_T_1307 = $signed(_cosQ16_T_1305) | $signed(_cosQ16_T_910);
  wire [15:0] _cosQ16_T_1308 = $signed(_cosQ16_T_1307) | $signed(_cosQ16_T_911);
  wire [15:0] _cosQ16_T_1309 = $signed(_cosQ16_T_1307) | $signed(_cosQ16_T_911);
  wire [15:0] _cosQ16_T_1310 = $signed(_cosQ16_T_1309) | $signed(_cosQ16_T_912);
  wire [15:0] _cosQ16_T_1311 = $signed(_cosQ16_T_1309) | $signed(_cosQ16_T_912);
  wire [15:0] _cosQ16_T_1312 = $signed(_cosQ16_T_1311) | $signed(_cosQ16_T_913);
  wire [15:0] _cosQ16_T_1313 = $signed(_cosQ16_T_1311) | $signed(_cosQ16_T_913);
  wire [15:0] _cosQ16_T_1314 = $signed(_cosQ16_T_1313) | $signed(_cosQ16_T_914);
  wire [15:0] _cosQ16_T_1315 = $signed(_cosQ16_T_1313) | $signed(_cosQ16_T_914);
  wire [15:0] _cosQ16_T_1316 = $signed(_cosQ16_T_1315) | $signed(_cosQ16_T_915);
  wire [15:0] _cosQ16_T_1317 = $signed(_cosQ16_T_1315) | $signed(_cosQ16_T_915);
  wire [15:0] _cosQ16_T_1318 = $signed(_cosQ16_T_1317) | $signed(_cosQ16_T_916);
  wire [15:0] _cosQ16_T_1319 = $signed(_cosQ16_T_1317) | $signed(_cosQ16_T_916);
  wire [15:0] _cosQ16_T_1320 = $signed(_cosQ16_T_1319) | $signed(_cosQ16_T_917);
  wire [15:0] _cosQ16_T_1321 = $signed(_cosQ16_T_1319) | $signed(_cosQ16_T_917);
  wire [15:0] _cosQ16_T_1322 = $signed(_cosQ16_T_1321) | $signed(_cosQ16_T_918);
  wire [15:0] _cosQ16_T_1323 = $signed(_cosQ16_T_1321) | $signed(_cosQ16_T_918);
  wire [15:0] _cosQ16_T_1324 = $signed(_cosQ16_T_1323) | $signed(_cosQ16_T_919);
  wire [15:0] _cosQ16_T_1325 = $signed(_cosQ16_T_1323) | $signed(_cosQ16_T_919);
  wire [15:0] _cosQ16_T_1326 = $signed(_cosQ16_T_1325) | $signed(_cosQ16_T_920);
  wire [15:0] _cosQ16_T_1327 = $signed(_cosQ16_T_1325) | $signed(_cosQ16_T_920);
  wire [15:0] _cosQ16_T_1328 = $signed(_cosQ16_T_1327) | $signed(_cosQ16_T_921);
  wire [15:0] _cosQ16_T_1329 = $signed(_cosQ16_T_1327) | $signed(_cosQ16_T_921);
  wire [15:0] _cosQ16_T_1330 = $signed(_cosQ16_T_1329) | $signed(_cosQ16_T_922);
  wire [15:0] _cosQ16_T_1331 = $signed(_cosQ16_T_1329) | $signed(_cosQ16_T_922);
  wire [15:0] _cosQ16_T_1332 = $signed(_cosQ16_T_1331) | $signed(_cosQ16_T_923);
  wire [15:0] _cosQ16_T_1333 = $signed(_cosQ16_T_1331) | $signed(_cosQ16_T_923);
  wire [15:0] _cosQ16_T_1334 = $signed(_cosQ16_T_1333) | $signed(_cosQ16_T_924);
  wire [15:0] _cosQ16_T_1335 = $signed(_cosQ16_T_1333) | $signed(_cosQ16_T_924);
  wire [15:0] _cosQ16_T_1336 = $signed(_cosQ16_T_1335) | $signed(_cosQ16_T_925);
  wire [15:0] _cosQ16_T_1337 = $signed(_cosQ16_T_1335) | $signed(_cosQ16_T_925);
  wire [15:0] _cosQ16_T_1338 = $signed(_cosQ16_T_1337) | $signed(_cosQ16_T_926);
  wire [15:0] _cosQ16_T_1339 = $signed(_cosQ16_T_1337) | $signed(_cosQ16_T_926);
  wire [15:0] _cosQ16_T_1340 = $signed(_cosQ16_T_1339) | $signed(_cosQ16_T_927);
  wire [15:0] _cosQ16_T_1341 = $signed(_cosQ16_T_1339) | $signed(_cosQ16_T_927);
  wire [15:0] _cosQ16_T_1342 = $signed(_cosQ16_T_1341) | $signed(_cosQ16_T_928);
  wire [15:0] _cosQ16_T_1343 = $signed(_cosQ16_T_1341) | $signed(_cosQ16_T_928);
  wire [15:0] _cosQ16_T_1344 = $signed(_cosQ16_T_1343) | $signed(_cosQ16_T_929);
  wire [15:0] _cosQ16_T_1345 = $signed(_cosQ16_T_1343) | $signed(_cosQ16_T_929);
  wire [15:0] _cosQ16_T_1346 = $signed(_cosQ16_T_1345) | $signed(_cosQ16_T_930);
  wire [15:0] _cosQ16_T_1347 = $signed(_cosQ16_T_1345) | $signed(_cosQ16_T_930);
  wire [15:0] _cosQ16_T_1348 = $signed(_cosQ16_T_1347) | $signed(_cosQ16_T_931);
  wire [15:0] _cosQ16_T_1349 = $signed(_cosQ16_T_1347) | $signed(_cosQ16_T_931);
  wire [15:0] _cosQ16_T_1350 = $signed(_cosQ16_T_1349) | $signed(_cosQ16_T_932);
  wire [15:0] _cosQ16_T_1351 = $signed(_cosQ16_T_1349) | $signed(_cosQ16_T_932);
  wire [15:0] _cosQ16_T_1352 = $signed(_cosQ16_T_1351) | $signed(_cosQ16_T_933);
  wire [15:0] _cosQ16_T_1353 = $signed(_cosQ16_T_1351) | $signed(_cosQ16_T_933);
  wire [15:0] _cosQ16_T_1354 = $signed(_cosQ16_T_1353) | $signed(_cosQ16_T_934);
  wire [15:0] _cosQ16_T_1355 = $signed(_cosQ16_T_1353) | $signed(_cosQ16_T_934);
  wire [15:0] _cosQ16_T_1356 = $signed(_cosQ16_T_1355) | $signed(_cosQ16_T_935);
  wire [15:0] _cosQ16_T_1357 = $signed(_cosQ16_T_1355) | $signed(_cosQ16_T_935);
  wire [15:0] _cosQ16_T_1358 = $signed(_cosQ16_T_1357) | $signed(_cosQ16_T_936);
  wire [15:0] _cosQ16_T_1359 = $signed(_cosQ16_T_1357) | $signed(_cosQ16_T_936);
  wire [15:0] _cosQ16_T_1360 = $signed(_cosQ16_T_1359) | $signed(_cosQ16_T_937);
  wire [15:0] _cosQ16_T_1361 = $signed(_cosQ16_T_1359) | $signed(_cosQ16_T_937);
  wire [15:0] _cosQ16_T_1362 = $signed(_cosQ16_T_1361) | $signed(_cosQ16_T_938);
  wire [15:0] _cosQ16_T_1363 = $signed(_cosQ16_T_1361) | $signed(_cosQ16_T_938);
  wire [15:0] _cosQ16_T_1364 = $signed(_cosQ16_T_1363) | $signed(_cosQ16_T_939);
  wire [15:0] _cosQ16_T_1365 = $signed(_cosQ16_T_1363) | $signed(_cosQ16_T_939);
  wire [15:0] _cosQ16_T_1366 = $signed(_cosQ16_T_1365) | $signed(_cosQ16_T_940);
  wire [15:0] _cosQ16_T_1367 = $signed(_cosQ16_T_1365) | $signed(_cosQ16_T_940);
  wire [15:0] _cosQ16_T_1368 = $signed(_cosQ16_T_1367) | $signed(_cosQ16_T_941);
  wire [15:0] _cosQ16_T_1369 = $signed(_cosQ16_T_1367) | $signed(_cosQ16_T_941);
  wire [15:0] _cosQ16_T_1370 = $signed(_cosQ16_T_1369) | $signed(_cosQ16_T_942);
  wire [15:0] _cosQ16_T_1371 = $signed(_cosQ16_T_1369) | $signed(_cosQ16_T_942);
  wire [15:0] _cosQ16_T_1372 = $signed(_cosQ16_T_1371) | $signed(_cosQ16_T_943);
  wire [15:0] _cosQ16_T_1373 = $signed(_cosQ16_T_1371) | $signed(_cosQ16_T_943);
  wire [15:0] _cosQ16_T_1374 = $signed(_cosQ16_T_1373) | $signed(_cosQ16_T_944);
  wire [15:0] _cosQ16_T_1375 = $signed(_cosQ16_T_1373) | $signed(_cosQ16_T_944);
  wire [15:0] _cosQ16_T_1376 = $signed(_cosQ16_T_1375) | $signed(_cosQ16_T_945);
  wire [15:0] _cosQ16_T_1377 = $signed(_cosQ16_T_1375) | $signed(_cosQ16_T_945);
  wire [15:0] _cosQ16_T_1378 = $signed(_cosQ16_T_1377) | $signed(_cosQ16_T_946);
  wire [15:0] _cosQ16_T_1379 = $signed(_cosQ16_T_1377) | $signed(_cosQ16_T_946);
  wire [15:0] _cosQ16_T_1380 = $signed(_cosQ16_T_1379) | $signed(_cosQ16_T_947);
  wire [15:0] _cosQ16_T_1381 = $signed(_cosQ16_T_1379) | $signed(_cosQ16_T_947);
  wire [15:0] _cosQ16_T_1382 = $signed(_cosQ16_T_1381) | $signed(_cosQ16_T_948);
  wire [15:0] _cosQ16_T_1383 = $signed(_cosQ16_T_1381) | $signed(_cosQ16_T_948);
  wire [15:0] _cosQ16_T_1384 = $signed(_cosQ16_T_1383) | $signed(_cosQ16_T_949);
  wire [15:0] _cosQ16_T_1385 = $signed(_cosQ16_T_1383) | $signed(_cosQ16_T_949);
  wire [15:0] _cosQ16_T_1386 = $signed(_cosQ16_T_1385) | $signed(_cosQ16_T_950);
  wire [15:0] _cosQ16_T_1387 = $signed(_cosQ16_T_1385) | $signed(_cosQ16_T_950);
  wire [15:0] _cosQ16_T_1388 = $signed(_cosQ16_T_1387) | $signed(_cosQ16_T_951);
  wire [15:0] _cosQ16_T_1389 = $signed(_cosQ16_T_1387) | $signed(_cosQ16_T_951);
  wire [15:0] _cosQ16_T_1390 = $signed(_cosQ16_T_1389) | $signed(_cosQ16_T_952);
  wire [15:0] _cosQ16_T_1391 = $signed(_cosQ16_T_1389) | $signed(_cosQ16_T_952);
  wire [15:0] _cosQ16_T_1392 = $signed(_cosQ16_T_1391) | $signed(_cosQ16_T_953);
  wire [15:0] _cosQ16_T_1393 = $signed(_cosQ16_T_1391) | $signed(_cosQ16_T_953);
  wire [15:0] _cosQ16_T_1394 = $signed(_cosQ16_T_1393) | $signed(_cosQ16_T_954);
  wire [15:0] _cosQ16_T_1395 = $signed(_cosQ16_T_1393) | $signed(_cosQ16_T_954);
  wire [15:0] _cosQ16_T_1396 = $signed(_cosQ16_T_1395) | $signed(_cosQ16_T_955);
  wire [15:0] _cosQ16_T_1397 = $signed(_cosQ16_T_1395) | $signed(_cosQ16_T_955);
  wire [15:0] _cosQ16_T_1398 = $signed(_cosQ16_T_1397) | $signed(_cosQ16_T_956);
  wire [15:0] _cosQ16_T_1399 = $signed(_cosQ16_T_1397) | $signed(_cosQ16_T_956);
  wire [15:0] _cosQ16_T_1400 = $signed(_cosQ16_T_1399) | $signed(_cosQ16_T_957);
  wire [15:0] _cosQ16_T_1401 = $signed(_cosQ16_T_1399) | $signed(_cosQ16_T_957);
  wire [15:0] _cosQ16_T_1402 = $signed(_cosQ16_T_1401) | $signed(_cosQ16_T_958);
  wire [15:0] _cosQ16_T_1403 = $signed(_cosQ16_T_1401) | $signed(_cosQ16_T_958);
  wire [15:0] _cosQ16_T_1404 = $signed(_cosQ16_T_1403) | $signed(_cosQ16_T_959);
  wire [15:0] _cosQ16_T_1405 = $signed(_cosQ16_T_1403) | $signed(_cosQ16_T_959);
  wire [15:0] _cosQ16_T_1406 = $signed(_cosQ16_T_1403) | $signed(_cosQ16_T_959);
  wire [15:0] _cosQ16_T_1407 = $signed(_cosQ16_T_1403) | $signed(_cosQ16_T_959);
  wire [15:0] _cosQ16_T_1408 = $signed(_cosQ16_T_1407) | $signed(_cosQ16_T_961);
  wire [15:0] _cosQ16_T_1409 = $signed(_cosQ16_T_1407) | $signed(_cosQ16_T_961);
  wire [15:0] _cosQ16_T_1410 = $signed(_cosQ16_T_1409) | $signed(_cosQ16_T_962);
  wire [15:0] _cosQ16_T_1411 = $signed(_cosQ16_T_1409) | $signed(_cosQ16_T_962);
  wire [15:0] _cosQ16_T_1412 = $signed(_cosQ16_T_1411) | $signed(_cosQ16_T_963);
  wire [15:0] _cosQ16_T_1413 = $signed(_cosQ16_T_1411) | $signed(_cosQ16_T_963);
  wire [15:0] _cosQ16_T_1414 = $signed(_cosQ16_T_1413) | $signed(_cosQ16_T_964);
  wire [15:0] _cosQ16_T_1415 = $signed(_cosQ16_T_1413) | $signed(_cosQ16_T_964);
  wire [15:0] _cosQ16_T_1416 = $signed(_cosQ16_T_1415) | $signed(_cosQ16_T_965);
  wire [15:0] _cosQ16_T_1417 = $signed(_cosQ16_T_1415) | $signed(_cosQ16_T_965);
  wire [15:0] _cosQ16_T_1418 = $signed(_cosQ16_T_1417) | $signed(_cosQ16_T_966);
  wire [15:0] _cosQ16_T_1419 = $signed(_cosQ16_T_1417) | $signed(_cosQ16_T_966);
  wire [15:0] _cosQ16_T_1420 = $signed(_cosQ16_T_1419) | $signed(_cosQ16_T_967);
  wire [15:0] _cosQ16_T_1421 = $signed(_cosQ16_T_1419) | $signed(_cosQ16_T_967);
  wire [15:0] _cosQ16_T_1422 = $signed(_cosQ16_T_1421) | $signed(_cosQ16_T_968);
  wire [15:0] _cosQ16_T_1423 = $signed(_cosQ16_T_1421) | $signed(_cosQ16_T_968);
  wire [15:0] _cosQ16_T_1424 = $signed(_cosQ16_T_1423) | $signed(_cosQ16_T_969);
  wire [15:0] _cosQ16_T_1425 = $signed(_cosQ16_T_1423) | $signed(_cosQ16_T_969);
  wire [15:0] _cosQ16_T_1426 = $signed(_cosQ16_T_1425) | $signed(_cosQ16_T_970);
  wire [15:0] _cosQ16_T_1427 = $signed(_cosQ16_T_1425) | $signed(_cosQ16_T_970);
  wire [15:0] _cosQ16_T_1428 = $signed(_cosQ16_T_1427) | $signed(_cosQ16_T_971);
  wire [15:0] _cosQ16_T_1429 = $signed(_cosQ16_T_1427) | $signed(_cosQ16_T_971);
  wire [15:0] _cosQ16_T_1430 = $signed(_cosQ16_T_1429) | $signed(_cosQ16_T_972);
  wire [15:0] _cosQ16_T_1431 = $signed(_cosQ16_T_1429) | $signed(_cosQ16_T_972);
  wire [15:0] _cosQ16_T_1432 = $signed(_cosQ16_T_1431) | $signed(_cosQ16_T_973);
  wire [15:0] _cosQ16_T_1433 = $signed(_cosQ16_T_1431) | $signed(_cosQ16_T_973);
  wire [15:0] _cosQ16_T_1434 = $signed(_cosQ16_T_1433) | $signed(_cosQ16_T_974);
  wire [15:0] _cosQ16_T_1435 = $signed(_cosQ16_T_1433) | $signed(_cosQ16_T_974);
  wire [15:0] _cosQ16_T_1436 = $signed(_cosQ16_T_1435) | $signed(_cosQ16_T_975);
  wire [15:0] _cosQ16_T_1437 = $signed(_cosQ16_T_1435) | $signed(_cosQ16_T_975);
  wire [15:0] _cosQ16_T_1438 = $signed(_cosQ16_T_1437) | $signed(_cosQ16_T_976);
  wire [15:0] _cosQ16_T_1439 = $signed(_cosQ16_T_1437) | $signed(_cosQ16_T_976);
  wire [15:0] _cosQ16_T_1440 = $signed(_cosQ16_T_1439) | $signed(_cosQ16_T_977);
  wire [15:0] _cosQ16_T_1441 = $signed(_cosQ16_T_1439) | $signed(_cosQ16_T_977);
  wire [15:0] _cosQ16_T_1442 = $signed(_cosQ16_T_1441) | $signed(_cosQ16_T_978);
  wire [15:0] _cosQ16_T_1443 = $signed(_cosQ16_T_1441) | $signed(_cosQ16_T_978);
  wire [15:0] _cosQ16_T_1444 = $signed(_cosQ16_T_1443) | $signed(_cosQ16_T_979);
  wire [15:0] _cosQ16_T_1445 = $signed(_cosQ16_T_1443) | $signed(_cosQ16_T_979);
  wire [15:0] _cosQ16_T_1446 = $signed(_cosQ16_T_1445) | $signed(_cosQ16_T_980);
  wire [15:0] _cosQ16_T_1447 = $signed(_cosQ16_T_1445) | $signed(_cosQ16_T_980);
  wire [15:0] _cosQ16_T_1448 = $signed(_cosQ16_T_1447) | $signed(_cosQ16_T_981);
  wire [15:0] _cosQ16_T_1449 = $signed(_cosQ16_T_1447) | $signed(_cosQ16_T_981);
  wire [15:0] _cosQ16_T_1450 = $signed(_cosQ16_T_1449) | $signed(_cosQ16_T_982);
  wire [15:0] _cosQ16_T_1451 = $signed(_cosQ16_T_1449) | $signed(_cosQ16_T_982);
  wire [15:0] _cosQ16_T_1452 = $signed(_cosQ16_T_1451) | $signed(_cosQ16_T_983);
  wire [15:0] _cosQ16_T_1453 = $signed(_cosQ16_T_1451) | $signed(_cosQ16_T_983);
  wire [15:0] _cosQ16_T_1454 = $signed(_cosQ16_T_1453) | $signed(_cosQ16_T_984);
  wire [15:0] _cosQ16_T_1455 = $signed(_cosQ16_T_1453) | $signed(_cosQ16_T_984);
  wire [15:0] _cosQ16_T_1456 = $signed(_cosQ16_T_1455) | $signed(_cosQ16_T_985);
  wire [15:0] _cosQ16_T_1457 = $signed(_cosQ16_T_1455) | $signed(_cosQ16_T_985);
  wire [15:0] _cosQ16_T_1458 = $signed(_cosQ16_T_1457) | $signed(_cosQ16_T_986);
  wire [15:0] _cosQ16_T_1459 = $signed(_cosQ16_T_1457) | $signed(_cosQ16_T_986);
  wire [15:0] _cosQ16_T_1460 = $signed(_cosQ16_T_1459) | $signed(_cosQ16_T_987);
  wire [15:0] _cosQ16_T_1461 = $signed(_cosQ16_T_1459) | $signed(_cosQ16_T_987);
  wire [15:0] _cosQ16_T_1462 = $signed(_cosQ16_T_1461) | $signed(_cosQ16_T_988);
  wire [15:0] _cosQ16_T_1463 = $signed(_cosQ16_T_1461) | $signed(_cosQ16_T_988);
  wire [15:0] _cosQ16_T_1464 = $signed(_cosQ16_T_1463) | $signed(_cosQ16_T_989);
  wire [15:0] _cosQ16_T_1465 = $signed(_cosQ16_T_1463) | $signed(_cosQ16_T_989);
  wire [15:0] _cosQ16_T_1466 = $signed(_cosQ16_T_1465) | $signed(_cosQ16_T_990);
  wire [15:0] _cosQ16_T_1467 = $signed(_cosQ16_T_1465) | $signed(_cosQ16_T_990);
  wire [15:0] _cosQ16_T_1468 = $signed(_cosQ16_T_1467) | $signed(_cosQ16_T_991);
  wire [15:0] _cosQ16_T_1469 = $signed(_cosQ16_T_1467) | $signed(_cosQ16_T_991);
  wire [15:0] _cosQ16_T_1470 = $signed(_cosQ16_T_1469) | $signed(_cosQ16_T_992);
  wire [15:0] _cosQ16_T_1471 = $signed(_cosQ16_T_1469) | $signed(_cosQ16_T_992);
  wire [15:0] _cosQ16_T_1472 = $signed(_cosQ16_T_1471) | $signed(_cosQ16_T_993);
  wire [15:0] _cosQ16_T_1473 = $signed(_cosQ16_T_1471) | $signed(_cosQ16_T_993);
  wire [15:0] _cosQ16_T_1474 = $signed(_cosQ16_T_1473) | $signed(_cosQ16_T_994);
  wire [15:0] _cosQ16_T_1475 = $signed(_cosQ16_T_1473) | $signed(_cosQ16_T_994);
  wire [15:0] _cosQ16_T_1476 = $signed(_cosQ16_T_1475) | $signed(_cosQ16_T_995);
  wire [15:0] _cosQ16_T_1477 = $signed(_cosQ16_T_1475) | $signed(_cosQ16_T_995);
  wire [15:0] _cosQ16_T_1478 = $signed(_cosQ16_T_1477) | $signed(_cosQ16_T_996);
  wire [15:0] _cosQ16_T_1479 = $signed(_cosQ16_T_1477) | $signed(_cosQ16_T_996);
  wire [15:0] _cosQ16_T_1480 = $signed(_cosQ16_T_1479) | $signed(_cosQ16_T_997);
  wire [15:0] _cosQ16_T_1481 = $signed(_cosQ16_T_1479) | $signed(_cosQ16_T_997);
  wire [15:0] _cosQ16_T_1482 = $signed(_cosQ16_T_1481) | $signed(_cosQ16_T_998);
  wire [15:0] _cosQ16_T_1483 = $signed(_cosQ16_T_1481) | $signed(_cosQ16_T_998);
  wire [15:0] _cosQ16_T_1484 = $signed(_cosQ16_T_1483) | $signed(_cosQ16_T_999);
  wire [15:0] _cosQ16_T_1485 = $signed(_cosQ16_T_1483) | $signed(_cosQ16_T_999);
  wire [15:0] _cosQ16_T_1486 = $signed(_cosQ16_T_1485) | $signed(_cosQ16_T_1000);
  wire [15:0] _cosQ16_T_1487 = $signed(_cosQ16_T_1485) | $signed(_cosQ16_T_1000);
  wire [15:0] _cosQ16_T_1488 = $signed(_cosQ16_T_1487) | $signed(_cosQ16_T_1001);
  wire [15:0] _cosQ16_T_1489 = $signed(_cosQ16_T_1487) | $signed(_cosQ16_T_1001);
  wire [15:0] _cosQ16_T_1490 = $signed(_cosQ16_T_1489) | $signed(_cosQ16_T_1002);
  wire [15:0] _cosQ16_T_1491 = $signed(_cosQ16_T_1489) | $signed(_cosQ16_T_1002);
  wire [15:0] _cosQ16_T_1492 = $signed(_cosQ16_T_1491) | $signed(_cosQ16_T_1003);
  wire [15:0] _cosQ16_T_1493 = $signed(_cosQ16_T_1491) | $signed(_cosQ16_T_1003);
  wire [15:0] _cosQ16_T_1494 = $signed(_cosQ16_T_1493) | $signed(_cosQ16_T_1004);
  wire [15:0] _cosQ16_T_1495 = $signed(_cosQ16_T_1493) | $signed(_cosQ16_T_1004);
  wire [15:0] _cosQ16_T_1496 = $signed(_cosQ16_T_1495) | $signed(_cosQ16_T_1005);
  wire [15:0] _cosQ16_T_1497 = $signed(_cosQ16_T_1495) | $signed(_cosQ16_T_1005);
  wire [15:0] _cosQ16_T_1498 = $signed(_cosQ16_T_1497) | $signed(_cosQ16_T_1006);
  wire [15:0] _cosQ16_T_1499 = $signed(_cosQ16_T_1497) | $signed(_cosQ16_T_1006);
  wire [15:0] _cosQ16_T_1500 = $signed(_cosQ16_T_1499) | $signed(_cosQ16_T_1007);
  wire [15:0] _cosQ16_T_1501 = $signed(_cosQ16_T_1499) | $signed(_cosQ16_T_1007);
  wire [15:0] _cosQ16_T_1502 = $signed(_cosQ16_T_1501) | $signed(_cosQ16_T_1008);
  wire [15:0] _cosQ16_T_1503 = $signed(_cosQ16_T_1501) | $signed(_cosQ16_T_1008);
  wire [15:0] _cosQ16_T_1504 = $signed(_cosQ16_T_1503) | $signed(_cosQ16_T_1009);
  wire [15:0] _cosQ16_T_1505 = $signed(_cosQ16_T_1503) | $signed(_cosQ16_T_1009);
  wire [15:0] _cosQ16_T_1506 = $signed(_cosQ16_T_1505) | $signed(_cosQ16_T_1010);
  wire [15:0] _cosQ16_T_1507 = $signed(_cosQ16_T_1505) | $signed(_cosQ16_T_1010);
  wire [15:0] _cosQ16_T_1508 = $signed(_cosQ16_T_1507) | $signed(_cosQ16_T_1011);
  wire [15:0] _cosQ16_T_1509 = $signed(_cosQ16_T_1507) | $signed(_cosQ16_T_1011);
  wire [15:0] _cosQ16_T_1510 = $signed(_cosQ16_T_1509) | $signed(_cosQ16_T_1012);
  wire [15:0] _cosQ16_T_1511 = $signed(_cosQ16_T_1509) | $signed(_cosQ16_T_1012);
  wire [15:0] _cosQ16_T_1512 = $signed(_cosQ16_T_1511) | $signed(_cosQ16_T_1013);
  wire [15:0] _cosQ16_T_1513 = $signed(_cosQ16_T_1511) | $signed(_cosQ16_T_1013);
  wire [15:0] _cosQ16_T_1514 = $signed(_cosQ16_T_1513) | $signed(_cosQ16_T_1014);
  wire [15:0] _cosQ16_T_1515 = $signed(_cosQ16_T_1513) | $signed(_cosQ16_T_1014);
  wire [15:0] _cosQ16_T_1516 = $signed(_cosQ16_T_1515) | $signed(_cosQ16_T_1015);
  wire [15:0] _cosQ16_T_1517 = $signed(_cosQ16_T_1515) | $signed(_cosQ16_T_1015);
  wire [15:0] _cosQ16_T_1518 = $signed(_cosQ16_T_1517) | $signed(_cosQ16_T_1016);
  wire [15:0] _cosQ16_T_1519 = $signed(_cosQ16_T_1517) | $signed(_cosQ16_T_1016);
  wire [15:0] _cosQ16_T_1520 = $signed(_cosQ16_T_1519) | $signed(_cosQ16_T_1017);
  wire [15:0] _cosQ16_T_1521 = $signed(_cosQ16_T_1519) | $signed(_cosQ16_T_1017);
  wire [15:0] _cosQ16_T_1522 = $signed(_cosQ16_T_1521) | $signed(_cosQ16_T_1018);
  wire [15:0] _cosQ16_T_1523 = $signed(_cosQ16_T_1521) | $signed(_cosQ16_T_1018);
  wire [15:0] _cosQ16_T_1524 = $signed(_cosQ16_T_1523) | $signed(_cosQ16_T_1019);
  wire [15:0] _cosQ16_T_1525 = $signed(_cosQ16_T_1523) | $signed(_cosQ16_T_1019);
  wire [15:0] _cosQ16_T_1526 = $signed(_cosQ16_T_1525) | $signed(_cosQ16_T_1020);
  wire [15:0] _cosQ16_T_1527 = $signed(_cosQ16_T_1525) | $signed(_cosQ16_T_1020);
  wire [15:0] _cosQ16_T_1528 = $signed(_cosQ16_T_1527) | $signed(_cosQ16_T_1021);
  wire [15:0] _cosQ16_T_1529 = $signed(_cosQ16_T_1527) | $signed(_cosQ16_T_1021);
  wire [15:0] _cosQ16_T_1530 = $signed(_cosQ16_T_1529) | $signed(_cosQ16_T_1022);
  wire [15:0] _cosQ16_T_1531 = $signed(_cosQ16_T_1529) | $signed(_cosQ16_T_1022);
  wire [15:0] _cosQ16_T_1532 = $signed(_cosQ16_T_1531) | $signed(_cosQ16_T_1023);
  wire [15:0] _cosQ16_T_1533 = $signed(_cosQ16_T_1531) | $signed(_cosQ16_T_1023);
  wire [15:0] _cosQ16_T_1534 = $signed(_cosQ16_T_1531) | $signed(_cosQ16_T_1023);
  wire [15:0] cosQ16 = $signed(_cosQ16_T_1531) | $signed(_cosQ16_T_1023);
  wire  _mQ8_T = io_modIdx == 3'h0;
  wire  _mQ8_T_1 = io_modIdx == 3'h1;
  wire  _mQ8_T_2 = io_modIdx == 3'h2;
  wire  _mQ8_T_3 = io_modIdx == 3'h3;
  wire  _mQ8_T_4 = io_modIdx == 3'h4;
  wire  _mQ8_T_5 = io_modIdx == 3'h5;
  wire  _mQ8_T_6 = io_modIdx == 3'h6;
  wire [7:0] _mQ8_T_7 = _mQ8_T ? 8'h4d : 8'h0;
  wire [7:0] _mQ8_T_8 = _mQ8_T_1 ? 8'h66 : 8'h0;
  wire [7:0] _mQ8_T_9 = _mQ8_T_2 ? 8'h80 : 8'h0;
  wire [7:0] _mQ8_T_10 = _mQ8_T_3 ? 8'h9a : 8'h0;
  wire [7:0] _mQ8_T_11 = _mQ8_T_4 ? 8'hb3 : 8'h0;
  wire [7:0] _mQ8_T_12 = _mQ8_T_5 ? 8'hcd : 8'h0;
  wire [7:0] _mQ8_T_13 = _mQ8_T_6 ? 8'he6 : 8'h0;
  wire [7:0] _mQ8_T_14 = _mQ8_T_7 | _mQ8_T_8;
  wire [7:0] _mQ8_T_15 = _mQ8_T_14 | _mQ8_T_9;
  wire [7:0] _mQ8_T_16 = _mQ8_T_15 | _mQ8_T_10;
  wire [7:0] _mQ8_T_17 = _mQ8_T_16 | _mQ8_T_11;
  wire [7:0] _mQ8_T_18 = _mQ8_T_17 | _mQ8_T_12;
  wire [7:0] _mQ8_T_19 = _mQ8_T_18 | _mQ8_T_13;
  reg [7:0] mQ8;
  wire [8:0] _cosTimesM_T = {1'b0,$signed(mQ8)};
  wire [15:0] _cosQ16_T_1535 = cosQ16;
  wire [24:0] _cosTimesM_T_1 = $signed(cosQ16) * $signed(_cosTimesM_T);
  wire [16:0] cosTimesM = _cosTimesM_T_1[24:8];
  wire [17:0] _mdRaw_T = $signed(cosTimesM) + 17'sh8000;
  wire [16:0] _mdRaw_T_1 = _mdRaw_T[16:0];
  wire [16:0] mdRaw = $signed(cosTimesM) + 17'sh8000;
  wire  mdData_lo = $signed(mdRaw) < 17'sh0;
  wire  mdData_hi = 1'h0;
  wire [16:0] _mdData_clipped_T = mdRaw;
  wire [16:0] mdData_clipped = mdData_lo ? $signed(17'sh0) : $signed(mdRaw);
  wire [16:0] mdData = mdData_lo ? $signed(17'sh0) : $signed(mdRaw);
  reg [5:0] usCnt;
  wire  usTickRaw = usCnt == 6'h31;
  wire [6:0] _usCnt_T = usCnt + 6'h1;
  wire [5:0] _usCnt_T_1 = usCnt + 6'h1;
  wire [5:0] _GEN_0 = usTickRaw ? 6'h0 : _usCnt_T_1;
  reg  usTick;
  wire  _T = io_delayIdx == 3'h0;
  wire [7:0] _GEN_1 = 8'h32;
  wire  _T_1 = io_delayIdx == 3'h1;
  wire [7:0] _GEN_2 = io_delayIdx == 3'h1 ? 8'h50 : 8'h32;
  wire  _T_2 = io_delayIdx == 3'h2;
  wire [7:0] _GEN_3 = io_delayIdx == 3'h2 ? 8'h6e : _GEN_2;
  wire  _T_3 = io_delayIdx == 3'h3;
  wire [7:0] _GEN_4 = io_delayIdx == 3'h3 ? 8'h8c : _GEN_3;
  wire  _T_4 = io_delayIdx == 3'h4;
  wire [7:0] _GEN_5 = io_delayIdx == 3'h4 ? 8'haa : _GEN_4;
  wire  _T_5 = io_delayIdx == 3'h5;
  wire [7:0] delayDepth = io_delayIdx == 3'h5 ? 8'hc8 : _GEN_5;
  reg [15:0] sr_0;
  reg [15:0] sr_1;
  reg [15:0] sr_2;
  reg [15:0] sr_3;
  reg [15:0] sr_4;
  reg [15:0] sr_5;
  reg [15:0] sr_6;
  reg [15:0] sr_7;
  reg [15:0] sr_8;
  reg [15:0] sr_9;
  reg [15:0] sr_10;
  reg [15:0] sr_11;
  reg [15:0] sr_12;
  reg [15:0] sr_13;
  reg [15:0] sr_14;
  reg [15:0] sr_15;
  reg [15:0] sr_16;
  reg [15:0] sr_17;
  reg [15:0] sr_18;
  reg [15:0] sr_19;
  reg [15:0] sr_20;
  reg [15:0] sr_21;
  reg [15:0] sr_22;
  reg [15:0] sr_23;
  reg [15:0] sr_24;
  reg [15:0] sr_25;
  reg [15:0] sr_26;
  reg [15:0] sr_27;
  reg [15:0] sr_28;
  reg [15:0] sr_29;
  reg [15:0] sr_30;
  reg [15:0] sr_31;
  reg [15:0] sr_32;
  reg [15:0] sr_33;
  reg [15:0] sr_34;
  reg [15:0] sr_35;
  reg [15:0] sr_36;
  reg [15:0] sr_37;
  reg [15:0] sr_38;
  reg [15:0] sr_39;
  reg [15:0] sr_40;
  reg [15:0] sr_41;
  reg [15:0] sr_42;
  reg [15:0] sr_43;
  reg [15:0] sr_44;
  reg [15:0] sr_45;
  reg [15:0] sr_46;
  reg [15:0] sr_47;
  reg [15:0] sr_48;
  reg [15:0] sr_49;
  reg [15:0] sr_50;
  reg [15:0] sr_51;
  reg [15:0] sr_52;
  reg [15:0] sr_53;
  reg [15:0] sr_54;
  reg [15:0] sr_55;
  reg [15:0] sr_56;
  reg [15:0] sr_57;
  reg [15:0] sr_58;
  reg [15:0] sr_59;
  reg [15:0] sr_60;
  reg [15:0] sr_61;
  reg [15:0] sr_62;
  reg [15:0] sr_63;
  reg [15:0] sr_64;
  reg [15:0] sr_65;
  reg [15:0] sr_66;
  reg [15:0] sr_67;
  reg [15:0] sr_68;
  reg [15:0] sr_69;
  reg [15:0] sr_70;
  reg [15:0] sr_71;
  reg [15:0] sr_72;
  reg [15:0] sr_73;
  reg [15:0] sr_74;
  reg [15:0] sr_75;
  reg [15:0] sr_76;
  reg [15:0] sr_77;
  reg [15:0] sr_78;
  reg [15:0] sr_79;
  reg [15:0] sr_80;
  reg [15:0] sr_81;
  reg [15:0] sr_82;
  reg [15:0] sr_83;
  reg [15:0] sr_84;
  reg [15:0] sr_85;
  reg [15:0] sr_86;
  reg [15:0] sr_87;
  reg [15:0] sr_88;
  reg [15:0] sr_89;
  reg [15:0] sr_90;
  reg [15:0] sr_91;
  reg [15:0] sr_92;
  reg [15:0] sr_93;
  reg [15:0] sr_94;
  reg [15:0] sr_95;
  reg [15:0] sr_96;
  reg [15:0] sr_97;
  reg [15:0] sr_98;
  reg [15:0] sr_99;
  reg [15:0] sr_100;
  reg [15:0] sr_101;
  reg [15:0] sr_102;
  reg [15:0] sr_103;
  reg [15:0] sr_104;
  reg [15:0] sr_105;
  reg [15:0] sr_106;
  reg [15:0] sr_107;
  reg [15:0] sr_108;
  reg [15:0] sr_109;
  reg [15:0] sr_110;
  reg [15:0] sr_111;
  reg [15:0] sr_112;
  reg [15:0] sr_113;
  reg [15:0] sr_114;
  reg [15:0] sr_115;
  reg [15:0] sr_116;
  reg [15:0] sr_117;
  reg [15:0] sr_118;
  reg [15:0] sr_119;
  reg [15:0] sr_120;
  reg [15:0] sr_121;
  reg [15:0] sr_122;
  reg [15:0] sr_123;
  reg [15:0] sr_124;
  reg [15:0] sr_125;
  reg [15:0] sr_126;
  reg [15:0] sr_127;
  reg [15:0] sr_128;
  reg [15:0] sr_129;
  reg [15:0] sr_130;
  reg [15:0] sr_131;
  reg [15:0] sr_132;
  reg [15:0] sr_133;
  reg [15:0] sr_134;
  reg [15:0] sr_135;
  reg [15:0] sr_136;
  reg [15:0] sr_137;
  reg [15:0] sr_138;
  reg [15:0] sr_139;
  reg [15:0] sr_140;
  reg [15:0] sr_141;
  reg [15:0] sr_142;
  reg [15:0] sr_143;
  reg [15:0] sr_144;
  reg [15:0] sr_145;
  reg [15:0] sr_146;
  reg [15:0] sr_147;
  reg [15:0] sr_148;
  reg [15:0] sr_149;
  reg [15:0] sr_150;
  reg [15:0] sr_151;
  reg [15:0] sr_152;
  reg [15:0] sr_153;
  reg [15:0] sr_154;
  reg [15:0] sr_155;
  reg [15:0] sr_156;
  reg [15:0] sr_157;
  reg [15:0] sr_158;
  reg [15:0] sr_159;
  reg [15:0] sr_160;
  reg [15:0] sr_161;
  reg [15:0] sr_162;
  reg [15:0] sr_163;
  reg [15:0] sr_164;
  reg [15:0] sr_165;
  reg [15:0] sr_166;
  reg [15:0] sr_167;
  reg [15:0] sr_168;
  reg [15:0] sr_169;
  reg [15:0] sr_170;
  reg [15:0] sr_171;
  reg [15:0] sr_172;
  reg [15:0] sr_173;
  reg [15:0] sr_174;
  reg [15:0] sr_175;
  reg [15:0] sr_176;
  reg [15:0] sr_177;
  reg [15:0] sr_178;
  reg [15:0] sr_179;
  reg [15:0] sr_180;
  reg [15:0] sr_181;
  reg [15:0] sr_182;
  reg [15:0] sr_183;
  reg [15:0] sr_184;
  reg [15:0] sr_185;
  reg [15:0] sr_186;
  reg [15:0] sr_187;
  reg [15:0] sr_188;
  reg [15:0] sr_189;
  reg [15:0] sr_190;
  reg [15:0] sr_191;
  reg [15:0] sr_192;
  reg [15:0] sr_193;
  reg [15:0] sr_194;
  reg [15:0] sr_195;
  reg [15:0] sr_196;
  reg [15:0] sr_197;
  reg [15:0] sr_198;
  reg [15:0] sr_199;
  wire [15:0] _GEN_7 = usTick ? sr_198 : sr_199;
  wire [15:0] _GEN_8 = usTick ? sr_197 : sr_198;
  wire [15:0] _GEN_9 = usTick ? sr_196 : sr_197;
  wire [15:0] _GEN_10 = usTick ? sr_195 : sr_196;
  wire [15:0] _GEN_11 = usTick ? sr_194 : sr_195;
  wire [15:0] _GEN_12 = usTick ? sr_193 : sr_194;
  wire [15:0] _GEN_13 = usTick ? sr_192 : sr_193;
  wire [15:0] _GEN_14 = usTick ? sr_191 : sr_192;
  wire [15:0] _GEN_15 = usTick ? sr_190 : sr_191;
  wire [15:0] _GEN_16 = usTick ? sr_189 : sr_190;
  wire [15:0] _GEN_17 = usTick ? sr_188 : sr_189;
  wire [15:0] _GEN_18 = usTick ? sr_187 : sr_188;
  wire [15:0] _GEN_19 = usTick ? sr_186 : sr_187;
  wire [15:0] _GEN_20 = usTick ? sr_185 : sr_186;
  wire [15:0] _GEN_21 = usTick ? sr_184 : sr_185;
  wire [15:0] _GEN_22 = usTick ? sr_183 : sr_184;
  wire [15:0] _GEN_23 = usTick ? sr_182 : sr_183;
  wire [15:0] _GEN_24 = usTick ? sr_181 : sr_182;
  wire [15:0] _GEN_25 = usTick ? sr_180 : sr_181;
  wire [15:0] _GEN_26 = usTick ? sr_179 : sr_180;
  wire [15:0] _GEN_27 = usTick ? sr_178 : sr_179;
  wire [15:0] _GEN_28 = usTick ? sr_177 : sr_178;
  wire [15:0] _GEN_29 = usTick ? sr_176 : sr_177;
  wire [15:0] _GEN_30 = usTick ? sr_175 : sr_176;
  wire [15:0] _GEN_31 = usTick ? sr_174 : sr_175;
  wire [15:0] _GEN_32 = usTick ? sr_173 : sr_174;
  wire [15:0] _GEN_33 = usTick ? sr_172 : sr_173;
  wire [15:0] _GEN_34 = usTick ? sr_171 : sr_172;
  wire [15:0] _GEN_35 = usTick ? sr_170 : sr_171;
  wire [15:0] _GEN_36 = usTick ? sr_169 : sr_170;
  wire [15:0] _GEN_37 = usTick ? sr_168 : sr_169;
  wire [15:0] _GEN_38 = usTick ? sr_167 : sr_168;
  wire [15:0] _GEN_39 = usTick ? sr_166 : sr_167;
  wire [15:0] _GEN_40 = usTick ? sr_165 : sr_166;
  wire [15:0] _GEN_41 = usTick ? sr_164 : sr_165;
  wire [15:0] _GEN_42 = usTick ? sr_163 : sr_164;
  wire [15:0] _GEN_43 = usTick ? sr_162 : sr_163;
  wire [15:0] _GEN_44 = usTick ? sr_161 : sr_162;
  wire [15:0] _GEN_45 = usTick ? sr_160 : sr_161;
  wire [15:0] _GEN_46 = usTick ? sr_159 : sr_160;
  wire [15:0] _GEN_47 = usTick ? sr_158 : sr_159;
  wire [15:0] _GEN_48 = usTick ? sr_157 : sr_158;
  wire [15:0] _GEN_49 = usTick ? sr_156 : sr_157;
  wire [15:0] _GEN_50 = usTick ? sr_155 : sr_156;
  wire [15:0] _GEN_51 = usTick ? sr_154 : sr_155;
  wire [15:0] _GEN_52 = usTick ? sr_153 : sr_154;
  wire [15:0] _GEN_53 = usTick ? sr_152 : sr_153;
  wire [15:0] _GEN_54 = usTick ? sr_151 : sr_152;
  wire [15:0] _GEN_55 = usTick ? sr_150 : sr_151;
  wire [15:0] _GEN_56 = usTick ? sr_149 : sr_150;
  wire [15:0] _GEN_57 = usTick ? sr_148 : sr_149;
  wire [15:0] _GEN_58 = usTick ? sr_147 : sr_148;
  wire [15:0] _GEN_59 = usTick ? sr_146 : sr_147;
  wire [15:0] _GEN_60 = usTick ? sr_145 : sr_146;
  wire [15:0] _GEN_61 = usTick ? sr_144 : sr_145;
  wire [15:0] _GEN_62 = usTick ? sr_143 : sr_144;
  wire [15:0] _GEN_63 = usTick ? sr_142 : sr_143;
  wire [15:0] _GEN_64 = usTick ? sr_141 : sr_142;
  wire [15:0] _GEN_65 = usTick ? sr_140 : sr_141;
  wire [15:0] _GEN_66 = usTick ? sr_139 : sr_140;
  wire [15:0] _GEN_67 = usTick ? sr_138 : sr_139;
  wire [15:0] _GEN_68 = usTick ? sr_137 : sr_138;
  wire [15:0] _GEN_69 = usTick ? sr_136 : sr_137;
  wire [15:0] _GEN_70 = usTick ? sr_135 : sr_136;
  wire [15:0] _GEN_71 = usTick ? sr_134 : sr_135;
  wire [15:0] _GEN_72 = usTick ? sr_133 : sr_134;
  wire [15:0] _GEN_73 = usTick ? sr_132 : sr_133;
  wire [15:0] _GEN_74 = usTick ? sr_131 : sr_132;
  wire [15:0] _GEN_75 = usTick ? sr_130 : sr_131;
  wire [15:0] _GEN_76 = usTick ? sr_129 : sr_130;
  wire [15:0] _GEN_77 = usTick ? sr_128 : sr_129;
  wire [15:0] _GEN_78 = usTick ? sr_127 : sr_128;
  wire [15:0] _GEN_79 = usTick ? sr_126 : sr_127;
  wire [15:0] _GEN_80 = usTick ? sr_125 : sr_126;
  wire [15:0] _GEN_81 = usTick ? sr_124 : sr_125;
  wire [15:0] _GEN_82 = usTick ? sr_123 : sr_124;
  wire [15:0] _GEN_83 = usTick ? sr_122 : sr_123;
  wire [15:0] _GEN_84 = usTick ? sr_121 : sr_122;
  wire [15:0] _GEN_85 = usTick ? sr_120 : sr_121;
  wire [15:0] _GEN_86 = usTick ? sr_119 : sr_120;
  wire [15:0] _GEN_87 = usTick ? sr_118 : sr_119;
  wire [15:0] _GEN_88 = usTick ? sr_117 : sr_118;
  wire [15:0] _GEN_89 = usTick ? sr_116 : sr_117;
  wire [15:0] _GEN_90 = usTick ? sr_115 : sr_116;
  wire [15:0] _GEN_91 = usTick ? sr_114 : sr_115;
  wire [15:0] _GEN_92 = usTick ? sr_113 : sr_114;
  wire [15:0] _GEN_93 = usTick ? sr_112 : sr_113;
  wire [15:0] _GEN_94 = usTick ? sr_111 : sr_112;
  wire [15:0] _GEN_95 = usTick ? sr_110 : sr_111;
  wire [15:0] _GEN_96 = usTick ? sr_109 : sr_110;
  wire [15:0] _GEN_97 = usTick ? sr_108 : sr_109;
  wire [15:0] _GEN_98 = usTick ? sr_107 : sr_108;
  wire [15:0] _GEN_99 = usTick ? sr_106 : sr_107;
  wire [15:0] _GEN_100 = usTick ? sr_105 : sr_106;
  wire [15:0] _GEN_101 = usTick ? sr_104 : sr_105;
  wire [15:0] _GEN_102 = usTick ? sr_103 : sr_104;
  wire [15:0] _GEN_103 = usTick ? sr_102 : sr_103;
  wire [15:0] _GEN_104 = usTick ? sr_101 : sr_102;
  wire [15:0] _GEN_105 = usTick ? sr_100 : sr_101;
  wire [15:0] _GEN_106 = usTick ? sr_99 : sr_100;
  wire [15:0] _GEN_107 = usTick ? sr_98 : sr_99;
  wire [15:0] _GEN_108 = usTick ? sr_97 : sr_98;
  wire [15:0] _GEN_109 = usTick ? sr_96 : sr_97;
  wire [15:0] _GEN_110 = usTick ? sr_95 : sr_96;
  wire [15:0] _GEN_111 = usTick ? sr_94 : sr_95;
  wire [15:0] _GEN_112 = usTick ? sr_93 : sr_94;
  wire [15:0] _GEN_113 = usTick ? sr_92 : sr_93;
  wire [15:0] _GEN_114 = usTick ? sr_91 : sr_92;
  wire [15:0] _GEN_115 = usTick ? sr_90 : sr_91;
  wire [15:0] _GEN_116 = usTick ? sr_89 : sr_90;
  wire [15:0] _GEN_117 = usTick ? sr_88 : sr_89;
  wire [15:0] _GEN_118 = usTick ? sr_87 : sr_88;
  wire [15:0] _GEN_119 = usTick ? sr_86 : sr_87;
  wire [15:0] _GEN_120 = usTick ? sr_85 : sr_86;
  wire [15:0] _GEN_121 = usTick ? sr_84 : sr_85;
  wire [15:0] _GEN_122 = usTick ? sr_83 : sr_84;
  wire [15:0] _GEN_123 = usTick ? sr_82 : sr_83;
  wire [15:0] _GEN_124 = usTick ? sr_81 : sr_82;
  wire [15:0] _GEN_125 = usTick ? sr_80 : sr_81;
  wire [15:0] _GEN_126 = usTick ? sr_79 : sr_80;
  wire [15:0] _GEN_127 = usTick ? sr_78 : sr_79;
  wire [15:0] _GEN_128 = usTick ? sr_77 : sr_78;
  wire [15:0] _GEN_129 = usTick ? sr_76 : sr_77;
  wire [15:0] _GEN_130 = usTick ? sr_75 : sr_76;
  wire [15:0] _GEN_131 = usTick ? sr_74 : sr_75;
  wire [15:0] _GEN_132 = usTick ? sr_73 : sr_74;
  wire [15:0] _GEN_133 = usTick ? sr_72 : sr_73;
  wire [15:0] _GEN_134 = usTick ? sr_71 : sr_72;
  wire [15:0] _GEN_135 = usTick ? sr_70 : sr_71;
  wire [15:0] _GEN_136 = usTick ? sr_69 : sr_70;
  wire [15:0] _GEN_137 = usTick ? sr_68 : sr_69;
  wire [15:0] _GEN_138 = usTick ? sr_67 : sr_68;
  wire [15:0] _GEN_139 = usTick ? sr_66 : sr_67;
  wire [15:0] _GEN_140 = usTick ? sr_65 : sr_66;
  wire [15:0] _GEN_141 = usTick ? sr_64 : sr_65;
  wire [15:0] _GEN_142 = usTick ? sr_63 : sr_64;
  wire [15:0] _GEN_143 = usTick ? sr_62 : sr_63;
  wire [15:0] _GEN_144 = usTick ? sr_61 : sr_62;
  wire [15:0] _GEN_145 = usTick ? sr_60 : sr_61;
  wire [15:0] _GEN_146 = usTick ? sr_59 : sr_60;
  wire [15:0] _GEN_147 = usTick ? sr_58 : sr_59;
  wire [15:0] _GEN_148 = usTick ? sr_57 : sr_58;
  wire [15:0] _GEN_149 = usTick ? sr_56 : sr_57;
  wire [15:0] _GEN_150 = usTick ? sr_55 : sr_56;
  wire [15:0] _GEN_151 = usTick ? sr_54 : sr_55;
  wire [15:0] _GEN_152 = usTick ? sr_53 : sr_54;
  wire [15:0] _GEN_153 = usTick ? sr_52 : sr_53;
  wire [15:0] _GEN_154 = usTick ? sr_51 : sr_52;
  wire [15:0] _GEN_155 = usTick ? sr_50 : sr_51;
  wire [15:0] _GEN_156 = usTick ? sr_49 : sr_50;
  wire [15:0] _GEN_157 = usTick ? sr_48 : sr_49;
  wire [15:0] _GEN_158 = usTick ? sr_47 : sr_48;
  wire [15:0] _GEN_159 = usTick ? sr_46 : sr_47;
  wire [15:0] _GEN_160 = usTick ? sr_45 : sr_46;
  wire [15:0] _GEN_161 = usTick ? sr_44 : sr_45;
  wire [15:0] _GEN_162 = usTick ? sr_43 : sr_44;
  wire [15:0] _GEN_163 = usTick ? sr_42 : sr_43;
  wire [15:0] _GEN_164 = usTick ? sr_41 : sr_42;
  wire [15:0] _GEN_165 = usTick ? sr_40 : sr_41;
  wire [15:0] _GEN_166 = usTick ? sr_39 : sr_40;
  wire [15:0] _GEN_167 = usTick ? sr_38 : sr_39;
  wire [15:0] _GEN_168 = usTick ? sr_37 : sr_38;
  wire [15:0] _GEN_169 = usTick ? sr_36 : sr_37;
  wire [15:0] _GEN_170 = usTick ? sr_35 : sr_36;
  wire [15:0] _GEN_171 = usTick ? sr_34 : sr_35;
  wire [15:0] _GEN_172 = usTick ? sr_33 : sr_34;
  wire [15:0] _GEN_173 = usTick ? sr_32 : sr_33;
  wire [15:0] _GEN_174 = usTick ? sr_31 : sr_32;
  wire [15:0] _GEN_175 = usTick ? sr_30 : sr_31;
  wire [15:0] _GEN_176 = usTick ? sr_29 : sr_30;
  wire [15:0] _GEN_177 = usTick ? sr_28 : sr_29;
  wire [15:0] _GEN_178 = usTick ? sr_27 : sr_28;
  wire [15:0] _GEN_179 = usTick ? sr_26 : sr_27;
  wire [15:0] _GEN_180 = usTick ? sr_25 : sr_26;
  wire [15:0] _GEN_181 = usTick ? sr_24 : sr_25;
  wire [15:0] _GEN_182 = usTick ? sr_23 : sr_24;
  wire [15:0] _GEN_183 = usTick ? sr_22 : sr_23;
  wire [15:0] _GEN_184 = usTick ? sr_21 : sr_22;
  wire [15:0] _GEN_185 = usTick ? sr_20 : sr_21;
  wire [15:0] _GEN_186 = usTick ? sr_19 : sr_20;
  wire [15:0] _GEN_187 = usTick ? sr_18 : sr_19;
  wire [15:0] _GEN_188 = usTick ? sr_17 : sr_18;
  wire [15:0] _GEN_189 = usTick ? sr_16 : sr_17;
  wire [15:0] _GEN_190 = usTick ? sr_15 : sr_16;
  wire [15:0] _GEN_191 = usTick ? sr_14 : sr_15;
  wire [15:0] _GEN_192 = usTick ? sr_13 : sr_14;
  wire [15:0] _GEN_193 = usTick ? sr_12 : sr_13;
  wire [15:0] _GEN_194 = usTick ? sr_11 : sr_12;
  wire [15:0] _GEN_195 = usTick ? sr_10 : sr_11;
  wire [15:0] _GEN_196 = usTick ? sr_9 : sr_10;
  wire [15:0] _GEN_197 = usTick ? sr_8 : sr_9;
  wire [15:0] _GEN_198 = usTick ? sr_7 : sr_8;
  wire [15:0] _GEN_199 = usTick ? sr_6 : sr_7;
  wire [15:0] _GEN_200 = usTick ? sr_5 : sr_6;
  wire [15:0] _GEN_201 = usTick ? sr_4 : sr_5;
  wire [15:0] _GEN_202 = usTick ? sr_3 : sr_4;
  wire [15:0] _GEN_203 = usTick ? sr_2 : sr_3;
  wire [15:0] _GEN_204 = usTick ? sr_1 : sr_2;
  wire [15:0] _GEN_205 = usTick ? sr_0 : sr_1;
  wire [16:0] _GEN_206 = usTick ? mdData : {{1'd0}, sr_0};
  wire [7:0] _GEN_6 = delayDepth;
  wire [8:0] _srSel_T = delayDepth - 8'h1;
  wire [7:0] srSel = delayDepth - 8'h1;
  wire  _alphaQ8_T = io_attenIdx == 4'h0;
  wire  _alphaQ8_T_1 = io_attenIdx == 4'h1;
  wire  _alphaQ8_T_2 = io_attenIdx == 4'h2;
  wire  _alphaQ8_T_3 = io_attenIdx == 4'h3;
  wire  _alphaQ8_T_4 = io_attenIdx == 4'h4;
  wire  _alphaQ8_T_5 = io_attenIdx == 4'h5;
  wire  _alphaQ8_T_6 = io_attenIdx == 4'h6;
  wire  _alphaQ8_T_7 = io_attenIdx == 4'h7;
  wire  _alphaQ8_T_8 = io_attenIdx == 4'h8;
  wire  _alphaQ8_T_9 = io_attenIdx == 4'h9;
  wire  _alphaQ8_T_10 = io_attenIdx == 4'ha;
  wire [8:0] _alphaQ8_T_11 = _alphaQ8_T ? 9'h100 : 9'h0;
  wire [8:0] _alphaQ8_T_12 = _alphaQ8_T_1 ? 9'hcb : 9'h0;
  wire [8:0] _alphaQ8_T_13 = _alphaQ8_T_2 ? 9'ha2 : 9'h0;
  wire [8:0] _alphaQ8_T_14 = _alphaQ8_T_3 ? 9'h80 : 9'h0;
  wire [8:0] _alphaQ8_T_15 = _alphaQ8_T_4 ? 9'h66 : 9'h0;
  wire [8:0] _alphaQ8_T_16 = _alphaQ8_T_5 ? 9'h51 : 9'h0;
  wire [8:0] _alphaQ8_T_17 = _alphaQ8_T_6 ? 9'h40 : 9'h0;
  wire [8:0] _alphaQ8_T_18 = _alphaQ8_T_7 ? 9'h33 : 9'h0;
  wire [8:0] _alphaQ8_T_19 = _alphaQ8_T_8 ? 9'h28 : 9'h0;
  wire [8:0] _alphaQ8_T_20 = _alphaQ8_T_9 ? 9'h20 : 9'h0;
  wire [8:0] _alphaQ8_T_21 = _alphaQ8_T_10 ? 9'h1a : 9'h0;
  wire [8:0] _alphaQ8_T_22 = _alphaQ8_T_11 | _alphaQ8_T_12;
  wire [8:0] _alphaQ8_T_23 = _alphaQ8_T_22 | _alphaQ8_T_13;
  wire [8:0] _alphaQ8_T_24 = _alphaQ8_T_23 | _alphaQ8_T_14;
  wire [8:0] _alphaQ8_T_25 = _alphaQ8_T_24 | _alphaQ8_T_15;
  wire [8:0] _alphaQ8_T_26 = _alphaQ8_T_25 | _alphaQ8_T_16;
  wire [8:0] _alphaQ8_T_27 = _alphaQ8_T_26 | _alphaQ8_T_17;
  wire [8:0] _alphaQ8_T_28 = _alphaQ8_T_27 | _alphaQ8_T_18;
  wire [8:0] _alphaQ8_T_29 = _alphaQ8_T_28 | _alphaQ8_T_19;
  wire [8:0] _alphaQ8_T_30 = _alphaQ8_T_29 | _alphaQ8_T_20;
  wire [8:0] _alphaQ8_T_31 = _alphaQ8_T_30 | _alphaQ8_T_21;
  reg [8:0] alphaQ8;
  wire [15:0] _GEN_207 = sr_0;
  wire [15:0] _GEN_208 = 8'h1 == srSel ? sr_1 : sr_0;
  wire [15:0] _GEN_209 = 8'h2 == srSel ? sr_2 : _GEN_208;
  wire [15:0] _GEN_210 = 8'h3 == srSel ? sr_3 : _GEN_209;
  wire [15:0] _GEN_211 = 8'h4 == srSel ? sr_4 : _GEN_210;
  wire [15:0] _GEN_212 = 8'h5 == srSel ? sr_5 : _GEN_211;
  wire [15:0] _GEN_213 = 8'h6 == srSel ? sr_6 : _GEN_212;
  wire [15:0] _GEN_214 = 8'h7 == srSel ? sr_7 : _GEN_213;
  wire [15:0] _GEN_215 = 8'h8 == srSel ? sr_8 : _GEN_214;
  wire [15:0] _GEN_216 = 8'h9 == srSel ? sr_9 : _GEN_215;
  wire [15:0] _GEN_217 = 8'ha == srSel ? sr_10 : _GEN_216;
  wire [15:0] _GEN_218 = 8'hb == srSel ? sr_11 : _GEN_217;
  wire [15:0] _GEN_219 = 8'hc == srSel ? sr_12 : _GEN_218;
  wire [15:0] _GEN_220 = 8'hd == srSel ? sr_13 : _GEN_219;
  wire [15:0] _GEN_221 = 8'he == srSel ? sr_14 : _GEN_220;
  wire [15:0] _GEN_222 = 8'hf == srSel ? sr_15 : _GEN_221;
  wire [15:0] _GEN_223 = 8'h10 == srSel ? sr_16 : _GEN_222;
  wire [15:0] _GEN_224 = 8'h11 == srSel ? sr_17 : _GEN_223;
  wire [15:0] _GEN_225 = 8'h12 == srSel ? sr_18 : _GEN_224;
  wire [15:0] _GEN_226 = 8'h13 == srSel ? sr_19 : _GEN_225;
  wire [15:0] _GEN_227 = 8'h14 == srSel ? sr_20 : _GEN_226;
  wire [15:0] _GEN_228 = 8'h15 == srSel ? sr_21 : _GEN_227;
  wire [15:0] _GEN_229 = 8'h16 == srSel ? sr_22 : _GEN_228;
  wire [15:0] _GEN_230 = 8'h17 == srSel ? sr_23 : _GEN_229;
  wire [15:0] _GEN_231 = 8'h18 == srSel ? sr_24 : _GEN_230;
  wire [15:0] _GEN_232 = 8'h19 == srSel ? sr_25 : _GEN_231;
  wire [15:0] _GEN_233 = 8'h1a == srSel ? sr_26 : _GEN_232;
  wire [15:0] _GEN_234 = 8'h1b == srSel ? sr_27 : _GEN_233;
  wire [15:0] _GEN_235 = 8'h1c == srSel ? sr_28 : _GEN_234;
  wire [15:0] _GEN_236 = 8'h1d == srSel ? sr_29 : _GEN_235;
  wire [15:0] _GEN_237 = 8'h1e == srSel ? sr_30 : _GEN_236;
  wire [15:0] _GEN_238 = 8'h1f == srSel ? sr_31 : _GEN_237;
  wire [15:0] _GEN_239 = 8'h20 == srSel ? sr_32 : _GEN_238;
  wire [15:0] _GEN_240 = 8'h21 == srSel ? sr_33 : _GEN_239;
  wire [15:0] _GEN_241 = 8'h22 == srSel ? sr_34 : _GEN_240;
  wire [15:0] _GEN_242 = 8'h23 == srSel ? sr_35 : _GEN_241;
  wire [15:0] _GEN_243 = 8'h24 == srSel ? sr_36 : _GEN_242;
  wire [15:0] _GEN_244 = 8'h25 == srSel ? sr_37 : _GEN_243;
  wire [15:0] _GEN_245 = 8'h26 == srSel ? sr_38 : _GEN_244;
  wire [15:0] _GEN_246 = 8'h27 == srSel ? sr_39 : _GEN_245;
  wire [15:0] _GEN_247 = 8'h28 == srSel ? sr_40 : _GEN_246;
  wire [15:0] _GEN_248 = 8'h29 == srSel ? sr_41 : _GEN_247;
  wire [15:0] _GEN_249 = 8'h2a == srSel ? sr_42 : _GEN_248;
  wire [15:0] _GEN_250 = 8'h2b == srSel ? sr_43 : _GEN_249;
  wire [15:0] _GEN_251 = 8'h2c == srSel ? sr_44 : _GEN_250;
  wire [15:0] _GEN_252 = 8'h2d == srSel ? sr_45 : _GEN_251;
  wire [15:0] _GEN_253 = 8'h2e == srSel ? sr_46 : _GEN_252;
  wire [15:0] _GEN_254 = 8'h2f == srSel ? sr_47 : _GEN_253;
  wire [15:0] _GEN_255 = 8'h30 == srSel ? sr_48 : _GEN_254;
  wire [15:0] _GEN_256 = 8'h31 == srSel ? sr_49 : _GEN_255;
  wire [15:0] _GEN_257 = 8'h32 == srSel ? sr_50 : _GEN_256;
  wire [15:0] _GEN_258 = 8'h33 == srSel ? sr_51 : _GEN_257;
  wire [15:0] _GEN_259 = 8'h34 == srSel ? sr_52 : _GEN_258;
  wire [15:0] _GEN_260 = 8'h35 == srSel ? sr_53 : _GEN_259;
  wire [15:0] _GEN_261 = 8'h36 == srSel ? sr_54 : _GEN_260;
  wire [15:0] _GEN_262 = 8'h37 == srSel ? sr_55 : _GEN_261;
  wire [15:0] _GEN_263 = 8'h38 == srSel ? sr_56 : _GEN_262;
  wire [15:0] _GEN_264 = 8'h39 == srSel ? sr_57 : _GEN_263;
  wire [15:0] _GEN_265 = 8'h3a == srSel ? sr_58 : _GEN_264;
  wire [15:0] _GEN_266 = 8'h3b == srSel ? sr_59 : _GEN_265;
  wire [15:0] _GEN_267 = 8'h3c == srSel ? sr_60 : _GEN_266;
  wire [15:0] _GEN_268 = 8'h3d == srSel ? sr_61 : _GEN_267;
  wire [15:0] _GEN_269 = 8'h3e == srSel ? sr_62 : _GEN_268;
  wire [15:0] _GEN_270 = 8'h3f == srSel ? sr_63 : _GEN_269;
  wire [15:0] _GEN_271 = 8'h40 == srSel ? sr_64 : _GEN_270;
  wire [15:0] _GEN_272 = 8'h41 == srSel ? sr_65 : _GEN_271;
  wire [15:0] _GEN_273 = 8'h42 == srSel ? sr_66 : _GEN_272;
  wire [15:0] _GEN_274 = 8'h43 == srSel ? sr_67 : _GEN_273;
  wire [15:0] _GEN_275 = 8'h44 == srSel ? sr_68 : _GEN_274;
  wire [15:0] _GEN_276 = 8'h45 == srSel ? sr_69 : _GEN_275;
  wire [15:0] _GEN_277 = 8'h46 == srSel ? sr_70 : _GEN_276;
  wire [15:0] _GEN_278 = 8'h47 == srSel ? sr_71 : _GEN_277;
  wire [15:0] _GEN_279 = 8'h48 == srSel ? sr_72 : _GEN_278;
  wire [15:0] _GEN_280 = 8'h49 == srSel ? sr_73 : _GEN_279;
  wire [15:0] _GEN_281 = 8'h4a == srSel ? sr_74 : _GEN_280;
  wire [15:0] _GEN_282 = 8'h4b == srSel ? sr_75 : _GEN_281;
  wire [15:0] _GEN_283 = 8'h4c == srSel ? sr_76 : _GEN_282;
  wire [15:0] _GEN_284 = 8'h4d == srSel ? sr_77 : _GEN_283;
  wire [15:0] _GEN_285 = 8'h4e == srSel ? sr_78 : _GEN_284;
  wire [15:0] _GEN_286 = 8'h4f == srSel ? sr_79 : _GEN_285;
  wire [15:0] _GEN_287 = 8'h50 == srSel ? sr_80 : _GEN_286;
  wire [15:0] _GEN_288 = 8'h51 == srSel ? sr_81 : _GEN_287;
  wire [15:0] _GEN_289 = 8'h52 == srSel ? sr_82 : _GEN_288;
  wire [15:0] _GEN_290 = 8'h53 == srSel ? sr_83 : _GEN_289;
  wire [15:0] _GEN_291 = 8'h54 == srSel ? sr_84 : _GEN_290;
  wire [15:0] _GEN_292 = 8'h55 == srSel ? sr_85 : _GEN_291;
  wire [15:0] _GEN_293 = 8'h56 == srSel ? sr_86 : _GEN_292;
  wire [15:0] _GEN_294 = 8'h57 == srSel ? sr_87 : _GEN_293;
  wire [15:0] _GEN_295 = 8'h58 == srSel ? sr_88 : _GEN_294;
  wire [15:0] _GEN_296 = 8'h59 == srSel ? sr_89 : _GEN_295;
  wire [15:0] _GEN_297 = 8'h5a == srSel ? sr_90 : _GEN_296;
  wire [15:0] _GEN_298 = 8'h5b == srSel ? sr_91 : _GEN_297;
  wire [15:0] _GEN_299 = 8'h5c == srSel ? sr_92 : _GEN_298;
  wire [15:0] _GEN_300 = 8'h5d == srSel ? sr_93 : _GEN_299;
  wire [15:0] _GEN_301 = 8'h5e == srSel ? sr_94 : _GEN_300;
  wire [15:0] _GEN_302 = 8'h5f == srSel ? sr_95 : _GEN_301;
  wire [15:0] _GEN_303 = 8'h60 == srSel ? sr_96 : _GEN_302;
  wire [15:0] _GEN_304 = 8'h61 == srSel ? sr_97 : _GEN_303;
  wire [15:0] _GEN_305 = 8'h62 == srSel ? sr_98 : _GEN_304;
  wire [15:0] _GEN_306 = 8'h63 == srSel ? sr_99 : _GEN_305;
  wire [15:0] _GEN_307 = 8'h64 == srSel ? sr_100 : _GEN_306;
  wire [15:0] _GEN_308 = 8'h65 == srSel ? sr_101 : _GEN_307;
  wire [15:0] _GEN_309 = 8'h66 == srSel ? sr_102 : _GEN_308;
  wire [15:0] _GEN_310 = 8'h67 == srSel ? sr_103 : _GEN_309;
  wire [15:0] _GEN_311 = 8'h68 == srSel ? sr_104 : _GEN_310;
  wire [15:0] _GEN_312 = 8'h69 == srSel ? sr_105 : _GEN_311;
  wire [15:0] _GEN_313 = 8'h6a == srSel ? sr_106 : _GEN_312;
  wire [15:0] _GEN_314 = 8'h6b == srSel ? sr_107 : _GEN_313;
  wire [15:0] _GEN_315 = 8'h6c == srSel ? sr_108 : _GEN_314;
  wire [15:0] _GEN_316 = 8'h6d == srSel ? sr_109 : _GEN_315;
  wire [15:0] _GEN_317 = 8'h6e == srSel ? sr_110 : _GEN_316;
  wire [15:0] _GEN_318 = 8'h6f == srSel ? sr_111 : _GEN_317;
  wire [15:0] _GEN_319 = 8'h70 == srSel ? sr_112 : _GEN_318;
  wire [15:0] _GEN_320 = 8'h71 == srSel ? sr_113 : _GEN_319;
  wire [15:0] _GEN_321 = 8'h72 == srSel ? sr_114 : _GEN_320;
  wire [15:0] _GEN_322 = 8'h73 == srSel ? sr_115 : _GEN_321;
  wire [15:0] _GEN_323 = 8'h74 == srSel ? sr_116 : _GEN_322;
  wire [15:0] _GEN_324 = 8'h75 == srSel ? sr_117 : _GEN_323;
  wire [15:0] _GEN_325 = 8'h76 == srSel ? sr_118 : _GEN_324;
  wire [15:0] _GEN_326 = 8'h77 == srSel ? sr_119 : _GEN_325;
  wire [15:0] _GEN_327 = 8'h78 == srSel ? sr_120 : _GEN_326;
  wire [15:0] _GEN_328 = 8'h79 == srSel ? sr_121 : _GEN_327;
  wire [15:0] _GEN_329 = 8'h7a == srSel ? sr_122 : _GEN_328;
  wire [15:0] _GEN_330 = 8'h7b == srSel ? sr_123 : _GEN_329;
  wire [15:0] _GEN_331 = 8'h7c == srSel ? sr_124 : _GEN_330;
  wire [15:0] _GEN_332 = 8'h7d == srSel ? sr_125 : _GEN_331;
  wire [15:0] _GEN_333 = 8'h7e == srSel ? sr_126 : _GEN_332;
  wire [15:0] _GEN_334 = 8'h7f == srSel ? sr_127 : _GEN_333;
  wire [15:0] _GEN_335 = 8'h80 == srSel ? sr_128 : _GEN_334;
  wire [15:0] _GEN_336 = 8'h81 == srSel ? sr_129 : _GEN_335;
  wire [15:0] _GEN_337 = 8'h82 == srSel ? sr_130 : _GEN_336;
  wire [15:0] _GEN_338 = 8'h83 == srSel ? sr_131 : _GEN_337;
  wire [15:0] _GEN_339 = 8'h84 == srSel ? sr_132 : _GEN_338;
  wire [15:0] _GEN_340 = 8'h85 == srSel ? sr_133 : _GEN_339;
  wire [15:0] _GEN_341 = 8'h86 == srSel ? sr_134 : _GEN_340;
  wire [15:0] _GEN_342 = 8'h87 == srSel ? sr_135 : _GEN_341;
  wire [15:0] _GEN_343 = 8'h88 == srSel ? sr_136 : _GEN_342;
  wire [15:0] _GEN_344 = 8'h89 == srSel ? sr_137 : _GEN_343;
  wire [15:0] _GEN_345 = 8'h8a == srSel ? sr_138 : _GEN_344;
  wire [15:0] _GEN_346 = 8'h8b == srSel ? sr_139 : _GEN_345;
  wire [15:0] _GEN_347 = 8'h8c == srSel ? sr_140 : _GEN_346;
  wire [15:0] _GEN_348 = 8'h8d == srSel ? sr_141 : _GEN_347;
  wire [15:0] _GEN_349 = 8'h8e == srSel ? sr_142 : _GEN_348;
  wire [15:0] _GEN_350 = 8'h8f == srSel ? sr_143 : _GEN_349;
  wire [15:0] _GEN_351 = 8'h90 == srSel ? sr_144 : _GEN_350;
  wire [15:0] _GEN_352 = 8'h91 == srSel ? sr_145 : _GEN_351;
  wire [15:0] _GEN_353 = 8'h92 == srSel ? sr_146 : _GEN_352;
  wire [15:0] _GEN_354 = 8'h93 == srSel ? sr_147 : _GEN_353;
  wire [15:0] _GEN_355 = 8'h94 == srSel ? sr_148 : _GEN_354;
  wire [15:0] _GEN_356 = 8'h95 == srSel ? sr_149 : _GEN_355;
  wire [15:0] _GEN_357 = 8'h96 == srSel ? sr_150 : _GEN_356;
  wire [15:0] _GEN_358 = 8'h97 == srSel ? sr_151 : _GEN_357;
  wire [15:0] _GEN_359 = 8'h98 == srSel ? sr_152 : _GEN_358;
  wire [15:0] _GEN_360 = 8'h99 == srSel ? sr_153 : _GEN_359;
  wire [15:0] _GEN_361 = 8'h9a == srSel ? sr_154 : _GEN_360;
  wire [15:0] _GEN_362 = 8'h9b == srSel ? sr_155 : _GEN_361;
  wire [15:0] _GEN_363 = 8'h9c == srSel ? sr_156 : _GEN_362;
  wire [15:0] _GEN_364 = 8'h9d == srSel ? sr_157 : _GEN_363;
  wire [15:0] _GEN_365 = 8'h9e == srSel ? sr_158 : _GEN_364;
  wire [15:0] _GEN_366 = 8'h9f == srSel ? sr_159 : _GEN_365;
  wire [15:0] _GEN_367 = 8'ha0 == srSel ? sr_160 : _GEN_366;
  wire [15:0] _GEN_368 = 8'ha1 == srSel ? sr_161 : _GEN_367;
  wire [15:0] _GEN_369 = 8'ha2 == srSel ? sr_162 : _GEN_368;
  wire [15:0] _GEN_370 = 8'ha3 == srSel ? sr_163 : _GEN_369;
  wire [15:0] _GEN_371 = 8'ha4 == srSel ? sr_164 : _GEN_370;
  wire [15:0] _GEN_372 = 8'ha5 == srSel ? sr_165 : _GEN_371;
  wire [15:0] _GEN_373 = 8'ha6 == srSel ? sr_166 : _GEN_372;
  wire [15:0] _GEN_374 = 8'ha7 == srSel ? sr_167 : _GEN_373;
  wire [15:0] _GEN_375 = 8'ha8 == srSel ? sr_168 : _GEN_374;
  wire [15:0] _GEN_376 = 8'ha9 == srSel ? sr_169 : _GEN_375;
  wire [15:0] _GEN_377 = 8'haa == srSel ? sr_170 : _GEN_376;
  wire [15:0] _GEN_378 = 8'hab == srSel ? sr_171 : _GEN_377;
  wire [15:0] _GEN_379 = 8'hac == srSel ? sr_172 : _GEN_378;
  wire [15:0] _GEN_380 = 8'had == srSel ? sr_173 : _GEN_379;
  wire [15:0] _GEN_381 = 8'hae == srSel ? sr_174 : _GEN_380;
  wire [15:0] _GEN_382 = 8'haf == srSel ? sr_175 : _GEN_381;
  wire [15:0] _GEN_383 = 8'hb0 == srSel ? sr_176 : _GEN_382;
  wire [15:0] _GEN_384 = 8'hb1 == srSel ? sr_177 : _GEN_383;
  wire [15:0] _GEN_385 = 8'hb2 == srSel ? sr_178 : _GEN_384;
  wire [15:0] _GEN_386 = 8'hb3 == srSel ? sr_179 : _GEN_385;
  wire [15:0] _GEN_387 = 8'hb4 == srSel ? sr_180 : _GEN_386;
  wire [15:0] _GEN_388 = 8'hb5 == srSel ? sr_181 : _GEN_387;
  wire [15:0] _GEN_389 = 8'hb6 == srSel ? sr_182 : _GEN_388;
  wire [15:0] _GEN_390 = 8'hb7 == srSel ? sr_183 : _GEN_389;
  wire [15:0] _GEN_391 = 8'hb8 == srSel ? sr_184 : _GEN_390;
  wire [15:0] _GEN_392 = 8'hb9 == srSel ? sr_185 : _GEN_391;
  wire [15:0] _GEN_393 = 8'hba == srSel ? sr_186 : _GEN_392;
  wire [15:0] _GEN_394 = 8'hbb == srSel ? sr_187 : _GEN_393;
  wire [15:0] _GEN_395 = 8'hbc == srSel ? sr_188 : _GEN_394;
  wire [15:0] _GEN_396 = 8'hbd == srSel ? sr_189 : _GEN_395;
  wire [15:0] _GEN_397 = 8'hbe == srSel ? sr_190 : _GEN_396;
  wire [15:0] _GEN_398 = 8'hbf == srSel ? sr_191 : _GEN_397;
  wire [15:0] _GEN_399 = 8'hc0 == srSel ? sr_192 : _GEN_398;
  wire [15:0] _GEN_400 = 8'hc1 == srSel ? sr_193 : _GEN_399;
  wire [15:0] _GEN_401 = 8'hc2 == srSel ? sr_194 : _GEN_400;
  wire [15:0] _GEN_402 = 8'hc3 == srSel ? sr_195 : _GEN_401;
  wire [15:0] _GEN_403 = 8'hc4 == srSel ? sr_196 : _GEN_402;
  wire [15:0] _GEN_404 = 8'hc5 == srSel ? sr_197 : _GEN_403;
  wire [15:0] _GEN_405 = 8'hc6 == srSel ? sr_198 : _GEN_404;
  wire [15:0] _GEN_406 = 8'hc7 == srSel ? sr_199 : _GEN_405;
  wire [15:0] _sr_srSel = 8'hc7 == srSel ? sr_199 : _GEN_405;
  wire [16:0] _mmOffset_T = {1'b0,$signed(_GEN_406)};
  wire [17:0] _mmOffset_T_1 = $signed(_mmOffset_T) - 17'sh8000;
  wire [16:0] _mmOffset_T_2 = _mmOffset_T_1[16:0];
  wire [16:0] mmOffset = $signed(_mmOffset_T) - 17'sh8000;
  wire [9:0] _mmOffsetAtten_T = {1'b0,$signed(alphaQ8)};
  wire [26:0] _mmOffsetAtten_T_1 = $signed(mmOffset) * $signed(_mmOffsetAtten_T);
  wire [18:0] mmOffsetAtten = _mmOffsetAtten_T_1[26:8];
  wire [19:0] _mmFinalRaw_T = $signed(mmOffsetAtten) + 19'sh8000;
  wire [18:0] _mmFinalRaw_T_1 = _mmFinalRaw_T[18:0];
  wire [18:0] mmFinalRaw = $signed(mmOffsetAtten) + 19'sh8000;
  wire  mmData_lo = $signed(mmFinalRaw) < 19'sh0;
  wire  mmData_hi = $signed(mmFinalRaw) > 19'shffff;
  wire [18:0] _mmData_clipped_T = mmData_hi ? $signed(19'shffff) : $signed(mmFinalRaw);
  wire [18:0] mmData_clipped = mmData_lo ? $signed(19'sh0) : $signed(_mmData_clipped_T);
  wire [18:0] mmData = mmData_lo ? $signed(19'sh0) : $signed(_mmData_clipped_T);
  wire [18:0] _io_dacData_T = io_modeSel ? mmData : {{2'd0}, mdData};
  reg [7:0] dacCnt;
  wire  dacTickRaw = dacCnt == 8'hf9;
  wire [8:0] _dacCnt_T = dacCnt + 8'h1;
  wire [7:0] _dacCnt_T_1 = dacCnt + 8'h1;
  wire [7:0] _GEN_407 = dacTickRaw ? 8'h0 : _dacCnt_T_1;
  reg  io_dacWriteReq_REG;
  wire [7:0] _mQ8_WIRE = _mQ8_T_18 | _mQ8_T_13;
  wire [15:0] _sr_WIRE_0 = 16'h0;
  wire [15:0] _sr_WIRE_1 = 16'h0;
  wire [15:0] _sr_WIRE_2 = 16'h0;
  wire [15:0] _sr_WIRE_3 = 16'h0;
  wire [15:0] _sr_WIRE_4 = 16'h0;
  wire [15:0] _sr_WIRE_5 = 16'h0;
  wire [15:0] _sr_WIRE_6 = 16'h0;
  wire [15:0] _sr_WIRE_7 = 16'h0;
  wire [15:0] _sr_WIRE_8 = 16'h0;
  wire [15:0] _sr_WIRE_9 = 16'h0;
  wire [15:0] _sr_WIRE_10 = 16'h0;
  wire [15:0] _sr_WIRE_11 = 16'h0;
  wire [15:0] _sr_WIRE_12 = 16'h0;
  wire [15:0] _sr_WIRE_13 = 16'h0;
  wire [15:0] _sr_WIRE_14 = 16'h0;
  wire [15:0] _sr_WIRE_15 = 16'h0;
  wire [15:0] _sr_WIRE_16 = 16'h0;
  wire [15:0] _sr_WIRE_17 = 16'h0;
  wire [15:0] _sr_WIRE_18 = 16'h0;
  wire [15:0] _sr_WIRE_19 = 16'h0;
  wire [15:0] _sr_WIRE_20 = 16'h0;
  wire [15:0] _sr_WIRE_21 = 16'h0;
  wire [15:0] _sr_WIRE_22 = 16'h0;
  wire [15:0] _sr_WIRE_23 = 16'h0;
  wire [15:0] _sr_WIRE_24 = 16'h0;
  wire [15:0] _sr_WIRE_25 = 16'h0;
  wire [15:0] _sr_WIRE_26 = 16'h0;
  wire [15:0] _sr_WIRE_27 = 16'h0;
  wire [15:0] _sr_WIRE_28 = 16'h0;
  wire [15:0] _sr_WIRE_29 = 16'h0;
  wire [15:0] _sr_WIRE_30 = 16'h0;
  wire [15:0] _sr_WIRE_31 = 16'h0;
  wire [15:0] _sr_WIRE_32 = 16'h0;
  wire [15:0] _sr_WIRE_33 = 16'h0;
  wire [15:0] _sr_WIRE_34 = 16'h0;
  wire [15:0] _sr_WIRE_35 = 16'h0;
  wire [15:0] _sr_WIRE_36 = 16'h0;
  wire [15:0] _sr_WIRE_37 = 16'h0;
  wire [15:0] _sr_WIRE_38 = 16'h0;
  wire [15:0] _sr_WIRE_39 = 16'h0;
  wire [15:0] _sr_WIRE_40 = 16'h0;
  wire [15:0] _sr_WIRE_41 = 16'h0;
  wire [15:0] _sr_WIRE_42 = 16'h0;
  wire [15:0] _sr_WIRE_43 = 16'h0;
  wire [15:0] _sr_WIRE_44 = 16'h0;
  wire [15:0] _sr_WIRE_45 = 16'h0;
  wire [15:0] _sr_WIRE_46 = 16'h0;
  wire [15:0] _sr_WIRE_47 = 16'h0;
  wire [15:0] _sr_WIRE_48 = 16'h0;
  wire [15:0] _sr_WIRE_49 = 16'h0;
  wire [15:0] _sr_WIRE_50 = 16'h0;
  wire [15:0] _sr_WIRE_51 = 16'h0;
  wire [15:0] _sr_WIRE_52 = 16'h0;
  wire [15:0] _sr_WIRE_53 = 16'h0;
  wire [15:0] _sr_WIRE_54 = 16'h0;
  wire [15:0] _sr_WIRE_55 = 16'h0;
  wire [15:0] _sr_WIRE_56 = 16'h0;
  wire [15:0] _sr_WIRE_57 = 16'h0;
  wire [15:0] _sr_WIRE_58 = 16'h0;
  wire [15:0] _sr_WIRE_59 = 16'h0;
  wire [15:0] _sr_WIRE_60 = 16'h0;
  wire [15:0] _sr_WIRE_61 = 16'h0;
  wire [15:0] _sr_WIRE_62 = 16'h0;
  wire [15:0] _sr_WIRE_63 = 16'h0;
  wire [15:0] _sr_WIRE_64 = 16'h0;
  wire [15:0] _sr_WIRE_65 = 16'h0;
  wire [15:0] _sr_WIRE_66 = 16'h0;
  wire [15:0] _sr_WIRE_67 = 16'h0;
  wire [15:0] _sr_WIRE_68 = 16'h0;
  wire [15:0] _sr_WIRE_69 = 16'h0;
  wire [15:0] _sr_WIRE_70 = 16'h0;
  wire [15:0] _sr_WIRE_71 = 16'h0;
  wire [15:0] _sr_WIRE_72 = 16'h0;
  wire [15:0] _sr_WIRE_73 = 16'h0;
  wire [15:0] _sr_WIRE_74 = 16'h0;
  wire [15:0] _sr_WIRE_75 = 16'h0;
  wire [15:0] _sr_WIRE_76 = 16'h0;
  wire [15:0] _sr_WIRE_77 = 16'h0;
  wire [15:0] _sr_WIRE_78 = 16'h0;
  wire [15:0] _sr_WIRE_79 = 16'h0;
  wire [15:0] _sr_WIRE_80 = 16'h0;
  wire [15:0] _sr_WIRE_81 = 16'h0;
  wire [15:0] _sr_WIRE_82 = 16'h0;
  wire [15:0] _sr_WIRE_83 = 16'h0;
  wire [15:0] _sr_WIRE_84 = 16'h0;
  wire [15:0] _sr_WIRE_85 = 16'h0;
  wire [15:0] _sr_WIRE_86 = 16'h0;
  wire [15:0] _sr_WIRE_87 = 16'h0;
  wire [15:0] _sr_WIRE_88 = 16'h0;
  wire [15:0] _sr_WIRE_89 = 16'h0;
  wire [15:0] _sr_WIRE_90 = 16'h0;
  wire [15:0] _sr_WIRE_91 = 16'h0;
  wire [15:0] _sr_WIRE_92 = 16'h0;
  wire [15:0] _sr_WIRE_93 = 16'h0;
  wire [15:0] _sr_WIRE_94 = 16'h0;
  wire [15:0] _sr_WIRE_95 = 16'h0;
  wire [15:0] _sr_WIRE_96 = 16'h0;
  wire [15:0] _sr_WIRE_97 = 16'h0;
  wire [15:0] _sr_WIRE_98 = 16'h0;
  wire [15:0] _sr_WIRE_99 = 16'h0;
  wire [15:0] _sr_WIRE_100 = 16'h0;
  wire [15:0] _sr_WIRE_101 = 16'h0;
  wire [15:0] _sr_WIRE_102 = 16'h0;
  wire [15:0] _sr_WIRE_103 = 16'h0;
  wire [15:0] _sr_WIRE_104 = 16'h0;
  wire [15:0] _sr_WIRE_105 = 16'h0;
  wire [15:0] _sr_WIRE_106 = 16'h0;
  wire [15:0] _sr_WIRE_107 = 16'h0;
  wire [15:0] _sr_WIRE_108 = 16'h0;
  wire [15:0] _sr_WIRE_109 = 16'h0;
  wire [15:0] _sr_WIRE_110 = 16'h0;
  wire [15:0] _sr_WIRE_111 = 16'h0;
  wire [15:0] _sr_WIRE_112 = 16'h0;
  wire [15:0] _sr_WIRE_113 = 16'h0;
  wire [15:0] _sr_WIRE_114 = 16'h0;
  wire [15:0] _sr_WIRE_115 = 16'h0;
  wire [15:0] _sr_WIRE_116 = 16'h0;
  wire [15:0] _sr_WIRE_117 = 16'h0;
  wire [15:0] _sr_WIRE_118 = 16'h0;
  wire [15:0] _sr_WIRE_119 = 16'h0;
  wire [15:0] _sr_WIRE_120 = 16'h0;
  wire [15:0] _sr_WIRE_121 = 16'h0;
  wire [15:0] _sr_WIRE_122 = 16'h0;
  wire [15:0] _sr_WIRE_123 = 16'h0;
  wire [15:0] _sr_WIRE_124 = 16'h0;
  wire [15:0] _sr_WIRE_125 = 16'h0;
  wire [15:0] _sr_WIRE_126 = 16'h0;
  wire [15:0] _sr_WIRE_127 = 16'h0;
  wire [15:0] _sr_WIRE_128 = 16'h0;
  wire [15:0] _sr_WIRE_129 = 16'h0;
  wire [15:0] _sr_WIRE_130 = 16'h0;
  wire [15:0] _sr_WIRE_131 = 16'h0;
  wire [15:0] _sr_WIRE_132 = 16'h0;
  wire [15:0] _sr_WIRE_133 = 16'h0;
  wire [15:0] _sr_WIRE_134 = 16'h0;
  wire [15:0] _sr_WIRE_135 = 16'h0;
  wire [15:0] _sr_WIRE_136 = 16'h0;
  wire [15:0] _sr_WIRE_137 = 16'h0;
  wire [15:0] _sr_WIRE_138 = 16'h0;
  wire [15:0] _sr_WIRE_139 = 16'h0;
  wire [15:0] _sr_WIRE_140 = 16'h0;
  wire [15:0] _sr_WIRE_141 = 16'h0;
  wire [15:0] _sr_WIRE_142 = 16'h0;
  wire [15:0] _sr_WIRE_143 = 16'h0;
  wire [15:0] _sr_WIRE_144 = 16'h0;
  wire [15:0] _sr_WIRE_145 = 16'h0;
  wire [15:0] _sr_WIRE_146 = 16'h0;
  wire [15:0] _sr_WIRE_147 = 16'h0;
  wire [15:0] _sr_WIRE_148 = 16'h0;
  wire [15:0] _sr_WIRE_149 = 16'h0;
  wire [15:0] _sr_WIRE_150 = 16'h0;
  wire [15:0] _sr_WIRE_151 = 16'h0;
  wire [15:0] _sr_WIRE_152 = 16'h0;
  wire [15:0] _sr_WIRE_153 = 16'h0;
  wire [15:0] _sr_WIRE_154 = 16'h0;
  wire [15:0] _sr_WIRE_155 = 16'h0;
  wire [15:0] _sr_WIRE_156 = 16'h0;
  wire [15:0] _sr_WIRE_157 = 16'h0;
  wire [15:0] _sr_WIRE_158 = 16'h0;
  wire [15:0] _sr_WIRE_159 = 16'h0;
  wire [15:0] _sr_WIRE_160 = 16'h0;
  wire [15:0] _sr_WIRE_161 = 16'h0;
  wire [15:0] _sr_WIRE_162 = 16'h0;
  wire [15:0] _sr_WIRE_163 = 16'h0;
  wire [15:0] _sr_WIRE_164 = 16'h0;
  wire [15:0] _sr_WIRE_165 = 16'h0;
  wire [15:0] _sr_WIRE_166 = 16'h0;
  wire [15:0] _sr_WIRE_167 = 16'h0;
  wire [15:0] _sr_WIRE_168 = 16'h0;
  wire [15:0] _sr_WIRE_169 = 16'h0;
  wire [15:0] _sr_WIRE_170 = 16'h0;
  wire [15:0] _sr_WIRE_171 = 16'h0;
  wire [15:0] _sr_WIRE_172 = 16'h0;
  wire [15:0] _sr_WIRE_173 = 16'h0;
  wire [15:0] _sr_WIRE_174 = 16'h0;
  wire [15:0] _sr_WIRE_175 = 16'h0;
  wire [15:0] _sr_WIRE_176 = 16'h0;
  wire [15:0] _sr_WIRE_177 = 16'h0;
  wire [15:0] _sr_WIRE_178 = 16'h0;
  wire [15:0] _sr_WIRE_179 = 16'h0;
  wire [15:0] _sr_WIRE_180 = 16'h0;
  wire [15:0] _sr_WIRE_181 = 16'h0;
  wire [15:0] _sr_WIRE_182 = 16'h0;
  wire [15:0] _sr_WIRE_183 = 16'h0;
  wire [15:0] _sr_WIRE_184 = 16'h0;
  wire [15:0] _sr_WIRE_185 = 16'h0;
  wire [15:0] _sr_WIRE_186 = 16'h0;
  wire [15:0] _sr_WIRE_187 = 16'h0;
  wire [15:0] _sr_WIRE_188 = 16'h0;
  wire [15:0] _sr_WIRE_189 = 16'h0;
  wire [15:0] _sr_WIRE_190 = 16'h0;
  wire [15:0] _sr_WIRE_191 = 16'h0;
  wire [15:0] _sr_WIRE_192 = 16'h0;
  wire [15:0] _sr_WIRE_193 = 16'h0;
  wire [15:0] _sr_WIRE_194 = 16'h0;
  wire [15:0] _sr_WIRE_195 = 16'h0;
  wire [15:0] _sr_WIRE_196 = 16'h0;
  wire [15:0] _sr_WIRE_197 = 16'h0;
  wire [15:0] _sr_WIRE_198 = 16'h0;
  wire [15:0] _sr_WIRE_199 = 16'h0;
  wire [8:0] _alphaQ8_WIRE = _alphaQ8_T_30 | _alphaQ8_T_21;
  wire [16:0] _GEN_408 = reset ? 17'h0 : _GEN_206;
  assign io_dacData = _io_dacData_T[15:0];
  assign io_dacWriteReq = io_dacWriteReq_REG;
  always @(posedge clock) begin
    if (reset) begin
      phase <= 20'h0;
    end else begin
      phase <= _phase_T_1;
    end
    if (reset) begin
      mQ8 <= 8'h0;
    end else begin
      mQ8 <= _mQ8_T_19;
    end
    if (reset) begin
      usCnt <= 6'h0;
    end else if (usTickRaw) begin
      usCnt <= 6'h0;
    end else begin
      usCnt <= _usCnt_T_1;
    end
    if (reset) begin
      usTick <= 1'h0;
    end else begin
      usTick <= usTickRaw;
    end
    sr_0 <= _GEN_408[15:0];
    if (reset) begin
      sr_1 <= 16'h0;
    end else if (usTick) begin
      sr_1 <= sr_0;
    end
    if (reset) begin
      sr_2 <= 16'h0;
    end else if (usTick) begin
      sr_2 <= sr_1;
    end
    if (reset) begin
      sr_3 <= 16'h0;
    end else if (usTick) begin
      sr_3 <= sr_2;
    end
    if (reset) begin
      sr_4 <= 16'h0;
    end else if (usTick) begin
      sr_4 <= sr_3;
    end
    if (reset) begin
      sr_5 <= 16'h0;
    end else if (usTick) begin
      sr_5 <= sr_4;
    end
    if (reset) begin
      sr_6 <= 16'h0;
    end else if (usTick) begin
      sr_6 <= sr_5;
    end
    if (reset) begin
      sr_7 <= 16'h0;
    end else if (usTick) begin
      sr_7 <= sr_6;
    end
    if (reset) begin
      sr_8 <= 16'h0;
    end else if (usTick) begin
      sr_8 <= sr_7;
    end
    if (reset) begin
      sr_9 <= 16'h0;
    end else if (usTick) begin
      sr_9 <= sr_8;
    end
    if (reset) begin
      sr_10 <= 16'h0;
    end else if (usTick) begin
      sr_10 <= sr_9;
    end
    if (reset) begin
      sr_11 <= 16'h0;
    end else if (usTick) begin
      sr_11 <= sr_10;
    end
    if (reset) begin
      sr_12 <= 16'h0;
    end else if (usTick) begin
      sr_12 <= sr_11;
    end
    if (reset) begin
      sr_13 <= 16'h0;
    end else if (usTick) begin
      sr_13 <= sr_12;
    end
    if (reset) begin
      sr_14 <= 16'h0;
    end else if (usTick) begin
      sr_14 <= sr_13;
    end
    if (reset) begin
      sr_15 <= 16'h0;
    end else if (usTick) begin
      sr_15 <= sr_14;
    end
    if (reset) begin
      sr_16 <= 16'h0;
    end else if (usTick) begin
      sr_16 <= sr_15;
    end
    if (reset) begin
      sr_17 <= 16'h0;
    end else if (usTick) begin
      sr_17 <= sr_16;
    end
    if (reset) begin
      sr_18 <= 16'h0;
    end else if (usTick) begin
      sr_18 <= sr_17;
    end
    if (reset) begin
      sr_19 <= 16'h0;
    end else if (usTick) begin
      sr_19 <= sr_18;
    end
    if (reset) begin
      sr_20 <= 16'h0;
    end else if (usTick) begin
      sr_20 <= sr_19;
    end
    if (reset) begin
      sr_21 <= 16'h0;
    end else if (usTick) begin
      sr_21 <= sr_20;
    end
    if (reset) begin
      sr_22 <= 16'h0;
    end else if (usTick) begin
      sr_22 <= sr_21;
    end
    if (reset) begin
      sr_23 <= 16'h0;
    end else if (usTick) begin
      sr_23 <= sr_22;
    end
    if (reset) begin
      sr_24 <= 16'h0;
    end else if (usTick) begin
      sr_24 <= sr_23;
    end
    if (reset) begin
      sr_25 <= 16'h0;
    end else if (usTick) begin
      sr_25 <= sr_24;
    end
    if (reset) begin
      sr_26 <= 16'h0;
    end else if (usTick) begin
      sr_26 <= sr_25;
    end
    if (reset) begin
      sr_27 <= 16'h0;
    end else if (usTick) begin
      sr_27 <= sr_26;
    end
    if (reset) begin
      sr_28 <= 16'h0;
    end else if (usTick) begin
      sr_28 <= sr_27;
    end
    if (reset) begin
      sr_29 <= 16'h0;
    end else if (usTick) begin
      sr_29 <= sr_28;
    end
    if (reset) begin
      sr_30 <= 16'h0;
    end else if (usTick) begin
      sr_30 <= sr_29;
    end
    if (reset) begin
      sr_31 <= 16'h0;
    end else if (usTick) begin
      sr_31 <= sr_30;
    end
    if (reset) begin
      sr_32 <= 16'h0;
    end else if (usTick) begin
      sr_32 <= sr_31;
    end
    if (reset) begin
      sr_33 <= 16'h0;
    end else if (usTick) begin
      sr_33 <= sr_32;
    end
    if (reset) begin
      sr_34 <= 16'h0;
    end else if (usTick) begin
      sr_34 <= sr_33;
    end
    if (reset) begin
      sr_35 <= 16'h0;
    end else if (usTick) begin
      sr_35 <= sr_34;
    end
    if (reset) begin
      sr_36 <= 16'h0;
    end else if (usTick) begin
      sr_36 <= sr_35;
    end
    if (reset) begin
      sr_37 <= 16'h0;
    end else if (usTick) begin
      sr_37 <= sr_36;
    end
    if (reset) begin
      sr_38 <= 16'h0;
    end else if (usTick) begin
      sr_38 <= sr_37;
    end
    if (reset) begin
      sr_39 <= 16'h0;
    end else if (usTick) begin
      sr_39 <= sr_38;
    end
    if (reset) begin
      sr_40 <= 16'h0;
    end else if (usTick) begin
      sr_40 <= sr_39;
    end
    if (reset) begin
      sr_41 <= 16'h0;
    end else if (usTick) begin
      sr_41 <= sr_40;
    end
    if (reset) begin
      sr_42 <= 16'h0;
    end else if (usTick) begin
      sr_42 <= sr_41;
    end
    if (reset) begin
      sr_43 <= 16'h0;
    end else if (usTick) begin
      sr_43 <= sr_42;
    end
    if (reset) begin
      sr_44 <= 16'h0;
    end else if (usTick) begin
      sr_44 <= sr_43;
    end
    if (reset) begin
      sr_45 <= 16'h0;
    end else if (usTick) begin
      sr_45 <= sr_44;
    end
    if (reset) begin
      sr_46 <= 16'h0;
    end else if (usTick) begin
      sr_46 <= sr_45;
    end
    if (reset) begin
      sr_47 <= 16'h0;
    end else if (usTick) begin
      sr_47 <= sr_46;
    end
    if (reset) begin
      sr_48 <= 16'h0;
    end else if (usTick) begin
      sr_48 <= sr_47;
    end
    if (reset) begin
      sr_49 <= 16'h0;
    end else if (usTick) begin
      sr_49 <= sr_48;
    end
    if (reset) begin
      sr_50 <= 16'h0;
    end else if (usTick) begin
      sr_50 <= sr_49;
    end
    if (reset) begin
      sr_51 <= 16'h0;
    end else if (usTick) begin
      sr_51 <= sr_50;
    end
    if (reset) begin
      sr_52 <= 16'h0;
    end else if (usTick) begin
      sr_52 <= sr_51;
    end
    if (reset) begin
      sr_53 <= 16'h0;
    end else if (usTick) begin
      sr_53 <= sr_52;
    end
    if (reset) begin
      sr_54 <= 16'h0;
    end else if (usTick) begin
      sr_54 <= sr_53;
    end
    if (reset) begin
      sr_55 <= 16'h0;
    end else if (usTick) begin
      sr_55 <= sr_54;
    end
    if (reset) begin
      sr_56 <= 16'h0;
    end else if (usTick) begin
      sr_56 <= sr_55;
    end
    if (reset) begin
      sr_57 <= 16'h0;
    end else if (usTick) begin
      sr_57 <= sr_56;
    end
    if (reset) begin
      sr_58 <= 16'h0;
    end else if (usTick) begin
      sr_58 <= sr_57;
    end
    if (reset) begin
      sr_59 <= 16'h0;
    end else if (usTick) begin
      sr_59 <= sr_58;
    end
    if (reset) begin
      sr_60 <= 16'h0;
    end else if (usTick) begin
      sr_60 <= sr_59;
    end
    if (reset) begin
      sr_61 <= 16'h0;
    end else if (usTick) begin
      sr_61 <= sr_60;
    end
    if (reset) begin
      sr_62 <= 16'h0;
    end else if (usTick) begin
      sr_62 <= sr_61;
    end
    if (reset) begin
      sr_63 <= 16'h0;
    end else if (usTick) begin
      sr_63 <= sr_62;
    end
    if (reset) begin
      sr_64 <= 16'h0;
    end else if (usTick) begin
      sr_64 <= sr_63;
    end
    if (reset) begin
      sr_65 <= 16'h0;
    end else if (usTick) begin
      sr_65 <= sr_64;
    end
    if (reset) begin
      sr_66 <= 16'h0;
    end else if (usTick) begin
      sr_66 <= sr_65;
    end
    if (reset) begin
      sr_67 <= 16'h0;
    end else if (usTick) begin
      sr_67 <= sr_66;
    end
    if (reset) begin
      sr_68 <= 16'h0;
    end else if (usTick) begin
      sr_68 <= sr_67;
    end
    if (reset) begin
      sr_69 <= 16'h0;
    end else if (usTick) begin
      sr_69 <= sr_68;
    end
    if (reset) begin
      sr_70 <= 16'h0;
    end else if (usTick) begin
      sr_70 <= sr_69;
    end
    if (reset) begin
      sr_71 <= 16'h0;
    end else if (usTick) begin
      sr_71 <= sr_70;
    end
    if (reset) begin
      sr_72 <= 16'h0;
    end else if (usTick) begin
      sr_72 <= sr_71;
    end
    if (reset) begin
      sr_73 <= 16'h0;
    end else if (usTick) begin
      sr_73 <= sr_72;
    end
    if (reset) begin
      sr_74 <= 16'h0;
    end else if (usTick) begin
      sr_74 <= sr_73;
    end
    if (reset) begin
      sr_75 <= 16'h0;
    end else if (usTick) begin
      sr_75 <= sr_74;
    end
    if (reset) begin
      sr_76 <= 16'h0;
    end else if (usTick) begin
      sr_76 <= sr_75;
    end
    if (reset) begin
      sr_77 <= 16'h0;
    end else if (usTick) begin
      sr_77 <= sr_76;
    end
    if (reset) begin
      sr_78 <= 16'h0;
    end else if (usTick) begin
      sr_78 <= sr_77;
    end
    if (reset) begin
      sr_79 <= 16'h0;
    end else if (usTick) begin
      sr_79 <= sr_78;
    end
    if (reset) begin
      sr_80 <= 16'h0;
    end else if (usTick) begin
      sr_80 <= sr_79;
    end
    if (reset) begin
      sr_81 <= 16'h0;
    end else if (usTick) begin
      sr_81 <= sr_80;
    end
    if (reset) begin
      sr_82 <= 16'h0;
    end else if (usTick) begin
      sr_82 <= sr_81;
    end
    if (reset) begin
      sr_83 <= 16'h0;
    end else if (usTick) begin
      sr_83 <= sr_82;
    end
    if (reset) begin
      sr_84 <= 16'h0;
    end else if (usTick) begin
      sr_84 <= sr_83;
    end
    if (reset) begin
      sr_85 <= 16'h0;
    end else if (usTick) begin
      sr_85 <= sr_84;
    end
    if (reset) begin
      sr_86 <= 16'h0;
    end else if (usTick) begin
      sr_86 <= sr_85;
    end
    if (reset) begin
      sr_87 <= 16'h0;
    end else if (usTick) begin
      sr_87 <= sr_86;
    end
    if (reset) begin
      sr_88 <= 16'h0;
    end else if (usTick) begin
      sr_88 <= sr_87;
    end
    if (reset) begin
      sr_89 <= 16'h0;
    end else if (usTick) begin
      sr_89 <= sr_88;
    end
    if (reset) begin
      sr_90 <= 16'h0;
    end else if (usTick) begin
      sr_90 <= sr_89;
    end
    if (reset) begin
      sr_91 <= 16'h0;
    end else if (usTick) begin
      sr_91 <= sr_90;
    end
    if (reset) begin
      sr_92 <= 16'h0;
    end else if (usTick) begin
      sr_92 <= sr_91;
    end
    if (reset) begin
      sr_93 <= 16'h0;
    end else if (usTick) begin
      sr_93 <= sr_92;
    end
    if (reset) begin
      sr_94 <= 16'h0;
    end else if (usTick) begin
      sr_94 <= sr_93;
    end
    if (reset) begin
      sr_95 <= 16'h0;
    end else if (usTick) begin
      sr_95 <= sr_94;
    end
    if (reset) begin
      sr_96 <= 16'h0;
    end else if (usTick) begin
      sr_96 <= sr_95;
    end
    if (reset) begin
      sr_97 <= 16'h0;
    end else if (usTick) begin
      sr_97 <= sr_96;
    end
    if (reset) begin
      sr_98 <= 16'h0;
    end else if (usTick) begin
      sr_98 <= sr_97;
    end
    if (reset) begin
      sr_99 <= 16'h0;
    end else if (usTick) begin
      sr_99 <= sr_98;
    end
    if (reset) begin
      sr_100 <= 16'h0;
    end else if (usTick) begin
      sr_100 <= sr_99;
    end
    if (reset) begin
      sr_101 <= 16'h0;
    end else if (usTick) begin
      sr_101 <= sr_100;
    end
    if (reset) begin
      sr_102 <= 16'h0;
    end else if (usTick) begin
      sr_102 <= sr_101;
    end
    if (reset) begin
      sr_103 <= 16'h0;
    end else if (usTick) begin
      sr_103 <= sr_102;
    end
    if (reset) begin
      sr_104 <= 16'h0;
    end else if (usTick) begin
      sr_104 <= sr_103;
    end
    if (reset) begin
      sr_105 <= 16'h0;
    end else if (usTick) begin
      sr_105 <= sr_104;
    end
    if (reset) begin
      sr_106 <= 16'h0;
    end else if (usTick) begin
      sr_106 <= sr_105;
    end
    if (reset) begin
      sr_107 <= 16'h0;
    end else if (usTick) begin
      sr_107 <= sr_106;
    end
    if (reset) begin
      sr_108 <= 16'h0;
    end else if (usTick) begin
      sr_108 <= sr_107;
    end
    if (reset) begin
      sr_109 <= 16'h0;
    end else if (usTick) begin
      sr_109 <= sr_108;
    end
    if (reset) begin
      sr_110 <= 16'h0;
    end else if (usTick) begin
      sr_110 <= sr_109;
    end
    if (reset) begin
      sr_111 <= 16'h0;
    end else if (usTick) begin
      sr_111 <= sr_110;
    end
    if (reset) begin
      sr_112 <= 16'h0;
    end else if (usTick) begin
      sr_112 <= sr_111;
    end
    if (reset) begin
      sr_113 <= 16'h0;
    end else if (usTick) begin
      sr_113 <= sr_112;
    end
    if (reset) begin
      sr_114 <= 16'h0;
    end else if (usTick) begin
      sr_114 <= sr_113;
    end
    if (reset) begin
      sr_115 <= 16'h0;
    end else if (usTick) begin
      sr_115 <= sr_114;
    end
    if (reset) begin
      sr_116 <= 16'h0;
    end else if (usTick) begin
      sr_116 <= sr_115;
    end
    if (reset) begin
      sr_117 <= 16'h0;
    end else if (usTick) begin
      sr_117 <= sr_116;
    end
    if (reset) begin
      sr_118 <= 16'h0;
    end else if (usTick) begin
      sr_118 <= sr_117;
    end
    if (reset) begin
      sr_119 <= 16'h0;
    end else if (usTick) begin
      sr_119 <= sr_118;
    end
    if (reset) begin
      sr_120 <= 16'h0;
    end else if (usTick) begin
      sr_120 <= sr_119;
    end
    if (reset) begin
      sr_121 <= 16'h0;
    end else if (usTick) begin
      sr_121 <= sr_120;
    end
    if (reset) begin
      sr_122 <= 16'h0;
    end else if (usTick) begin
      sr_122 <= sr_121;
    end
    if (reset) begin
      sr_123 <= 16'h0;
    end else if (usTick) begin
      sr_123 <= sr_122;
    end
    if (reset) begin
      sr_124 <= 16'h0;
    end else if (usTick) begin
      sr_124 <= sr_123;
    end
    if (reset) begin
      sr_125 <= 16'h0;
    end else if (usTick) begin
      sr_125 <= sr_124;
    end
    if (reset) begin
      sr_126 <= 16'h0;
    end else if (usTick) begin
      sr_126 <= sr_125;
    end
    if (reset) begin
      sr_127 <= 16'h0;
    end else if (usTick) begin
      sr_127 <= sr_126;
    end
    if (reset) begin
      sr_128 <= 16'h0;
    end else if (usTick) begin
      sr_128 <= sr_127;
    end
    if (reset) begin
      sr_129 <= 16'h0;
    end else if (usTick) begin
      sr_129 <= sr_128;
    end
    if (reset) begin
      sr_130 <= 16'h0;
    end else if (usTick) begin
      sr_130 <= sr_129;
    end
    if (reset) begin
      sr_131 <= 16'h0;
    end else if (usTick) begin
      sr_131 <= sr_130;
    end
    if (reset) begin
      sr_132 <= 16'h0;
    end else if (usTick) begin
      sr_132 <= sr_131;
    end
    if (reset) begin
      sr_133 <= 16'h0;
    end else if (usTick) begin
      sr_133 <= sr_132;
    end
    if (reset) begin
      sr_134 <= 16'h0;
    end else if (usTick) begin
      sr_134 <= sr_133;
    end
    if (reset) begin
      sr_135 <= 16'h0;
    end else if (usTick) begin
      sr_135 <= sr_134;
    end
    if (reset) begin
      sr_136 <= 16'h0;
    end else if (usTick) begin
      sr_136 <= sr_135;
    end
    if (reset) begin
      sr_137 <= 16'h0;
    end else if (usTick) begin
      sr_137 <= sr_136;
    end
    if (reset) begin
      sr_138 <= 16'h0;
    end else if (usTick) begin
      sr_138 <= sr_137;
    end
    if (reset) begin
      sr_139 <= 16'h0;
    end else if (usTick) begin
      sr_139 <= sr_138;
    end
    if (reset) begin
      sr_140 <= 16'h0;
    end else if (usTick) begin
      sr_140 <= sr_139;
    end
    if (reset) begin
      sr_141 <= 16'h0;
    end else if (usTick) begin
      sr_141 <= sr_140;
    end
    if (reset) begin
      sr_142 <= 16'h0;
    end else if (usTick) begin
      sr_142 <= sr_141;
    end
    if (reset) begin
      sr_143 <= 16'h0;
    end else if (usTick) begin
      sr_143 <= sr_142;
    end
    if (reset) begin
      sr_144 <= 16'h0;
    end else if (usTick) begin
      sr_144 <= sr_143;
    end
    if (reset) begin
      sr_145 <= 16'h0;
    end else if (usTick) begin
      sr_145 <= sr_144;
    end
    if (reset) begin
      sr_146 <= 16'h0;
    end else if (usTick) begin
      sr_146 <= sr_145;
    end
    if (reset) begin
      sr_147 <= 16'h0;
    end else if (usTick) begin
      sr_147 <= sr_146;
    end
    if (reset) begin
      sr_148 <= 16'h0;
    end else if (usTick) begin
      sr_148 <= sr_147;
    end
    if (reset) begin
      sr_149 <= 16'h0;
    end else if (usTick) begin
      sr_149 <= sr_148;
    end
    if (reset) begin
      sr_150 <= 16'h0;
    end else if (usTick) begin
      sr_150 <= sr_149;
    end
    if (reset) begin
      sr_151 <= 16'h0;
    end else if (usTick) begin
      sr_151 <= sr_150;
    end
    if (reset) begin
      sr_152 <= 16'h0;
    end else if (usTick) begin
      sr_152 <= sr_151;
    end
    if (reset) begin
      sr_153 <= 16'h0;
    end else if (usTick) begin
      sr_153 <= sr_152;
    end
    if (reset) begin
      sr_154 <= 16'h0;
    end else if (usTick) begin
      sr_154 <= sr_153;
    end
    if (reset) begin
      sr_155 <= 16'h0;
    end else if (usTick) begin
      sr_155 <= sr_154;
    end
    if (reset) begin
      sr_156 <= 16'h0;
    end else if (usTick) begin
      sr_156 <= sr_155;
    end
    if (reset) begin
      sr_157 <= 16'h0;
    end else if (usTick) begin
      sr_157 <= sr_156;
    end
    if (reset) begin
      sr_158 <= 16'h0;
    end else if (usTick) begin
      sr_158 <= sr_157;
    end
    if (reset) begin
      sr_159 <= 16'h0;
    end else if (usTick) begin
      sr_159 <= sr_158;
    end
    if (reset) begin
      sr_160 <= 16'h0;
    end else if (usTick) begin
      sr_160 <= sr_159;
    end
    if (reset) begin
      sr_161 <= 16'h0;
    end else if (usTick) begin
      sr_161 <= sr_160;
    end
    if (reset) begin
      sr_162 <= 16'h0;
    end else if (usTick) begin
      sr_162 <= sr_161;
    end
    if (reset) begin
      sr_163 <= 16'h0;
    end else if (usTick) begin
      sr_163 <= sr_162;
    end
    if (reset) begin
      sr_164 <= 16'h0;
    end else if (usTick) begin
      sr_164 <= sr_163;
    end
    if (reset) begin
      sr_165 <= 16'h0;
    end else if (usTick) begin
      sr_165 <= sr_164;
    end
    if (reset) begin
      sr_166 <= 16'h0;
    end else if (usTick) begin
      sr_166 <= sr_165;
    end
    if (reset) begin
      sr_167 <= 16'h0;
    end else if (usTick) begin
      sr_167 <= sr_166;
    end
    if (reset) begin
      sr_168 <= 16'h0;
    end else if (usTick) begin
      sr_168 <= sr_167;
    end
    if (reset) begin
      sr_169 <= 16'h0;
    end else if (usTick) begin
      sr_169 <= sr_168;
    end
    if (reset) begin
      sr_170 <= 16'h0;
    end else if (usTick) begin
      sr_170 <= sr_169;
    end
    if (reset) begin
      sr_171 <= 16'h0;
    end else if (usTick) begin
      sr_171 <= sr_170;
    end
    if (reset) begin
      sr_172 <= 16'h0;
    end else if (usTick) begin
      sr_172 <= sr_171;
    end
    if (reset) begin
      sr_173 <= 16'h0;
    end else if (usTick) begin
      sr_173 <= sr_172;
    end
    if (reset) begin
      sr_174 <= 16'h0;
    end else if (usTick) begin
      sr_174 <= sr_173;
    end
    if (reset) begin
      sr_175 <= 16'h0;
    end else if (usTick) begin
      sr_175 <= sr_174;
    end
    if (reset) begin
      sr_176 <= 16'h0;
    end else if (usTick) begin
      sr_176 <= sr_175;
    end
    if (reset) begin
      sr_177 <= 16'h0;
    end else if (usTick) begin
      sr_177 <= sr_176;
    end
    if (reset) begin
      sr_178 <= 16'h0;
    end else if (usTick) begin
      sr_178 <= sr_177;
    end
    if (reset) begin
      sr_179 <= 16'h0;
    end else if (usTick) begin
      sr_179 <= sr_178;
    end
    if (reset) begin
      sr_180 <= 16'h0;
    end else if (usTick) begin
      sr_180 <= sr_179;
    end
    if (reset) begin
      sr_181 <= 16'h0;
    end else if (usTick) begin
      sr_181 <= sr_180;
    end
    if (reset) begin
      sr_182 <= 16'h0;
    end else if (usTick) begin
      sr_182 <= sr_181;
    end
    if (reset) begin
      sr_183 <= 16'h0;
    end else if (usTick) begin
      sr_183 <= sr_182;
    end
    if (reset) begin
      sr_184 <= 16'h0;
    end else if (usTick) begin
      sr_184 <= sr_183;
    end
    if (reset) begin
      sr_185 <= 16'h0;
    end else if (usTick) begin
      sr_185 <= sr_184;
    end
    if (reset) begin
      sr_186 <= 16'h0;
    end else if (usTick) begin
      sr_186 <= sr_185;
    end
    if (reset) begin
      sr_187 <= 16'h0;
    end else if (usTick) begin
      sr_187 <= sr_186;
    end
    if (reset) begin
      sr_188 <= 16'h0;
    end else if (usTick) begin
      sr_188 <= sr_187;
    end
    if (reset) begin
      sr_189 <= 16'h0;
    end else if (usTick) begin
      sr_189 <= sr_188;
    end
    if (reset) begin
      sr_190 <= 16'h0;
    end else if (usTick) begin
      sr_190 <= sr_189;
    end
    if (reset) begin
      sr_191 <= 16'h0;
    end else if (usTick) begin
      sr_191 <= sr_190;
    end
    if (reset) begin
      sr_192 <= 16'h0;
    end else if (usTick) begin
      sr_192 <= sr_191;
    end
    if (reset) begin
      sr_193 <= 16'h0;
    end else if (usTick) begin
      sr_193 <= sr_192;
    end
    if (reset) begin
      sr_194 <= 16'h0;
    end else if (usTick) begin
      sr_194 <= sr_193;
    end
    if (reset) begin
      sr_195 <= 16'h0;
    end else if (usTick) begin
      sr_195 <= sr_194;
    end
    if (reset) begin
      sr_196 <= 16'h0;
    end else if (usTick) begin
      sr_196 <= sr_195;
    end
    if (reset) begin
      sr_197 <= 16'h0;
    end else if (usTick) begin
      sr_197 <= sr_196;
    end
    if (reset) begin
      sr_198 <= 16'h0;
    end else if (usTick) begin
      sr_198 <= sr_197;
    end
    if (reset) begin
      sr_199 <= 16'h0;
    end else if (usTick) begin
      sr_199 <= sr_198;
    end
    if (reset) begin
      alphaQ8 <= 9'h100;
    end else begin
      alphaQ8 <= _alphaQ8_T_31;
    end
    if (reset) begin
      dacCnt <= 8'h0;
    end else if (dacTickRaw) begin
      dacCnt <= 8'h0;
    end else begin
      dacCnt <= _dacCnt_T_1;
    end
    if (reset) begin
      io_dacWriteReq_REG <= 1'h0;
    end else begin
      io_dacWriteReq_REG <= dacTickRaw;
    end
  end
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
  phase = _RAND_0[19:0];
  _RAND_1 = {1{`RANDOM}};
  mQ8 = _RAND_1[7:0];
  _RAND_2 = {1{`RANDOM}};
  usCnt = _RAND_2[5:0];
  _RAND_3 = {1{`RANDOM}};
  usTick = _RAND_3[0:0];
  _RAND_4 = {1{`RANDOM}};
  sr_0 = _RAND_4[15:0];
  _RAND_5 = {1{`RANDOM}};
  sr_1 = _RAND_5[15:0];
  _RAND_6 = {1{`RANDOM}};
  sr_2 = _RAND_6[15:0];
  _RAND_7 = {1{`RANDOM}};
  sr_3 = _RAND_7[15:0];
  _RAND_8 = {1{`RANDOM}};
  sr_4 = _RAND_8[15:0];
  _RAND_9 = {1{`RANDOM}};
  sr_5 = _RAND_9[15:0];
  _RAND_10 = {1{`RANDOM}};
  sr_6 = _RAND_10[15:0];
  _RAND_11 = {1{`RANDOM}};
  sr_7 = _RAND_11[15:0];
  _RAND_12 = {1{`RANDOM}};
  sr_8 = _RAND_12[15:0];
  _RAND_13 = {1{`RANDOM}};
  sr_9 = _RAND_13[15:0];
  _RAND_14 = {1{`RANDOM}};
  sr_10 = _RAND_14[15:0];
  _RAND_15 = {1{`RANDOM}};
  sr_11 = _RAND_15[15:0];
  _RAND_16 = {1{`RANDOM}};
  sr_12 = _RAND_16[15:0];
  _RAND_17 = {1{`RANDOM}};
  sr_13 = _RAND_17[15:0];
  _RAND_18 = {1{`RANDOM}};
  sr_14 = _RAND_18[15:0];
  _RAND_19 = {1{`RANDOM}};
  sr_15 = _RAND_19[15:0];
  _RAND_20 = {1{`RANDOM}};
  sr_16 = _RAND_20[15:0];
  _RAND_21 = {1{`RANDOM}};
  sr_17 = _RAND_21[15:0];
  _RAND_22 = {1{`RANDOM}};
  sr_18 = _RAND_22[15:0];
  _RAND_23 = {1{`RANDOM}};
  sr_19 = _RAND_23[15:0];
  _RAND_24 = {1{`RANDOM}};
  sr_20 = _RAND_24[15:0];
  _RAND_25 = {1{`RANDOM}};
  sr_21 = _RAND_25[15:0];
  _RAND_26 = {1{`RANDOM}};
  sr_22 = _RAND_26[15:0];
  _RAND_27 = {1{`RANDOM}};
  sr_23 = _RAND_27[15:0];
  _RAND_28 = {1{`RANDOM}};
  sr_24 = _RAND_28[15:0];
  _RAND_29 = {1{`RANDOM}};
  sr_25 = _RAND_29[15:0];
  _RAND_30 = {1{`RANDOM}};
  sr_26 = _RAND_30[15:0];
  _RAND_31 = {1{`RANDOM}};
  sr_27 = _RAND_31[15:0];
  _RAND_32 = {1{`RANDOM}};
  sr_28 = _RAND_32[15:0];
  _RAND_33 = {1{`RANDOM}};
  sr_29 = _RAND_33[15:0];
  _RAND_34 = {1{`RANDOM}};
  sr_30 = _RAND_34[15:0];
  _RAND_35 = {1{`RANDOM}};
  sr_31 = _RAND_35[15:0];
  _RAND_36 = {1{`RANDOM}};
  sr_32 = _RAND_36[15:0];
  _RAND_37 = {1{`RANDOM}};
  sr_33 = _RAND_37[15:0];
  _RAND_38 = {1{`RANDOM}};
  sr_34 = _RAND_38[15:0];
  _RAND_39 = {1{`RANDOM}};
  sr_35 = _RAND_39[15:0];
  _RAND_40 = {1{`RANDOM}};
  sr_36 = _RAND_40[15:0];
  _RAND_41 = {1{`RANDOM}};
  sr_37 = _RAND_41[15:0];
  _RAND_42 = {1{`RANDOM}};
  sr_38 = _RAND_42[15:0];
  _RAND_43 = {1{`RANDOM}};
  sr_39 = _RAND_43[15:0];
  _RAND_44 = {1{`RANDOM}};
  sr_40 = _RAND_44[15:0];
  _RAND_45 = {1{`RANDOM}};
  sr_41 = _RAND_45[15:0];
  _RAND_46 = {1{`RANDOM}};
  sr_42 = _RAND_46[15:0];
  _RAND_47 = {1{`RANDOM}};
  sr_43 = _RAND_47[15:0];
  _RAND_48 = {1{`RANDOM}};
  sr_44 = _RAND_48[15:0];
  _RAND_49 = {1{`RANDOM}};
  sr_45 = _RAND_49[15:0];
  _RAND_50 = {1{`RANDOM}};
  sr_46 = _RAND_50[15:0];
  _RAND_51 = {1{`RANDOM}};
  sr_47 = _RAND_51[15:0];
  _RAND_52 = {1{`RANDOM}};
  sr_48 = _RAND_52[15:0];
  _RAND_53 = {1{`RANDOM}};
  sr_49 = _RAND_53[15:0];
  _RAND_54 = {1{`RANDOM}};
  sr_50 = _RAND_54[15:0];
  _RAND_55 = {1{`RANDOM}};
  sr_51 = _RAND_55[15:0];
  _RAND_56 = {1{`RANDOM}};
  sr_52 = _RAND_56[15:0];
  _RAND_57 = {1{`RANDOM}};
  sr_53 = _RAND_57[15:0];
  _RAND_58 = {1{`RANDOM}};
  sr_54 = _RAND_58[15:0];
  _RAND_59 = {1{`RANDOM}};
  sr_55 = _RAND_59[15:0];
  _RAND_60 = {1{`RANDOM}};
  sr_56 = _RAND_60[15:0];
  _RAND_61 = {1{`RANDOM}};
  sr_57 = _RAND_61[15:0];
  _RAND_62 = {1{`RANDOM}};
  sr_58 = _RAND_62[15:0];
  _RAND_63 = {1{`RANDOM}};
  sr_59 = _RAND_63[15:0];
  _RAND_64 = {1{`RANDOM}};
  sr_60 = _RAND_64[15:0];
  _RAND_65 = {1{`RANDOM}};
  sr_61 = _RAND_65[15:0];
  _RAND_66 = {1{`RANDOM}};
  sr_62 = _RAND_66[15:0];
  _RAND_67 = {1{`RANDOM}};
  sr_63 = _RAND_67[15:0];
  _RAND_68 = {1{`RANDOM}};
  sr_64 = _RAND_68[15:0];
  _RAND_69 = {1{`RANDOM}};
  sr_65 = _RAND_69[15:0];
  _RAND_70 = {1{`RANDOM}};
  sr_66 = _RAND_70[15:0];
  _RAND_71 = {1{`RANDOM}};
  sr_67 = _RAND_71[15:0];
  _RAND_72 = {1{`RANDOM}};
  sr_68 = _RAND_72[15:0];
  _RAND_73 = {1{`RANDOM}};
  sr_69 = _RAND_73[15:0];
  _RAND_74 = {1{`RANDOM}};
  sr_70 = _RAND_74[15:0];
  _RAND_75 = {1{`RANDOM}};
  sr_71 = _RAND_75[15:0];
  _RAND_76 = {1{`RANDOM}};
  sr_72 = _RAND_76[15:0];
  _RAND_77 = {1{`RANDOM}};
  sr_73 = _RAND_77[15:0];
  _RAND_78 = {1{`RANDOM}};
  sr_74 = _RAND_78[15:0];
  _RAND_79 = {1{`RANDOM}};
  sr_75 = _RAND_79[15:0];
  _RAND_80 = {1{`RANDOM}};
  sr_76 = _RAND_80[15:0];
  _RAND_81 = {1{`RANDOM}};
  sr_77 = _RAND_81[15:0];
  _RAND_82 = {1{`RANDOM}};
  sr_78 = _RAND_82[15:0];
  _RAND_83 = {1{`RANDOM}};
  sr_79 = _RAND_83[15:0];
  _RAND_84 = {1{`RANDOM}};
  sr_80 = _RAND_84[15:0];
  _RAND_85 = {1{`RANDOM}};
  sr_81 = _RAND_85[15:0];
  _RAND_86 = {1{`RANDOM}};
  sr_82 = _RAND_86[15:0];
  _RAND_87 = {1{`RANDOM}};
  sr_83 = _RAND_87[15:0];
  _RAND_88 = {1{`RANDOM}};
  sr_84 = _RAND_88[15:0];
  _RAND_89 = {1{`RANDOM}};
  sr_85 = _RAND_89[15:0];
  _RAND_90 = {1{`RANDOM}};
  sr_86 = _RAND_90[15:0];
  _RAND_91 = {1{`RANDOM}};
  sr_87 = _RAND_91[15:0];
  _RAND_92 = {1{`RANDOM}};
  sr_88 = _RAND_92[15:0];
  _RAND_93 = {1{`RANDOM}};
  sr_89 = _RAND_93[15:0];
  _RAND_94 = {1{`RANDOM}};
  sr_90 = _RAND_94[15:0];
  _RAND_95 = {1{`RANDOM}};
  sr_91 = _RAND_95[15:0];
  _RAND_96 = {1{`RANDOM}};
  sr_92 = _RAND_96[15:0];
  _RAND_97 = {1{`RANDOM}};
  sr_93 = _RAND_97[15:0];
  _RAND_98 = {1{`RANDOM}};
  sr_94 = _RAND_98[15:0];
  _RAND_99 = {1{`RANDOM}};
  sr_95 = _RAND_99[15:0];
  _RAND_100 = {1{`RANDOM}};
  sr_96 = _RAND_100[15:0];
  _RAND_101 = {1{`RANDOM}};
  sr_97 = _RAND_101[15:0];
  _RAND_102 = {1{`RANDOM}};
  sr_98 = _RAND_102[15:0];
  _RAND_103 = {1{`RANDOM}};
  sr_99 = _RAND_103[15:0];
  _RAND_104 = {1{`RANDOM}};
  sr_100 = _RAND_104[15:0];
  _RAND_105 = {1{`RANDOM}};
  sr_101 = _RAND_105[15:0];
  _RAND_106 = {1{`RANDOM}};
  sr_102 = _RAND_106[15:0];
  _RAND_107 = {1{`RANDOM}};
  sr_103 = _RAND_107[15:0];
  _RAND_108 = {1{`RANDOM}};
  sr_104 = _RAND_108[15:0];
  _RAND_109 = {1{`RANDOM}};
  sr_105 = _RAND_109[15:0];
  _RAND_110 = {1{`RANDOM}};
  sr_106 = _RAND_110[15:0];
  _RAND_111 = {1{`RANDOM}};
  sr_107 = _RAND_111[15:0];
  _RAND_112 = {1{`RANDOM}};
  sr_108 = _RAND_112[15:0];
  _RAND_113 = {1{`RANDOM}};
  sr_109 = _RAND_113[15:0];
  _RAND_114 = {1{`RANDOM}};
  sr_110 = _RAND_114[15:0];
  _RAND_115 = {1{`RANDOM}};
  sr_111 = _RAND_115[15:0];
  _RAND_116 = {1{`RANDOM}};
  sr_112 = _RAND_116[15:0];
  _RAND_117 = {1{`RANDOM}};
  sr_113 = _RAND_117[15:0];
  _RAND_118 = {1{`RANDOM}};
  sr_114 = _RAND_118[15:0];
  _RAND_119 = {1{`RANDOM}};
  sr_115 = _RAND_119[15:0];
  _RAND_120 = {1{`RANDOM}};
  sr_116 = _RAND_120[15:0];
  _RAND_121 = {1{`RANDOM}};
  sr_117 = _RAND_121[15:0];
  _RAND_122 = {1{`RANDOM}};
  sr_118 = _RAND_122[15:0];
  _RAND_123 = {1{`RANDOM}};
  sr_119 = _RAND_123[15:0];
  _RAND_124 = {1{`RANDOM}};
  sr_120 = _RAND_124[15:0];
  _RAND_125 = {1{`RANDOM}};
  sr_121 = _RAND_125[15:0];
  _RAND_126 = {1{`RANDOM}};
  sr_122 = _RAND_126[15:0];
  _RAND_127 = {1{`RANDOM}};
  sr_123 = _RAND_127[15:0];
  _RAND_128 = {1{`RANDOM}};
  sr_124 = _RAND_128[15:0];
  _RAND_129 = {1{`RANDOM}};
  sr_125 = _RAND_129[15:0];
  _RAND_130 = {1{`RANDOM}};
  sr_126 = _RAND_130[15:0];
  _RAND_131 = {1{`RANDOM}};
  sr_127 = _RAND_131[15:0];
  _RAND_132 = {1{`RANDOM}};
  sr_128 = _RAND_132[15:0];
  _RAND_133 = {1{`RANDOM}};
  sr_129 = _RAND_133[15:0];
  _RAND_134 = {1{`RANDOM}};
  sr_130 = _RAND_134[15:0];
  _RAND_135 = {1{`RANDOM}};
  sr_131 = _RAND_135[15:0];
  _RAND_136 = {1{`RANDOM}};
  sr_132 = _RAND_136[15:0];
  _RAND_137 = {1{`RANDOM}};
  sr_133 = _RAND_137[15:0];
  _RAND_138 = {1{`RANDOM}};
  sr_134 = _RAND_138[15:0];
  _RAND_139 = {1{`RANDOM}};
  sr_135 = _RAND_139[15:0];
  _RAND_140 = {1{`RANDOM}};
  sr_136 = _RAND_140[15:0];
  _RAND_141 = {1{`RANDOM}};
  sr_137 = _RAND_141[15:0];
  _RAND_142 = {1{`RANDOM}};
  sr_138 = _RAND_142[15:0];
  _RAND_143 = {1{`RANDOM}};
  sr_139 = _RAND_143[15:0];
  _RAND_144 = {1{`RANDOM}};
  sr_140 = _RAND_144[15:0];
  _RAND_145 = {1{`RANDOM}};
  sr_141 = _RAND_145[15:0];
  _RAND_146 = {1{`RANDOM}};
  sr_142 = _RAND_146[15:0];
  _RAND_147 = {1{`RANDOM}};
  sr_143 = _RAND_147[15:0];
  _RAND_148 = {1{`RANDOM}};
  sr_144 = _RAND_148[15:0];
  _RAND_149 = {1{`RANDOM}};
  sr_145 = _RAND_149[15:0];
  _RAND_150 = {1{`RANDOM}};
  sr_146 = _RAND_150[15:0];
  _RAND_151 = {1{`RANDOM}};
  sr_147 = _RAND_151[15:0];
  _RAND_152 = {1{`RANDOM}};
  sr_148 = _RAND_152[15:0];
  _RAND_153 = {1{`RANDOM}};
  sr_149 = _RAND_153[15:0];
  _RAND_154 = {1{`RANDOM}};
  sr_150 = _RAND_154[15:0];
  _RAND_155 = {1{`RANDOM}};
  sr_151 = _RAND_155[15:0];
  _RAND_156 = {1{`RANDOM}};
  sr_152 = _RAND_156[15:0];
  _RAND_157 = {1{`RANDOM}};
  sr_153 = _RAND_157[15:0];
  _RAND_158 = {1{`RANDOM}};
  sr_154 = _RAND_158[15:0];
  _RAND_159 = {1{`RANDOM}};
  sr_155 = _RAND_159[15:0];
  _RAND_160 = {1{`RANDOM}};
  sr_156 = _RAND_160[15:0];
  _RAND_161 = {1{`RANDOM}};
  sr_157 = _RAND_161[15:0];
  _RAND_162 = {1{`RANDOM}};
  sr_158 = _RAND_162[15:0];
  _RAND_163 = {1{`RANDOM}};
  sr_159 = _RAND_163[15:0];
  _RAND_164 = {1{`RANDOM}};
  sr_160 = _RAND_164[15:0];
  _RAND_165 = {1{`RANDOM}};
  sr_161 = _RAND_165[15:0];
  _RAND_166 = {1{`RANDOM}};
  sr_162 = _RAND_166[15:0];
  _RAND_167 = {1{`RANDOM}};
  sr_163 = _RAND_167[15:0];
  _RAND_168 = {1{`RANDOM}};
  sr_164 = _RAND_168[15:0];
  _RAND_169 = {1{`RANDOM}};
  sr_165 = _RAND_169[15:0];
  _RAND_170 = {1{`RANDOM}};
  sr_166 = _RAND_170[15:0];
  _RAND_171 = {1{`RANDOM}};
  sr_167 = _RAND_171[15:0];
  _RAND_172 = {1{`RANDOM}};
  sr_168 = _RAND_172[15:0];
  _RAND_173 = {1{`RANDOM}};
  sr_169 = _RAND_173[15:0];
  _RAND_174 = {1{`RANDOM}};
  sr_170 = _RAND_174[15:0];
  _RAND_175 = {1{`RANDOM}};
  sr_171 = _RAND_175[15:0];
  _RAND_176 = {1{`RANDOM}};
  sr_172 = _RAND_176[15:0];
  _RAND_177 = {1{`RANDOM}};
  sr_173 = _RAND_177[15:0];
  _RAND_178 = {1{`RANDOM}};
  sr_174 = _RAND_178[15:0];
  _RAND_179 = {1{`RANDOM}};
  sr_175 = _RAND_179[15:0];
  _RAND_180 = {1{`RANDOM}};
  sr_176 = _RAND_180[15:0];
  _RAND_181 = {1{`RANDOM}};
  sr_177 = _RAND_181[15:0];
  _RAND_182 = {1{`RANDOM}};
  sr_178 = _RAND_182[15:0];
  _RAND_183 = {1{`RANDOM}};
  sr_179 = _RAND_183[15:0];
  _RAND_184 = {1{`RANDOM}};
  sr_180 = _RAND_184[15:0];
  _RAND_185 = {1{`RANDOM}};
  sr_181 = _RAND_185[15:0];
  _RAND_186 = {1{`RANDOM}};
  sr_182 = _RAND_186[15:0];
  _RAND_187 = {1{`RANDOM}};
  sr_183 = _RAND_187[15:0];
  _RAND_188 = {1{`RANDOM}};
  sr_184 = _RAND_188[15:0];
  _RAND_189 = {1{`RANDOM}};
  sr_185 = _RAND_189[15:0];
  _RAND_190 = {1{`RANDOM}};
  sr_186 = _RAND_190[15:0];
  _RAND_191 = {1{`RANDOM}};
  sr_187 = _RAND_191[15:0];
  _RAND_192 = {1{`RANDOM}};
  sr_188 = _RAND_192[15:0];
  _RAND_193 = {1{`RANDOM}};
  sr_189 = _RAND_193[15:0];
  _RAND_194 = {1{`RANDOM}};
  sr_190 = _RAND_194[15:0];
  _RAND_195 = {1{`RANDOM}};
  sr_191 = _RAND_195[15:0];
  _RAND_196 = {1{`RANDOM}};
  sr_192 = _RAND_196[15:0];
  _RAND_197 = {1{`RANDOM}};
  sr_193 = _RAND_197[15:0];
  _RAND_198 = {1{`RANDOM}};
  sr_194 = _RAND_198[15:0];
  _RAND_199 = {1{`RANDOM}};
  sr_195 = _RAND_199[15:0];
  _RAND_200 = {1{`RANDOM}};
  sr_196 = _RAND_200[15:0];
  _RAND_201 = {1{`RANDOM}};
  sr_197 = _RAND_201[15:0];
  _RAND_202 = {1{`RANDOM}};
  sr_198 = _RAND_202[15:0];
  _RAND_203 = {1{`RANDOM}};
  sr_199 = _RAND_203[15:0];
  _RAND_204 = {1{`RANDOM}};
  alphaQ8 = _RAND_204[8:0];
  _RAND_205 = {1{`RANDOM}};
  dacCnt = _RAND_205[7:0];
  _RAND_206 = {1{`RANDOM}};
  io_dacWriteReq_REG = _RAND_206[0:0];
`endif
  `endif
end
`ifdef FIRRTL_AFTER_INITIAL
`FIRRTL_AFTER_INITIAL
`endif
`endif
endmodule
module Step2Top(
  input         clock,
  input         reset,
  input         io_keyRaw_0,
  input         io_keyRaw_1,
  input         io_keyRaw_2,
  input         io_keyRaw_3,
  output        io_modeSel,
  output [3:0]  io_attenIdx,
  output [2:0]  io_modIdx,
  output [2:0]  io_delayIdx,
  output        io_led_0,
  output        io_led_1,
  output        io_led_2,
  output        io_led_3,
  output [15:0] io_dacData,
  output        io_dacWriteReq
);
  wire  kd1_clock;
  wire  kd1_reset;
  wire  kd1_io_raw_in;
  wire  kd1_io_pulse;
  wire  kd1_io_stable;
  wire  kd2_clock;
  wire  kd2_reset;
  wire  kd2_io_raw_in;
  wire  kd2_io_pulse;
  wire  kd2_io_stable;
  wire  kd3_clock;
  wire  kd3_reset;
  wire  kd3_io_raw_in;
  wire  kd3_io_pulse;
  wire  kd3_io_stable;
  wire  kd4_clock;
  wire  kd4_reset;
  wire  kd4_io_raw_in;
  wire  kd4_io_pulse;
  wire  kd4_io_stable;
  wire  fsm_clock;
  wire  fsm_reset;
  wire  fsm_io_key1Pulse;
  wire  fsm_io_key2Pulse;
  wire  fsm_io_key3Pulse;
  wire  fsm_io_key4Pulse;
  wire  fsm_io_modeSel;
  wire [3:0] fsm_io_attenIdx;
  wire [2:0] fsm_io_modIdx;
  wire [2:0] fsm_io_delayIdx;
  wire  fsm_io_led_0;
  wire  fsm_io_led_1;
  wire  fsm_io_led_2;
  wire  fsm_io_led_3;
  wire  am_clock;
  wire  am_reset;
  wire  am_io_modeSel;
  wire [3:0] am_io_attenIdx;
  wire [2:0] am_io_modIdx;
  wire [2:0] am_io_delayIdx;
  wire [15:0] am_io_dacData;
  wire  am_io_dacWriteReq;
  wire  _kd1_io_raw_in_T = ~io_keyRaw_0;
  wire  _kd2_io_raw_in_T = ~io_keyRaw_1;
  wire  _kd3_io_raw_in_T = ~io_keyRaw_2;
  wire  _kd4_io_raw_in_T = ~io_keyRaw_3;
  KeyDebounce kd1 (
    .clock(kd1_clock),
    .reset(kd1_reset),
    .io_raw_in(kd1_io_raw_in),
    .io_pulse(kd1_io_pulse),
    .io_stable(kd1_io_stable)
  );
  KeyDebounce kd2 (
    .clock(kd2_clock),
    .reset(kd2_reset),
    .io_raw_in(kd2_io_raw_in),
    .io_pulse(kd2_io_pulse),
    .io_stable(kd2_io_stable)
  );
  KeyDebounce kd3 (
    .clock(kd3_clock),
    .reset(kd3_reset),
    .io_raw_in(kd3_io_raw_in),
    .io_pulse(kd3_io_pulse),
    .io_stable(kd3_io_stable)
  );
  KeyDebounce kd4 (
    .clock(kd4_clock),
    .reset(kd4_reset),
    .io_raw_in(kd4_io_raw_in),
    .io_pulse(kd4_io_pulse),
    .io_stable(kd4_io_stable)
  );
  ParamControlFSM fsm (
    .clock(fsm_clock),
    .reset(fsm_reset),
    .io_key1Pulse(fsm_io_key1Pulse),
    .io_key2Pulse(fsm_io_key2Pulse),
    .io_key3Pulse(fsm_io_key3Pulse),
    .io_key4Pulse(fsm_io_key4Pulse),
    .io_modeSel(fsm_io_modeSel),
    .io_attenIdx(fsm_io_attenIdx),
    .io_modIdx(fsm_io_modIdx),
    .io_delayIdx(fsm_io_delayIdx),
    .io_led_0(fsm_io_led_0),
    .io_led_1(fsm_io_led_1),
    .io_led_2(fsm_io_led_2),
    .io_led_3(fsm_io_led_3)
  );
  AMStep2Generator am (
    .clock(am_clock),
    .reset(am_reset),
    .io_modeSel(am_io_modeSel),
    .io_attenIdx(am_io_attenIdx),
    .io_modIdx(am_io_modIdx),
    .io_delayIdx(am_io_delayIdx),
    .io_dacData(am_io_dacData),
    .io_dacWriteReq(am_io_dacWriteReq)
  );
  assign io_modeSel = fsm_io_modeSel;
  assign io_attenIdx = fsm_io_attenIdx;
  assign io_modIdx = fsm_io_modIdx;
  assign io_delayIdx = fsm_io_delayIdx;
  assign io_led_0 = fsm_io_led_0;
  assign io_led_1 = fsm_io_led_1;
  assign io_led_2 = 1'h0;
  assign io_led_3 = 1'h0;
  assign io_dacData = am_io_dacData;
  assign io_dacWriteReq = am_io_dacWriteReq;
  assign kd1_clock = clock;
  assign kd1_reset = reset;
  assign kd1_io_raw_in = ~io_keyRaw_0;
  assign kd2_clock = clock;
  assign kd2_reset = reset;
  assign kd2_io_raw_in = ~io_keyRaw_1;
  assign kd3_clock = clock;
  assign kd3_reset = reset;
  assign kd3_io_raw_in = ~io_keyRaw_2;
  assign kd4_clock = clock;
  assign kd4_reset = reset;
  assign kd4_io_raw_in = ~io_keyRaw_3;
  assign fsm_clock = clock;
  assign fsm_reset = reset;
  assign fsm_io_key1Pulse = kd1_io_pulse;
  assign fsm_io_key2Pulse = kd2_io_pulse;
  assign fsm_io_key3Pulse = kd3_io_pulse;
  assign fsm_io_key4Pulse = kd4_io_pulse;
  assign am_clock = clock;
  assign am_reset = reset;
  assign am_io_modeSel = fsm_io_modeSel;
  assign am_io_attenIdx = fsm_io_attenIdx;
  assign am_io_modIdx = fsm_io_modIdx;
  assign am_io_delayIdx = fsm_io_delayIdx;
endmodule
