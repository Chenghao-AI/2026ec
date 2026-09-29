$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
# Look at data around sample 4447 (where bin 351 is)
for ($i = 4440; $i -lt 4465; $i++) {
    $line = $lines[$i]
    Write-Host $line
}
