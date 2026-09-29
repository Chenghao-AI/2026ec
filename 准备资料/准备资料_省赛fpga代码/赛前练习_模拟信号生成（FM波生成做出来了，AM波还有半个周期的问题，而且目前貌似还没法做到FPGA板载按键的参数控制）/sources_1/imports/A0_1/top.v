`timescale 1ns / 1ps
//
// top.v - 顶层 wrapper：50 MHz → 125 MHz MMCM + 按键同步消抖 + ODDR 时钟转发
//
// 接口：
//   clk_50m : 50 MHz 板上时钟 (U18 / BANK34)
//   key1~3  : 按键 (按为 0；1.0 V Vpp / AM 调制度 / FM 频偏)
//   cha_data / chb_data : 14-bit DAC 数据
//   cha_clk  / chb_clk  : 125 MHz DAC 锁存时钟 (ODDR 转发)
//   status_led[3:0]     : 状态指示 (低有效)
//
// 仿真专用输出 sim_dsp_clk_unused：仅在 XSim 编译时 (define SIMULATION) 暴露。
//
// 仿真 vs 综合 DEBOUNCE_CYCLES：
//   - SIMULATION:  DEBOUNCE_CYCLES = 128 (~2.5 us @ 50 MHz)
//   - 综合:        DEBOUNCE_CYCLES = 1_000_000 (20 ms @ 50 MHz)
//
module top (
    input  wire        clk_50m,
    input  wire        key1,
    input  wire        key2,
    input  wire        key3,
    output wire [13:0] cha_data,
    output wire        cha_clk,
    output wire [13:0] chb_data,
    output wire        chb_clk,
    output wire [3:0]  status_led
`ifdef SIMULATION
    ,
    output wire        sim_dsp_clk_unused
`endif
);

    wire clk_dsp_125m;
    wire clk_buf_125m;
    wire mmcm_locked;

    reg [3:0] rst_cnt = 4'h0;
    reg       rst_reg = 1'b1;
    always @(posedge clk_50m) begin
        if (rst_cnt[3] == 1'b0) begin
            rst_cnt <= rst_cnt + 4'h1;
            rst_reg <= 1'b1;
        end else begin
            rst_reg <= 1'b0;
        end
    end

    wire sys_rst_50m = ~(mmcm_locked & ~rst_reg);

    // ---- 50MHz → 125MHz reset CDC ----
    // 同步 sys_rst 到 mmcm_clk0 域, 避免跨时钟域 timing 路径 (clk_50m → mmcm_clk0)
    reg sys_rst_sync0 = 1'b1;
    reg sys_rst_sync1 = 1'b1;
    reg sys_rst_sync2 = 1'b1;
    reg sys_rst_sync3 = 1'b1;
    always @(posedge clk_dsp_125m) begin
        sys_rst_sync0 <= sys_rst_50m;
        sys_rst_sync1 <= sys_rst_sync0;
        sys_rst_sync2 <= sys_rst_sync1;
        sys_rst_sync3 <= sys_rst_sync2;
    end
    wire sys_rst = sys_rst_sync3;

    MMCM_Wrapper u_mmcm (
        .CLKIN1     (clk_50m),
        .RESETN     (1'b1),
        .CLKOUT_DSP (clk_dsp_125m),
        .CLKOUT_BUF (clk_buf_125m),
        .LOCKED     (mmcm_locked)
    );

`ifdef SIMULATION
    localparam [7:0]  DEBOUNCE_CYCLES = 8'd128;
    reg [7:0]  key1_cnt = 8'h0;
    reg [7:0]  key2_cnt = 8'h0;
    reg [7:0]  key3_cnt = 8'h0;
    wire [7:0] debounce_minus_one = DEBOUNCE_CYCLES - 8'd1;
    wire [7:0] debounce_inc       = 8'd1;
