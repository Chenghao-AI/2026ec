`timescale 1ns / 1ps
`default_nettype none

// ============================================================================
// DivideBy2_BUFG — 8 MHz -> 4 MHz (1 级 2 分频 + BUFG 全局时钟网络)
// ----------------------------------------------------------------------------
//   在 clk_8m 上升沿翻转 clk_div_r, 然后经 BUFG 扇出, 避免大扇出引入 skew.
//   输出 clk_4m 是全局时钟, 可作为 FFT IP / CORDIC IP / 数据通路采样时钟.
// ============================================================================
module DivideBy2_BUFG (
    input  wire clk_8m,
    output wire clk_4m
);

    reg clk_div_r = 1'b0;
    always @(posedge clk_8m) begin
        clk_div_r <= ~clk_div_r;
    end

    BUFG u_bufg_4m (
        .I (clk_div_r),
        .O (clk_4m)
    );

endmodule
`default_nettype wire