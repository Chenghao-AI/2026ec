module SevenSegmentDriver #(
    parameter [15:0] displayValue = 16'h1234
)(
    input        clock,
                 reset,
    output [7:0] io_seg,
    output [3:0] io_dig_sel
);

  wire [7:0] seg_0 = 8'b11000000;  // 0: A,B,C,D,E,F
  wire [7:0] seg_1 = 8'b11111001;  // 1: B,C
  wire [7:0] seg_2 = 8'b10100100;  // 2: A,B,D,E,G
  wire [7:0] seg_3 = 8'b10110000;  // 3: A,B,C,D,G
  wire [7:0] seg_4 = 8'b10011001;  // 4: B,C,F,G
  wire [7:0] seg_5 = 8'b10010010;  // 5: A,C,D,F,G
  wire [7:0] seg_6 = 8'b10000010;  // 6: A,C,D,E,F,G
  wire [7:0] seg_7 = 8'b11111000;  // 7: A,B,C
  wire [7:0] seg_8 = 8'b10000000;  // 8: ALL
  wire [7:0] seg_9 = 8'b10010000;  // 9: A,B,C,D,F,G

  reg [1:0] digit_idx;
  reg [15:0] scan_cnt;
  
  always @(posedge clock) begin
    if (reset) begin
      scan_cnt <= 16'd0;
      digit_idx <= 2'd0;
    end else if (scan_cnt >= 16'd9999) begin
      scan_cnt <= 16'd0;
      digit_idx <= digit_idx + 2'd1;  
    end else begin
      scan_cnt <= scan_cnt + 16'd1;
    end
  end

  wire [3:0] dig_sel = 4'b1000 >> digit_idx;

  wire [3:0] digit_val;
  assign digit_val = (digit_idx == 2'd0) ? displayValue[3:0] :  
                     (digit_idx == 2'd1) ? displayValue[7:4]  :  
                     (digit_idx == 2'd2) ? displayValue[11:8]   :  
                                          displayValue[15:12];     

  reg [7:0] seg_out;
  always @(*) begin
    case (digit_val)
      4'd0:  seg_out = seg_0;
      4'd1:  seg_out = seg_1;
      4'd2:  seg_out = seg_2;
      4'd3:  seg_out = seg_3;
      4'd4:  seg_out = seg_4;
      4'd5:  seg_out = seg_5;
      4'd6:  seg_out = seg_6;
      4'd7:  seg_out = seg_7;
      4'd8:  seg_out = seg_8;
      4'd9:  seg_out = seg_9;
      default: seg_out = seg_0;  
    endcase
  end

  assign io_seg = seg_out;
  assign io_dig_sel = dig_sel;

endmodule