`else
    localparam [19:0] DEBOUNCE_CYCLES = 20'd1_000_000;
    reg [19:0] key1_cnt = 20'h0;
    reg [19:0] key2_cnt = 20'h0;
    reg [19:0] key3_cnt = 20'h0;
    wire [19:0] debounce_minus_one = DEBOUNCE_CYCLES - 20'd1;
    wire [19:0] debounce_inc       = 20'd1;
`endif

    reg key1_sync0, key1_sync1;
    reg key2_sync0, key2_sync1;
    reg key3_sync0, key3_sync1;
    reg        key1_stable = 1'b1;
    reg        key2_stable = 1'b1;
    reg        key3_stable = 1'b1;
    reg        key1_stable_d = 1'b1;
    reg        key2_stable_d = 1'b1;
    reg        key3_stable_d = 1'b1;

    always @(posedge clk_50m) begin
        if (!mmcm_locked || ~rst_reg) begin
            key1_sync0 <= 1'b1;  key1_sync1 <= 1'b1;
            key2_sync0 <= 1'b1;  key2_sync1 <= 1'b1;
            key3_sync0 <= 1'b1;  key3_sync1 <= 1'b1;
            key1_cnt   <= debounce_minus_one + debounce_inc; // = 0
            key1_stable <= 1'b1; key1_stable_d <= 1'b1;
            key2_cnt   <= debounce_minus_one + debounce_inc;
            key2_stable <= 1'b1; key2_stable_d <= 1'b1;
            key3_cnt   <= debounce_minus_one + debounce_inc;
            key3_stable <= 1'b1; key3_stable_d <= 1'b1;
        end else begin
            key1_sync0 <= key1;  key1_sync1 <= key1_sync0;
            key2_sync0 <= key2;  key2_sync1 <= key2_sync0;
            key3_sync0 <= key3;  key3_sync1 <= key3_sync0;

            // KEY1 debounce
            if (key1_stable == key1_sync1) begin
                key1_cnt <= debounce_minus_one + debounce_inc;
            end else if (key1_cnt == debounce_minus_one) begin
                key1_stable <= key1_sync1;
                key1_cnt    <= debounce_minus_one + debounce_inc;
            end else begin
                key1_cnt <= key1_cnt + debounce_inc;
            end
            key1_stable_d <= key1_stable;

            // KEY2 debounce
            if (key2_stable == key2_sync1) begin
                key2_cnt <= debounce_minus_one + debounce_inc;
            end else if (key2_cnt == debounce_minus_one) begin
                key2_stable <= key2_sync1;
                key2_cnt    <= debounce_minus_one + debounce_inc;
            end else begin
                key2_cnt <= key2_cnt + debounce_inc;
            end
            key2_stable_d <= key2_stable;

            // KEY3 debounce
            if (key3_stable == key3_sync1) begin
                key3_cnt <= debounce_minus_one + debounce_inc;
            end else if (key3_cnt == debounce_minus_one) begin
                key3_stable <= key3_sync1;
                key3_cnt    <= debounce_minus_one + debounce_inc;
            end else begin
                key3_cnt <= key3_cnt + debounce_inc;
            end
            key3_stable_d <= key3_stable;
        end
    end

    // 跨时钟域：clk_50m → clk_dsp_125m 双寄存器同步 + 反相
    reg key1_d0, key1_d1;
    reg key2_d0, key2_d1;
    reg key3_d0, key3_d1;

    wire key1_raw = key1_stable_d;
    wire key2_raw = key2_stable_d;
    wire key3_raw = key3_stable_d;

    always @(posedge clk_dsp_125m) begin
        key1_d0 <= ~key1_raw;  key1_d1 <= key1_d0;
        key2_d0 <= ~key2_raw;  key2_d1 <= key2_d0;
        key3_d0 <= ~key3_raw;  key3_d1 <= key3_d0;
    end

    wire [13:0] dsp_cha_data;
    wire [13:0] dsp_chb_data;
    wire [3:0]  dsp_status_led;

    AD9764Top u_ad9764 (
        .clock          (clk_dsp_125m),
        .reset          (sys_rst),
        .io_key1        (key1_d1),
        .io_key2        (key2_d1),
        .io_key3        (key3_d1),
        .io_cha_data    (dsp_cha_data),
        .io_chb_data    (dsp_chb_data),
        .io_status_led  (dsp_status_led)
    );

    FDRE #(.INIT(1'b0)) cha_data_reg [13:0] (.C(clk_dsp_125m), .CE(1'b1), .D({dsp_cha_data}), .Q(cha_data));
    FDRE #(.INIT(1'b0)) chb_data_reg [13:0] (.C(clk_dsp_125m), .CE(1'b1), .D({dsp_chb_data}), .Q(chb_data));
    FDRE #(.INIT(1'b1)) led_reg      [3:0]  (.C(clk_dsp_125m), .CE(1'b1), .D(dsp_status_led), .Q(status_led));

    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) oddr_cha (
        .Q  (cha_clk),
        .C  (clk_buf_125m),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) oddr_chb (
        .Q  (chb_clk),
        .C  (clk_buf_125m),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );

`ifdef SIMULATION
    assign sim_dsp_clk_unused = clk_dsp_125m;
`endif

endmodule
