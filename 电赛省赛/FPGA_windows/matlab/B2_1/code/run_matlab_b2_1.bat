@echo off
REM ============================================================================
REM run_matlab_b2_1.bat — 一键运行 B2.1 MATLAB 分析
REM 用法: 双击或 cmd 执行
REM ============================================================================

REM 切换到 MATLAB code 目录
cd /d "C:\Users\24307\Desktop\FPGA_windows\matlab\B2_1\code"

REM 调用 MATLAB 跑 read_dual_adc (默认读 source/ila_dump.csv,
REM 也可以 read_dual_adc('C:\...\sim_dump.csv') 用 Python 仿真数据)
"C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "read_dual_adc('C:\Users\24307\Desktop\FPGA_windows\Vivado\result\B2_1\sim\sim_dump.csv')" -logfile "C:\Users\24307\Desktop\FPGA_windows\Vivado\logs\matlab_b2_1.log"

echo Done.