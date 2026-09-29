# 用 Python 做 FFT 验证 (in MATLAB 路径下生成 CSV)
Add-Type -AssemblyName System.Numerics
$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$adc = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $adc_v = 0
    try { $adc_v = [Convert]::ToInt32($parts[6], 16) } catch {}
    $signed = $adc_v - 2048
    $adc += [double]$signed
}

Write-Host "Total ADC samples: $($adc.Count)"
Write-Host "Min: $(($adc | Measure-Object -Minimum).Minimum), Max: $(($adc | Measure-Object -Maximum).Maximum)"

# 输出 CSV 供 MATLAB/Python 调用
$outPath = "C:\Users\24307\Desktop\FPGA_windows\adc_timeseries.csv"
"sample,adc" | Out-File $outPath -Encoding ASCII
for ($i = 0; $i -lt $adc.Count; $i++) {
    "$i,$($adc[$i])" | Out-File $outPath -Append -Encoding ASCII
}
Write-Host "ADC data written to: $outPath"
