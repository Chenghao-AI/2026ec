# STM32CubeIDE Debugger Console:
#   source D:/Users/Desktop/Electronic\ Competition/Tools/fpga_uart_capture.gdb
#   fpga-uart-capture

define fpga-uart-capture
  set $capture_begin = (char *)&g_fpga_debug_measurement
  set $capture_end = $capture_begin + sizeof(g_fpga_debug_measurement)
  dump binary memory D:/fpga_uart_snapshot.bin $capture_begin $capture_end
  printf "Saved %u bytes to D:/fpga_uart_snapshot.bin\n", sizeof(g_fpga_debug_measurement)
  printf "Debug state:\n"
  output g_fpga_debug_state
  printf "\nUART statistics:\n"
  output g_fpga_debug_stats
  printf "\n"
end

document fpga-uart-capture
Export the exact FPGA measurement accepted by STM32 to
D:/fpga_uart_snapshot.bin. Halt at FPGA_UART_DebugMeasurementReadyHook first;
that hook runs after STM32 has attempted to send ACK.
end
