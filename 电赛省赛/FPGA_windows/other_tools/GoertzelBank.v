`timescale 1ns / 1ps
// =====================================================================
// GoertzelBank.v  (P1 / 2026_G 题频谱分析)
//
// 2560 个 Goertzel cell 并联, 每 cell 持有固定的 2*cos(2πk/N) 系数
// 系数在 elaboration 阶段从 "CoeffBank.mem" 通过 $readmemh 一次性加载,
// 此后每周期只更新 cell 状态.
//
// 输入 x (24-bit signed 已加窗) 广播到所有 cell.
//
// 扫描输出: 2560 cell 的 (Q1, Q2) 在 frame_end 之后串行读出.
// =====================================================================
module GoertzelBank #(
    parameter N_CELL = 2560,
    parameter ADDR_W = 12
) (
    input  wire                       clk,
    input  wire                       clear,     // 帧首清 0
    input  wire                       advance,   // sample 已就绪
    input  wire signed [23:0]         x,

    // 系数 load 一次 (elaboration): io_load_addr + io_load_data 在文件外面不接
    input  wire                       coeff_we,         // = 1'b1 during elaboration
    input  wire [ADDR_W-1:0]          coeff_waddr,
    input  wire signed [15:0]         coeff_wdata,

    // 扫描输出 (帧末)
    input  wire [ADDR_W-1:0]          scan_idx,
    output wire signed [27:0]         scan_Q1,
    output wire signed [27:0]         scan_Q2
);
    // 2560 cell 系数寄存器
    reg signed [15:0] coeff_table [0:N_CELL-1];
    initial begin
        // 仿真/综合时由 Vivado 的 $readmemh 加载
        $readmemh("CoeffBank.mem", coeff_table);
    end
    always @(posedge clk) begin
        if (coeff_we) coeff_table[coeff_waddr] <= coeff_wdata;
    end

    // 2560 个 cell
    wire signed [27:0] q1_w [0:N_CELL-1];
    wire signed [27:0] q2_w [0:N_CELL-1];
    genvar gi;
    generate
        for (gi = 0; gi < N_CELL; gi = gi + 1) begin: g_cell
            GoertzelCell u_cell (
                .clk     (clk),
                .clear   (clear),
                .advance (advance),
                .x       (x),
                .coeff   (coeff_table[gi]),
                .Q1      (q1_w[gi]),
                .Q2      (q2_w[gi])
            );
        end
    endgenerate

    // 扫描输出 — 2560 选 1 (综合成 mux, 但只在帧末使用一次, 占 ~ 几十 LUT)
    assign scan_Q1 = q1_w[scan_idx];
    assign scan_Q2 = q2_w[scan_idx];

endmodule
