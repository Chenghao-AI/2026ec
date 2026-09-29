# Load this file from the STM32CubeIDE Debugger Console with:
#   source Tools/spectrum_dump.gdb
# Then halt the MCU after the sweep and run:
#   spectrum-dump

define spectrum-dump
  set $spectrum_begin = (char *)&g_spectrum_points[0]
  set $spectrum_end = (char *)&g_spectrum_points[1201]
  dump binary memory D:/spectrum_snapshot.bin $spectrum_begin $spectrum_end
  printf "Saved 1201 SpectrumPoint_t records to D:/spectrum_snapshot.bin\n"
end

document spectrum-dump
Dump the stable g_spectrum_points array to Tools/spectrum_snapshot.bin.
The target must be halted after Spectrum_RunSynchronousSweep has completed.
end
