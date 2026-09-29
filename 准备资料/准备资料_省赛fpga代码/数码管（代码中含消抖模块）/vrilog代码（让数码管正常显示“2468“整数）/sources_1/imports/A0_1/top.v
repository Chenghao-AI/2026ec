`timescale 1ns / 1ps

module top (
    input  wire clk_50m,    // 50MHz PL clock (U18)
    output wire [7:0] seg,   // 7-segment display segments (LOW = ON)
    output wire [3:0] dig_sel  // Digit select (HIGH = ON)
);

    // Reset signal (active high)
    wire reset;
    assign reset = 1'b0;  // No external reset

    // Instantiate the SevenSegmentDriver
    SevenSegmentDriver #(
        .displayValue(16'h2468)  // Display 
    ) u_display (
        .clock     (clk_50m),
        .reset     (reset),
        .io_seg    (seg),
        .io_dig_sel(dig_sel)
    );

endmodule
