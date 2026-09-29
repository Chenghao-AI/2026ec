`timescale 1ns / 1ps
module SineWaveGenerator(

  input         clock,

  input         reset,

  input         io_enable,

  output [15:0] io_dac_data,

  output        io_write_req

);

`ifdef RANDOMIZE_REG_INIT

  reg [31:0] _RAND_0;

  reg [31:0] _RAND_1;

  reg [31:0] _RAND_2;

`endif

  reg [15:0] phase;

  reg [15:0] tick_counter;

  wire  _T = tick_counter >= 16'h0f9f;

  wire [15:0] _phase_T_1 = phase + 16'h0106;

  wire [15:0] _tick_counter_T_1 = tick_counter + 16'h1;

  wire  update_req = io_enable & _T;

  wire [7:0] sin_index = phase[15:8];

  reg [15:0] dac_reg;

  wire [15:0] _GEN_7 = 8'h1 == sin_index ? 16'h8323 : 16'h7fff;

  wire [15:0] _GEN_8 = 8'h2 == sin_index ? 16'h8647 : _GEN_7;

  wire [15:0] _GEN_9 = 8'h3 == sin_index ? 16'h896a : _GEN_8;

  wire [15:0] _GEN_10 = 8'h4 == sin_index ? 16'h8c8b : _GEN_9;

  wire [15:0] _GEN_11 = 8'h5 == sin_index ? 16'h8faa : _GEN_10;

  wire [15:0] _GEN_12 = 8'h6 == sin_index ? 16'h92c7 : _GEN_11;

  wire [15:0] _GEN_13 = 8'h7 == sin_index ? 16'h95e1 : _GEN_12;

  wire [15:0] _GEN_14 = 8'h8 == sin_index ? 16'h98f8 : _GEN_13;

  wire [15:0] _GEN_15 = 8'h9 == sin_index ? 16'h9c0a : _GEN_14;

  wire [15:0] _GEN_16 = 8'ha == sin_index ? 16'h9f19 : _GEN_15;

  wire [15:0] _GEN_17 = 8'hb == sin_index ? 16'ha223 : _GEN_16;

  wire [15:0] _GEN_18 = 8'hc == sin_index ? 16'ha527 : _GEN_17;

  wire [15:0] _GEN_19 = 8'hd == sin_index ? 16'ha826 : _GEN_18;

  wire [15:0] _GEN_20 = 8'he == sin_index ? 16'hab1e : _GEN_19;

  wire [15:0] _GEN_21 = 8'hf == sin_index ? 16'hae10 : _GEN_20;

  wire [15:0] _GEN_22 = 8'h10 == sin_index ? 16'hb0fb : _GEN_21;

  wire [15:0] _GEN_23 = 8'h11 == sin_index ? 16'hb3de : _GEN_22;

  wire [15:0] _GEN_24 = 8'h12 == sin_index ? 16'hb6b9 : _GEN_23;

  wire [15:0] _GEN_25 = 8'h13 == sin_index ? 16'hb98c : _GEN_24;

  wire [15:0] _GEN_26 = 8'h14 == sin_index ? 16'hbc55 : _GEN_25;

  wire [15:0] _GEN_27 = 8'h15 == sin_index ? 16'hbf16 : _GEN_26;

  wire [15:0] _GEN_28 = 8'h16 == sin_index ? 16'hc1cd : _GEN_27;

  wire [15:0] _GEN_29 = 8'h17 == sin_index ? 16'hc47a : _GEN_28;

  wire [15:0] _GEN_30 = 8'h18 == sin_index ? 16'hc71c : _GEN_29;

  wire [15:0] _GEN_31 = 8'h19 == sin_index ? 16'hc9b3 : _GEN_30;

  wire [15:0] _GEN_32 = 8'h1a == sin_index ? 16'hcc3f : _GEN_31;

  wire [15:0] _GEN_33 = 8'h1b == sin_index ? 16'hcebf : _GEN_32;

  wire [15:0] _GEN_34 = 8'h1c == sin_index ? 16'hd132 : _GEN_33;

  wire [15:0] _GEN_35 = 8'h1d == sin_index ? 16'hd39a : _GEN_34;

  wire [15:0] _GEN_36 = 8'h1e == sin_index ? 16'hd5f4 : _GEN_35;

  wire [15:0] _GEN_37 = 8'h1f == sin_index ? 16'hd842 : _GEN_36;

  wire [15:0] _GEN_38 = 8'h20 == sin_index ? 16'hda81 : _GEN_37;

  wire [15:0] _GEN_39 = 8'h21 == sin_index ? 16'hdcb3 : _GEN_38;

  wire [15:0] _GEN_40 = 8'h22 == sin_index ? 16'hded6 : _GEN_39;

  wire [15:0] _GEN_41 = 8'h23 == sin_index ? 16'he0eb : _GEN_40;

  wire [15:0] _GEN_42 = 8'h24 == sin_index ? 16'he2f1 : _GEN_41;

  wire [15:0] _GEN_43 = 8'h25 == sin_index ? 16'he4e7 : _GEN_42;

  wire [15:0] _GEN_44 = 8'h26 == sin_index ? 16'he6ce : _GEN_43;

  wire [15:0] _GEN_45 = 8'h27 == sin_index ? 16'he8a5 : _GEN_44;

  wire [15:0] _GEN_46 = 8'h28 == sin_index ? 16'hea6c : _GEN_45;

  wire [15:0] _GEN_47 = 8'h29 == sin_index ? 16'hec23 : _GEN_46;

  wire [15:0] _GEN_48 = 8'h2a == sin_index ? 16'hedc9 : _GEN_47;

  wire [15:0] _GEN_49 = 8'h2b == sin_index ? 16'hef5e : _GEN_48;

  wire [15:0] _GEN_50 = 8'h2c == sin_index ? 16'hf0e1 : _GEN_49;

  wire [15:0] _GEN_51 = 8'h2d == sin_index ? 16'hf254 : _GEN_50;

  wire [15:0] _GEN_52 = 8'h2e == sin_index ? 16'hf3b4 : _GEN_51;

  wire [15:0] _GEN_53 = 8'h2f == sin_index ? 16'hf503 : _GEN_52;

  wire [15:0] _GEN_54 = 8'h30 == sin_index ? 16'hf640 : _GEN_53;

  wire [15:0] _GEN_55 = 8'h31 == sin_index ? 16'hf76b : _GEN_54;

  wire [15:0] _GEN_56 = 8'h32 == sin_index ? 16'hf883 : _GEN_55;

  wire [15:0] _GEN_57 = 8'h33 == sin_index ? 16'hf989 : _GEN_56;

  wire [15:0] _GEN_58 = 8'h34 == sin_index ? 16'hfa7c : _GEN_57;

  wire [15:0] _GEN_59 = 8'h35 == sin_index ? 16'hfb5c : _GEN_58;

  wire [15:0] _GEN_60 = 8'h36 == sin_index ? 16'hfc28 : _GEN_59;

  wire [15:0] _GEN_61 = 8'h37 == sin_index ? 16'hfce2 : _GEN_60;

  wire [15:0] _GEN_62 = 8'h38 == sin_index ? 16'hfd89 : _GEN_61;

  wire [15:0] _GEN_63 = 8'h39 == sin_index ? 16'hfe1c : _GEN_62;

  wire [15:0] _GEN_64 = 8'h3a == sin_index ? 16'hfe9c : _GEN_63;

  wire [15:0] _GEN_65 = 8'h3b == sin_index ? 16'hff08 : _GEN_64;

  wire [15:0] _GEN_66 = 8'h3c == sin_index ? 16'hff61 : _GEN_65;

  wire [15:0] _GEN_67 = 8'h3d == sin_index ? 16'hffa6 : _GEN_66;

  wire [15:0] _GEN_68 = 8'h3e == sin_index ? 16'hffd7 : _GEN_67;

  wire [15:0] _GEN_69 = 8'h3f == sin_index ? 16'hfff5 : _GEN_68;

  wire [15:0] _GEN_70 = 8'h40 == sin_index ? 16'hffff : _GEN_69;

  wire [15:0] _GEN_71 = 8'h41 == sin_index ? 16'hfff5 : _GEN_70;

  wire [15:0] _GEN_72 = 8'h42 == sin_index ? 16'hffd7 : _GEN_71;

  wire [15:0] _GEN_73 = 8'h43 == sin_index ? 16'hffa6 : _GEN_72;

  wire [15:0] _GEN_74 = 8'h44 == sin_index ? 16'hff61 : _GEN_73;

  wire [15:0] _GEN_75 = 8'h45 == sin_index ? 16'hff08 : _GEN_74;

  wire [15:0] _GEN_76 = 8'h46 == sin_index ? 16'hfe9c : _GEN_75;

  wire [15:0] _GEN_77 = 8'h47 == sin_index ? 16'hfe1c : _GEN_76;

  wire [15:0] _GEN_78 = 8'h48 == sin_index ? 16'hfd89 : _GEN_77;

  wire [15:0] _GEN_79 = 8'h49 == sin_index ? 16'hfce2 : _GEN_78;

  wire [15:0] _GEN_80 = 8'h4a == sin_index ? 16'hfc28 : _GEN_79;

  wire [15:0] _GEN_81 = 8'h4b == sin_index ? 16'hfb5c : _GEN_80;

  wire [15:0] _GEN_82 = 8'h4c == sin_index ? 16'hfa7c : _GEN_81;

  wire [15:0] _GEN_83 = 8'h4d == sin_index ? 16'hf989 : _GEN_82;

  wire [15:0] _GEN_84 = 8'h4e == sin_index ? 16'hf883 : _GEN_83;

  wire [15:0] _GEN_85 = 8'h4f == sin_index ? 16'hf76b : _GEN_84;

  wire [15:0] _GEN_86 = 8'h50 == sin_index ? 16'hf640 : _GEN_85;

  wire [15:0] _GEN_87 = 8'h51 == sin_index ? 16'hf503 : _GEN_86;

  wire [15:0] _GEN_88 = 8'h52 == sin_index ? 16'hf3b4 : _GEN_87;

  wire [15:0] _GEN_89 = 8'h53 == sin_index ? 16'hf254 : _GEN_88;

  wire [15:0] _GEN_90 = 8'h54 == sin_index ? 16'hf0e1 : _GEN_89;

  wire [15:0] _GEN_91 = 8'h55 == sin_index ? 16'hef5e : _GEN_90;

  wire [15:0] _GEN_92 = 8'h56 == sin_index ? 16'hedc9 : _GEN_91;

  wire [15:0] _GEN_93 = 8'h57 == sin_index ? 16'hec23 : _GEN_92;

  wire [15:0] _GEN_94 = 8'h58 == sin_index ? 16'hea6c : _GEN_93;

  wire [15:0] _GEN_95 = 8'h59 == sin_index ? 16'he8a5 : _GEN_94;

  wire [15:0] _GEN_96 = 8'h5a == sin_index ? 16'he6ce : _GEN_95;

  wire [15:0] _GEN_97 = 8'h5b == sin_index ? 16'he4e7 : _GEN_96;

  wire [15:0] _GEN_98 = 8'h5c == sin_index ? 16'he2f1 : _GEN_97;

  wire [15:0] _GEN_99 = 8'h5d == sin_index ? 16'he0eb : _GEN_98;

  wire [15:0] _GEN_100 = 8'h5e == sin_index ? 16'hded6 : _GEN_99;

  wire [15:0] _GEN_101 = 8'h5f == sin_index ? 16'hdcb3 : _GEN_100;

  wire [15:0] _GEN_102 = 8'h60 == sin_index ? 16'hda81 : _GEN_101;

  wire [15:0] _GEN_103 = 8'h61 == sin_index ? 16'hd842 : _GEN_102;

  wire [15:0] _GEN_104 = 8'h62 == sin_index ? 16'hd5f4 : _GEN_103;

  wire [15:0] _GEN_105 = 8'h63 == sin_index ? 16'hd39a : _GEN_104;

  wire [15:0] _GEN_106 = 8'h64 == sin_index ? 16'hd132 : _GEN_105;

  wire [15:0] _GEN_107 = 8'h65 == sin_index ? 16'hcebf : _GEN_106;

  wire [15:0] _GEN_108 = 8'h66 == sin_index ? 16'hcc3f : _GEN_107;

  wire [15:0] _GEN_109 = 8'h67 == sin_index ? 16'hc9b3 : _GEN_108;

  wire [15:0] _GEN_110 = 8'h68 == sin_index ? 16'hc71c : _GEN_109;

  wire [15:0] _GEN_111 = 8'h69 == sin_index ? 16'hc47a : _GEN_110;

  wire [15:0] _GEN_112 = 8'h6a == sin_index ? 16'hc1cd : _GEN_111;

  wire [15:0] _GEN_113 = 8'h6b == sin_index ? 16'hbf16 : _GEN_112;

  wire [15:0] _GEN_114 = 8'h6c == sin_index ? 16'hbc55 : _GEN_113;

  wire [15:0] _GEN_115 = 8'h6d == sin_index ? 16'hb98c : _GEN_114;

  wire [15:0] _GEN_116 = 8'h6e == sin_index ? 16'hb6b9 : _GEN_115;

  wire [15:0] _GEN_117 = 8'h6f == sin_index ? 16'hb3de : _GEN_116;

  wire [15:0] _GEN_118 = 8'h70 == sin_index ? 16'hb0fb : _GEN_117;

  wire [15:0] _GEN_119 = 8'h71 == sin_index ? 16'hae10 : _GEN_118;

  wire [15:0] _GEN_120 = 8'h72 == sin_index ? 16'hab1e : _GEN_119;

  wire [15:0] _GEN_121 = 8'h73 == sin_index ? 16'ha826 : _GEN_120;

  wire [15:0] _GEN_122 = 8'h74 == sin_index ? 16'ha527 : _GEN_121;

  wire [15:0] _GEN_123 = 8'h75 == sin_index ? 16'ha223 : _GEN_122;

  wire [15:0] _GEN_124 = 8'h76 == sin_index ? 16'h9f19 : _GEN_123;

  wire [15:0] _GEN_125 = 8'h77 == sin_index ? 16'h9c0a : _GEN_124;

  wire [15:0] _GEN_126 = 8'h78 == sin_index ? 16'h98f8 : _GEN_125;

  wire [15:0] _GEN_127 = 8'h79 == sin_index ? 16'h95e1 : _GEN_126;

  wire [15:0] _GEN_128 = 8'h7a == sin_index ? 16'h92c7 : _GEN_127;

  wire [15:0] _GEN_129 = 8'h7b == sin_index ? 16'h8faa : _GEN_128;

  wire [15:0] _GEN_130 = 8'h7c == sin_index ? 16'h8c8b : _GEN_129;

  wire [15:0] _GEN_131 = 8'h7d == sin_index ? 16'h896a : _GEN_130;

  wire [15:0] _GEN_132 = 8'h7e == sin_index ? 16'h8647 : _GEN_131;

  wire [15:0] _GEN_133 = 8'h7f == sin_index ? 16'h8323 : _GEN_132;

  wire [15:0] _GEN_134 = 8'h80 == sin_index ? 16'h7fff : _GEN_133;

  wire [15:0] _GEN_135 = 8'h81 == sin_index ? 16'h7cdb : _GEN_134;

  wire [15:0] _GEN_136 = 8'h82 == sin_index ? 16'h79b7 : _GEN_135;

  wire [15:0] _GEN_137 = 8'h83 == sin_index ? 16'h7694 : _GEN_136;

  wire [15:0] _GEN_138 = 8'h84 == sin_index ? 16'h7373 : _GEN_137;

  wire [15:0] _GEN_139 = 8'h85 == sin_index ? 16'h7054 : _GEN_138;

  wire [15:0] _GEN_140 = 8'h86 == sin_index ? 16'h6d37 : _GEN_139;

  wire [15:0] _GEN_141 = 8'h87 == sin_index ? 16'h6a1d : _GEN_140;

  wire [15:0] _GEN_142 = 8'h88 == sin_index ? 16'h6706 : _GEN_141;

  wire [15:0] _GEN_143 = 8'h89 == sin_index ? 16'h63f4 : _GEN_142;

  wire [15:0] _GEN_144 = 8'h8a == sin_index ? 16'h60e5 : _GEN_143;

  wire [15:0] _GEN_145 = 8'h8b == sin_index ? 16'h5ddb : _GEN_144;

  wire [15:0] _GEN_146 = 8'h8c == sin_index ? 16'h5ad7 : _GEN_145;

  wire [15:0] _GEN_147 = 8'h8d == sin_index ? 16'h57d8 : _GEN_146;

  wire [15:0] _GEN_148 = 8'h8e == sin_index ? 16'h54e0 : _GEN_147;

  wire [15:0] _GEN_149 = 8'h8f == sin_index ? 16'h51ee : _GEN_148;

  wire [15:0] _GEN_150 = 8'h90 == sin_index ? 16'h4f03 : _GEN_149;

  wire [15:0] _GEN_151 = 8'h91 == sin_index ? 16'h4c20 : _GEN_150;

  wire [15:0] _GEN_152 = 8'h92 == sin_index ? 16'h4945 : _GEN_151;

  wire [15:0] _GEN_153 = 8'h93 == sin_index ? 16'h4672 : _GEN_152;

  wire [15:0] _GEN_154 = 8'h94 == sin_index ? 16'h43a9 : _GEN_153;

  wire [15:0] _GEN_155 = 8'h95 == sin_index ? 16'h40e8 : _GEN_154;

  wire [15:0] _GEN_156 = 8'h96 == sin_index ? 16'h3e31 : _GEN_155;

  wire [15:0] _GEN_157 = 8'h97 == sin_index ? 16'h3b84 : _GEN_156;

  wire [15:0] _GEN_158 = 8'h98 == sin_index ? 16'h38e2 : _GEN_157;

  wire [15:0] _GEN_159 = 8'h99 == sin_index ? 16'h364b : _GEN_158;

  wire [15:0] _GEN_160 = 8'h9a == sin_index ? 16'h33bf : _GEN_159;

  wire [15:0] _GEN_161 = 8'h9b == sin_index ? 16'h313f : _GEN_160;

  wire [15:0] _GEN_162 = 8'h9c == sin_index ? 16'h2ecc : _GEN_161;

  wire [15:0] _GEN_163 = 8'h9d == sin_index ? 16'h2c64 : _GEN_162;

  wire [15:0] _GEN_164 = 8'h9e == sin_index ? 16'h2a0a : _GEN_163;

  wire [15:0] _GEN_165 = 8'h9f == sin_index ? 16'h27bc : _GEN_164;

  wire [15:0] _GEN_166 = 8'ha0 == sin_index ? 16'h257d : _GEN_165;

  wire [15:0] _GEN_167 = 8'ha1 == sin_index ? 16'h234b : _GEN_166;

  wire [15:0] _GEN_168 = 8'ha2 == sin_index ? 16'h2128 : _GEN_167;

  wire [15:0] _GEN_169 = 8'ha3 == sin_index ? 16'h1f13 : _GEN_168;

  wire [15:0] _GEN_170 = 8'ha4 == sin_index ? 16'h1d0d : _GEN_169;

  wire [15:0] _GEN_171 = 8'ha5 == sin_index ? 16'h1b17 : _GEN_170;

  wire [15:0] _GEN_172 = 8'ha6 == sin_index ? 16'h1930 : _GEN_171;

  wire [15:0] _GEN_173 = 8'ha7 == sin_index ? 16'h1759 : _GEN_172;

  wire [15:0] _GEN_174 = 8'ha8 == sin_index ? 16'h1592 : _GEN_173;

  wire [15:0] _GEN_175 = 8'ha9 == sin_index ? 16'h13db : _GEN_174;

  wire [15:0] _GEN_176 = 8'haa == sin_index ? 16'h1235 : _GEN_175;

  wire [15:0] _GEN_177 = 8'hab == sin_index ? 16'h10a0 : _GEN_176;

  wire [15:0] _GEN_178 = 8'hac == sin_index ? 16'hf1d : _GEN_177;

  wire [15:0] _GEN_179 = 8'had == sin_index ? 16'hdaa : _GEN_178;

  wire [15:0] _GEN_180 = 8'hae == sin_index ? 16'hc4a : _GEN_179;

  wire [15:0] _GEN_181 = 8'haf == sin_index ? 16'hafb : _GEN_180;

  wire [15:0] _GEN_182 = 8'hb0 == sin_index ? 16'h9be : _GEN_181;

  wire [15:0] _GEN_183 = 8'hb1 == sin_index ? 16'h893 : _GEN_182;

  wire [15:0] _GEN_184 = 8'hb2 == sin_index ? 16'h77b : _GEN_183;

  wire [15:0] _GEN_185 = 8'hb3 == sin_index ? 16'h675 : _GEN_184;

  wire [15:0] _GEN_186 = 8'hb4 == sin_index ? 16'h582 : _GEN_185;

  wire [15:0] _GEN_187 = 8'hb5 == sin_index ? 16'h4a2 : _GEN_186;

  wire [15:0] _GEN_188 = 8'hb6 == sin_index ? 16'h3d6 : _GEN_187;

  wire [15:0] _GEN_189 = 8'hb7 == sin_index ? 16'h31c : _GEN_188;

  wire [15:0] _GEN_190 = 8'hb8 == sin_index ? 16'h275 : _GEN_189;

  wire [15:0] _GEN_191 = 8'hb9 == sin_index ? 16'h1e2 : _GEN_190;

  wire [15:0] _GEN_192 = 8'hba == sin_index ? 16'h162 : _GEN_191;

  wire [15:0] _GEN_193 = 8'hbb == sin_index ? 16'hf6 : _GEN_192;

  wire [15:0] _GEN_194 = 8'hbc == sin_index ? 16'h9d : _GEN_193;

  wire [15:0] _GEN_195 = 8'hbd == sin_index ? 16'h58 : _GEN_194;

  wire [15:0] _GEN_196 = 8'hbe == sin_index ? 16'h27 : _GEN_195;

  wire [15:0] _GEN_197 = 8'hbf == sin_index ? 16'h9 : _GEN_196;

  wire [15:0] _GEN_198 = 8'hc0 == sin_index ? 16'h0 : _GEN_197;

  wire [15:0] _GEN_199 = 8'hc1 == sin_index ? 16'h9 : _GEN_198;

  wire [15:0] _GEN_200 = 8'hc2 == sin_index ? 16'h27 : _GEN_199;

  wire [15:0] _GEN_201 = 8'hc3 == sin_index ? 16'h58 : _GEN_200;

  wire [15:0] _GEN_202 = 8'hc4 == sin_index ? 16'h9d : _GEN_201;

  wire [15:0] _GEN_203 = 8'hc5 == sin_index ? 16'hf6 : _GEN_202;

  wire [15:0] _GEN_204 = 8'hc6 == sin_index ? 16'h162 : _GEN_203;

  wire [15:0] _GEN_205 = 8'hc7 == sin_index ? 16'h1e2 : _GEN_204;

  wire [15:0] _GEN_206 = 8'hc8 == sin_index ? 16'h275 : _GEN_205;

  wire [15:0] _GEN_207 = 8'hc9 == sin_index ? 16'h31c : _GEN_206;

  wire [15:0] _GEN_208 = 8'hca == sin_index ? 16'h3d6 : _GEN_207;

  wire [15:0] _GEN_209 = 8'hcb == sin_index ? 16'h4a2 : _GEN_208;

  wire [15:0] _GEN_210 = 8'hcc == sin_index ? 16'h582 : _GEN_209;

  wire [15:0] _GEN_211 = 8'hcd == sin_index ? 16'h675 : _GEN_210;

  wire [15:0] _GEN_212 = 8'hce == sin_index ? 16'h77b : _GEN_211;

  wire [15:0] _GEN_213 = 8'hcf == sin_index ? 16'h893 : _GEN_212;

  wire [15:0] _GEN_214 = 8'hd0 == sin_index ? 16'h9be : _GEN_213;

  wire [15:0] _GEN_215 = 8'hd1 == sin_index ? 16'hafb : _GEN_214;

  wire [15:0] _GEN_216 = 8'hd2 == sin_index ? 16'hc4a : _GEN_215;

  wire [15:0] _GEN_217 = 8'hd3 == sin_index ? 16'hdaa : _GEN_216;

  wire [15:0] _GEN_218 = 8'hd4 == sin_index ? 16'hf1d : _GEN_217;

  wire [15:0] _GEN_219 = 8'hd5 == sin_index ? 16'h10a0 : _GEN_218;

  wire [15:0] _GEN_220 = 8'hd6 == sin_index ? 16'h1235 : _GEN_219;

  wire [15:0] _GEN_221 = 8'hd7 == sin_index ? 16'h13db : _GEN_220;

  wire [15:0] _GEN_222 = 8'hd8 == sin_index ? 16'h1592 : _GEN_221;

  wire [15:0] _GEN_223 = 8'hd9 == sin_index ? 16'h1759 : _GEN_222;

  wire [15:0] _GEN_224 = 8'hda == sin_index ? 16'h1930 : _GEN_223;

  wire [15:0] _GEN_225 = 8'hdb == sin_index ? 16'h1b17 : _GEN_224;

  wire [15:0] _GEN_226 = 8'hdc == sin_index ? 16'h1d0d : _GEN_225;

  wire [15:0] _GEN_227 = 8'hdd == sin_index ? 16'h1f13 : _GEN_226;

  wire [15:0] _GEN_228 = 8'hde == sin_index ? 16'h2128 : _GEN_227;

  wire [15:0] _GEN_229 = 8'hdf == sin_index ? 16'h234b : _GEN_228;

  wire [15:0] _GEN_230 = 8'he0 == sin_index ? 16'h257d : _GEN_229;

  wire [15:0] _GEN_231 = 8'he1 == sin_index ? 16'h27bc : _GEN_230;

  wire [15:0] _GEN_232 = 8'he2 == sin_index ? 16'h2a0a : _GEN_231;

  wire [15:0] _GEN_233 = 8'he3 == sin_index ? 16'h2c64 : _GEN_232;

  wire [15:0] _GEN_234 = 8'he4 == sin_index ? 16'h2ecc : _GEN_233;

  wire [15:0] _GEN_235 = 8'he5 == sin_index ? 16'h313f : _GEN_234;

  wire [15:0] _GEN_236 = 8'he6 == sin_index ? 16'h33bf : _GEN_235;

  wire [15:0] _GEN_237 = 8'he7 == sin_index ? 16'h364b : _GEN_236;

  wire [15:0] _GEN_238 = 8'he8 == sin_index ? 16'h38e2 : _GEN_237;

  wire [15:0] _GEN_239 = 8'he9 == sin_index ? 16'h3b84 : _GEN_238;

  wire [15:0] _GEN_240 = 8'hea == sin_index ? 16'h3e31 : _GEN_239;

  wire [15:0] _GEN_241 = 8'heb == sin_index ? 16'h40e8 : _GEN_240;

  wire [15:0] _GEN_242 = 8'hec == sin_index ? 16'h43a9 : _GEN_241;

  wire [15:0] _GEN_243 = 8'hed == sin_index ? 16'h4672 : _GEN_242;

  wire [15:0] _GEN_244 = 8'hee == sin_index ? 16'h4945 : _GEN_243;

  wire [15:0] _GEN_245 = 8'hef == sin_index ? 16'h4c20 : _GEN_244;

  wire [15:0] _GEN_246 = 8'hf0 == sin_index ? 16'h4f03 : _GEN_245;

  wire [15:0] _GEN_247 = 8'hf1 == sin_index ? 16'h51ee : _GEN_246;

  wire [15:0] _GEN_248 = 8'hf2 == sin_index ? 16'h54e0 : _GEN_247;

  wire [15:0] _GEN_249 = 8'hf3 == sin_index ? 16'h57d8 : _GEN_248;

  wire [15:0] _GEN_250 = 8'hf4 == sin_index ? 16'h5ad7 : _GEN_249;

  wire [15:0] _GEN_251 = 8'hf5 == sin_index ? 16'h5ddb : _GEN_250;

  wire [15:0] _GEN_252 = 8'hf6 == sin_index ? 16'h60e5 : _GEN_251;

  wire [15:0] _GEN_253 = 8'hf7 == sin_index ? 16'h63f4 : _GEN_252;

  wire [15:0] _GEN_254 = 8'hf8 == sin_index ? 16'h6706 : _GEN_253;

  wire [15:0] _GEN_255 = 8'hf9 == sin_index ? 16'h6a1d : _GEN_254;

  wire [15:0] _GEN_256 = 8'hfa == sin_index ? 16'h6d37 : _GEN_255;

  wire [15:0] _GEN_257 = 8'hfb == sin_index ? 16'h7054 : _GEN_256;

  wire [15:0] _GEN_258 = 8'hfc == sin_index ? 16'h7373 : _GEN_257;

  wire [15:0] _GEN_259 = 8'hfd == sin_index ? 16'h7694 : _GEN_258;

  assign io_dac_data = dac_reg;

  assign io_write_req = io_enable & _T;

  always @(posedge clock) begin

    if (reset) begin

      phase <= 16'h0;

    end else if (io_enable) begin

      if (tick_counter >= 16'h0f9f) begin

        phase <= _phase_T_1;

      end

    end else begin

      phase <= 16'h0;

    end

    if (reset) begin

      tick_counter <= 16'h0;

    end else if (io_enable) begin

      if (tick_counter >= 16'h0f9f) begin

        tick_counter <= 16'h0;

      end else begin

        tick_counter <= _tick_counter_T_1;

      end

    end else begin

      tick_counter <= 16'h0;

    end

    if (reset) begin

      dac_reg <= 16'h8000;

    end else if (update_req) begin

      if (8'hff == sin_index) begin

        dac_reg <= 16'h7cdb;

      end else if (8'hfe == sin_index) begin

        dac_reg <= 16'h79b7;

      end else begin

        dac_reg <= _GEN_259;

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

  phase = _RAND_0[15:0];

  _RAND_1 = {1{`RANDOM}};

  tick_counter = _RAND_1[15:0];

  _RAND_2 = {1{`RANDOM}};

  dac_reg = _RAND_2[15:0];

`endif

  `endif

end

`ifdef FIRRTL_AFTER_INITIAL

`FIRRTL_AFTER_INITIAL

`endif

`endif

endmodule
