`timescale 1ns / 1ps
// =====================================================================
// B2.1 top_tb.v — Vivado XSim testbench (保留为可编译占位)
//
// 实际行为仿真我们用 Python sim_b2_1.py 实现 (因 XSim 在 WSL batch 模式
// 反复显示 0 CPU usage / $display 不输出). 本 testbench 仅用于保证
// sim_1 fileset 能成功编译, 不会实际 run.
//
// 使用方式 (Windows 原生命令行):
//   vivado -mode batch -source tcl/B2_1/b2_1_sim.tcl
// =====================================================================
module top_tb;
    initial begin
        $display("[B2.1 top_tb] Use Python sim_b2_1.py for behavioral simulation.");
        $display("[B2.1 top_tb] See /home/makashibata/Desktop/FPGA_Linux/other_tools/sim_b2_1.py");
        $finish;
    end
endmodule