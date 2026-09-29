`timescale 1ps / 1ps

module MMCM_Wrapper (
    input  wire CLKIN1,
    input  wire RESETN,
    output wire CLKOUT_DSP,
    output wire CLKOUT_BUF,
    output wire LOCKED
);

    MMCM_Behavioral u_behav (
        .CLKIN1     (CLKIN1),
        .RESETN     (RESETN),
        .CLKOUT_DSP (CLKOUT_DSP),
        .CLKOUT_BUF (CLKOUT_BUF),
        .LOCKED     (LOCKED)
    );

endmodule

module MMCM_Behavioral (
    input  wire CLKIN1,
    input  wire RESETN,
    output reg  CLKOUT_DSP,
    output reg  CLKOUT_BUF,
    output reg  LOCKED
);

    reg [2:0] div = 3'b0;
    reg [3:0] lock_cnt = 4'b0;
    reg        locked_r = 1'b0;

    initial begin
        CLKOUT_DSP = 1'b0;
        CLKOUT_BUF = 1'b0;
        LOCKED     = 1'b0;
    end

    always @(posedge CLKIN1) begin
        if (div == 3'b111) begin
            CLKOUT_DSP <= ~CLKOUT_DSP;
            CLKOUT_BUF <= ~CLKOUT_DSP;
            div        <= 3'b0;
        end else begin
            div <= div + 1'b1;
        end
        if (!RESETN) begin
            lock_cnt <= 4'b0;
            LOCKED   <= 1'b0;
        end else begin
            if (lock_cnt == 4'hF) begin
                LOCKED <= 1'b1;
            end else begin
                lock_cnt <= lock_cnt + 1'b1;
                LOCKED   <= 1'b0;
            end
        end
    end

endmodule