`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// crc16_ccitt.v — CRC-16/CCITT-FALSE (poly=0x1021, init=0xFFFF)
// ----------------------------------------------------------------------------
//   用查表法 (256 × 16 bit LUT) 实现单 byte 串行计算.
//
//   公式: crc = (crc << 8) ^ TABLE[((crc >> 8) ^ data) & 0xFF]
//   范围: TYPE + SEQ + LEN + Payload (不含 AA55)
//   输出顺序: 高字节先发 (大端)
//
//   用法:
//     1. crc_init = 1 (脉冲), crc_out = 0xFFFF
//     2. 对每个字节: data_in=byte, crc_tick=1 周期脉冲
//     3. 完成后读 crc_out
// ============================================================================
module crc16_ccitt (
    input  wire        clk,
    input  wire        rst,
    input  wire        crc_init,    // 1 周期脉冲, 重置 CRC = 0xFFFF
    input  wire [7:0]  data_in,
    input  wire        crc_tick,    // 1 周期脉冲, 喂入 1 字节
    output reg [15:0]  crc_out = 16'hFFFF
);

    // CRC-16/CCITT-FALSE 表 (256 项)
    reg [15:0] crc_table [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            crc_table[i] = 16'h0000;
        end
        // 0x1021 多项式
        crc_table[0]   = 16'h0000; crc_table[1]   = 16'h1021; crc_table[2]   = 16'h2042; crc_table[3]   = 16'h3063;
        crc_table[4]   = 16'h4084; crc_table[5]   = 16'h50A5; crc_table[6]   = 16'h60C6; crc_table[7]   = 16'h70E7;
        crc_table[8]   = 16'h8108; crc_table[9]   = 16'h9129; crc_table[10]  = 16'hA14A; crc_table[11]  = 16'hB16B;
        crc_table[12]  = 16'hC18C; crc_table[13]  = 16'hD1AD; crc_table[14]  = 16'hE1CE; crc_table[15]  = 16'hF1EF;
        crc_table[16]  = 16'h1231; crc_table[17]  = 16'h0210; crc_table[18]  = 16'h3273; crc_table[19]  = 16'h2252;
        crc_table[20]  = 16'h52B5; crc_table[21]  = 16'h4294; crc_table[22]  = 16'h72F7; crc_table[23]  = 16'h62D6;
        crc_table[24]  = 16'h9339; crc_table[25]  = 16'h8318; crc_table[26]  = 16'hB37B; crc_table[27]  = 16'hA35A;
        crc_table[28]  = 16'hD3BD; crc_table[29]  = 16'hC39C; crc_table[30]  = 16'hF3FF; crc_table[31]  = 16'hE3DE;
        crc_table[32]  = 16'h2462; crc_table[33]  = 16'h3443; crc_table[34]  = 16'h0420; crc_table[35]  = 16'h1401;
        crc_table[36]  = 16'h64E6; crc_table[37]  = 16'h74C7; crc_table[38]  = 16'h44A4; crc_table[39]  = 16'h5485;
        crc_table[40]  = 16'hA56A; crc_table[41]  = 16'hB54B; crc_table[42]  = 16'h8528; crc_table[43]  = 16'h9509;
        crc_table[44]  = 16'hE5EE; crc_table[45]  = 16'hF5CF; crc_table[46]  = 16'hC5AC; crc_table[47]  = 16'hD58D;
        crc_table[48]  = 16'h3653; crc_table[49]  = 16'h2672; crc_table[50]  = 16'h1611; crc_table[51]  = 16'h0630;
        crc_table[52]  = 16'h76D7; crc_table[53]  = 16'h66F6; crc_table[54]  = 16'h5695; crc_table[55]  = 16'h46B4;
        crc_table[56]  = 16'hB75B; crc_table[57]  = 16'hA77A; crc_table[58]  = 16'h9719; crc_table[59]  = 16'h8738;
        crc_table[60]  = 16'hF7DF; crc_table[61]  = 16'hE7FE; crc_table[62]  = 16'hD79D; crc_table[63]  = 16'hC7BC;
        crc_table[64]  = 16'h48C4; crc_table[65]  = 16'h58E5; crc_table[66]  = 16'h6886; crc_table[67]  = 16'h78A7;
        crc_table[68]  = 16'h0840; crc_table[69]  = 16'h1861; crc_table[70]  = 16'h2802; crc_table[71]  = 16'h3823;
        crc_table[72]  = 16'hC9CC; crc_table[73]  = 16'hD9ED; crc_table[74]  = 16'hE98E; crc_table[75]  = 16'hF9AF;
        crc_table[76]  = 16'h8948; crc_table[77]  = 16'h9969; crc_table[78]  = 16'hA90A; crc_table[79]  = 16'hB92B;
        crc_table[80]  = 16'h5AF5; crc_table[81]  = 16'h4AD4; crc_table[82]  = 16'h7AB7; crc_table[83]  = 16'h6A96;
        crc_table[84]  = 16'h1A71; crc_table[85]  = 16'h0A50; crc_table[86]  = 16'h3A33; crc_table[87]  = 16'h2A12;
        crc_table[88]  = 16'hDBFD; crc_table[89]  = 16'hCBDC; crc_table[90]  = 16'hFBBF; crc_table[91]  = 16'hEB9E;
        crc_table[92]  = 16'h9B79; crc_table[93]  = 16'h8B58; crc_table[94]  = 16'hBB3B; crc_table[95]  = 16'hAB1A;
        crc_table[96]  = 16'h6CA6; crc_table[97]  = 16'h7C87; crc_table[98]  = 16'h4CE4; crc_table[99]  = 16'h5CC5;
        crc_table[100] = 16'h2C22; crc_table[101] = 16'h3C03; crc_table[102] = 16'h0C60; crc_table[103] = 16'h1C41;
        crc_table[104] = 16'hEDAE; crc_table[105] = 16'hFD8F; crc_table[106] = 16'hCDEC; crc_table[107] = 16'hDDCD;
        crc_table[108] = 16'hAD2A; crc_table[109] = 16'hBD0B; crc_table[110] = 16'h8D68; crc_table[111] = 16'h9D49;
        crc_table[112] = 16'h7E97; crc_table[113] = 16'h6EB6; crc_table[114] = 16'h5ED5; crc_table[115] = 16'h4EF4;
        crc_table[116] = 16'h3E13; crc_table[117] = 16'h2E32; crc_table[118] = 16'h1E51; crc_table[119] = 16'h0E70;
        crc_table[120] = 16'hFF9F; crc_table[121] = 16'hEFBE; crc_table[122] = 16'hDFDD; crc_table[123] = 16'hCFFC;
        crc_table[124] = 16'hBF1B; crc_table[125] = 16'hAF3A; crc_table[126] = 16'h9F59; crc_table[127] = 16'h8F78;
        crc_table[128] = 16'h9188; crc_table[129] = 16'h81A9; crc_table[130] = 16'hB1CA; crc_table[131] = 16'hA1EB;
        crc_table[132] = 16'hD10C; crc_table[133] = 16'hC12D; crc_table[134] = 16'hF14E; crc_table[135] = 16'hE16F;
        crc_table[136] = 16'h1080; crc_table[137] = 16'h00A1; crc_table[138] = 16'h30C2; crc_table[139] = 16'h20E3;
        crc_table[140] = 16'h5004; crc_table[141] = 16'h4025; crc_table[142] = 16'h7046; crc_table[143] = 16'h6067;
        crc_table[144] = 16'h83B9; crc_table[145] = 16'h9398; crc_table[146] = 16'hA3FB; crc_table[147] = 16'hB3DA;
        crc_table[148] = 16'hC33D; crc_table[149] = 16'hD31C; crc_table[150] = 16'hE37F; crc_table[151] = 16'hF35E;
        crc_table[152] = 16'h02B1; crc_table[153] = 16'h1290; crc_table[154] = 16'h22F3; crc_table[155] = 16'h32D2;
        crc_table[156] = 16'h4235; crc_table[157] = 16'h5214; crc_table[158] = 16'h6277; crc_table[159] = 16'h7256;
        crc_table[160] = 16'hB5EA; crc_table[161] = 16'hA5CB; crc_table[162] = 16'h95A8; crc_table[163] = 16'h8589;
        crc_table[164] = 16'hF56E; crc_table[165] = 16'hE54F; crc_table[166] = 16'hD52C; crc_table[167] = 16'hC50D;
        crc_table[168] = 16'h34E2; crc_table[169] = 16'h24C3; crc_table[170] = 16'h14A0; crc_table[171] = 16'h0481;
        crc_table[172] = 16'h7466; crc_table[173] = 16'h6447; crc_table[174] = 16'h5424; crc_table[175] = 16'h4405;
        crc_table[176] = 16'hA7DB; crc_table[177] = 16'hB7FA; crc_table[178] = 16'h8799; crc_table[179] = 16'h97B8;
        crc_table[180] = 16'hE75F; crc_table[181] = 16'hF77E; crc_table[182] = 16'hC71D; crc_table[183] = 16'hD73C;
        crc_table[184] = 16'h26D3; crc_table[185] = 16'h36F2; crc_table[186] = 16'h0691; crc_table[187] = 16'h16B0;
        crc_table[188] = 16'h6657; crc_table[189] = 16'h7676; crc_table[190] = 16'h4615; crc_table[191] = 16'h5634;
        crc_table[192] = 16'hD94C; crc_table[193] = 16'hC96D; crc_table[194] = 16'hF90E; crc_table[195] = 16'hE92F;
        crc_table[196] = 16'h99C8; crc_table[197] = 16'h89E9; crc_table[198] = 16'hB98A; crc_table[199] = 16'hA9AB;
        crc_table[200] = 16'h5844; crc_table[201] = 16'h4865; crc_table[202] = 16'h7806; crc_table[203] = 16'h6827;
        crc_table[204] = 16'h18C0; crc_table[205] = 16'h08E1; crc_table[206] = 16'h3882; crc_table[207] = 16'h28A3;
        crc_table[208] = 16'hCB7D; crc_table[209] = 16'hDB5C; crc_table[210] = 16'hEB3F; crc_table[211] = 16'hFB1E;
        crc_table[212] = 16'h8BF9; crc_table[213] = 16'h9BD8; crc_table[214] = 16'hABBB; crc_table[215] = 16'hBB9A;
        crc_table[216] = 16'h4A75; crc_table[217] = 16'h5A54; crc_table[218] = 16'h6A37; crc_table[219] = 16'h7A16;
        crc_table[220] = 16'h0AF1; crc_table[221] = 16'h1AD0; crc_table[222] = 16'h2AB3; crc_table[223] = 16'h3A92;
        crc_table[224] = 16'hFD2E; crc_table[225] = 16'hED0F; crc_table[226] = 16'hDD6C; crc_table[227] = 16'hCD4D;
        crc_table[228] = 16'hBDAA; crc_table[229] = 16'hAD8B; crc_table[230] = 16'h9DE8; crc_table[231] = 16'h8DC9;
        crc_table[232] = 16'h7C26; crc_table[233] = 16'h6C07; crc_table[234] = 16'h5C64; crc_table[235] = 16'h4C45;
        crc_table[236] = 16'h3CA2; crc_table[237] = 16'h2C83; crc_table[238] = 16'h1CE0; crc_table[239] = 16'h0CC1;
        crc_table[240] = 16'hEF1F; crc_table[241] = 16'hFF3E; crc_table[242] = 16'hCF5D; crc_table[243] = 16'hDF7C;
        crc_table[244] = 16'hAF9B; crc_table[245] = 16'hBFBA; crc_table[246] = 16'h8FD9; crc_table[247] = 16'h9FF8;
        crc_table[248] = 16'h6E17; crc_table[249] = 16'h7E36; crc_table[250] = 16'h4E55; crc_table[251] = 16'h5E74;
        crc_table[252] = 16'h2E93; crc_table[253] = 16'h3EB2; crc_table[254] = 16'h0ED1; crc_table[255] = 16'h1EF0;
    end

    // CRC 处理 (1 周期延迟)
    always @(posedge clk) begin
        if (rst) begin
            crc_out <= 16'hFFFF;
        end else if (crc_init) begin
            crc_out <= 16'hFFFF;
        end else if (crc_tick) begin
            crc_out <= {crc_out[7:0], 8'h00} ^ crc_table[((crc_out >> 8) ^ data_in) & 8'hFF];
        end
    end

endmodule
`default_nettype wire
