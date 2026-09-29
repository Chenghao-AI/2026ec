$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'

# 收集 ADC signed (正确算法: adc - 2048)
$adc = @()
$magSeq = @()
$binSeq = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [Convert]::ToInt32($parts[5], 16) } catch { continue }
    $adc_v = 0
    try { $adc_v = [Convert]::ToInt32($parts[6], 16) } catch {}
    # 正确 signed 算法: offset_binary - 2048
    $signed = $adc_v - 2048
    $adc += $signed
    if ($valid -ne 0) {
        $mag = 0
        try { $mag = [Convert]::ToInt32($parts[3], 16) } catch {}
        $bin = 0
        try { $bin = [Convert]::ToInt32($parts[4], 16) } catch {}
        $magSeq += $mag
        $binSeq += $bin
    }
}

Write-Host "=== ADC 时域 (signed) 前 50 个 sample ==="
for ($i = 0; $i -lt [Math]::Min(50, $adc.Count); $i++) {
    "{0,4}: {1,5}" -f $i, $adc[$i]
    if (($i + 1) % 5 -eq 0) { Write-Host "" }
}

# 找过零点
$posCross = @()
$negCross = @()
for ($i = 1; $i -lt $adc.Count; $i++) {
    if ($adc[$i-1] -le 0 -and $adc[$i] -gt 0) { $posCross += $i }
    if ($adc[$i-1] -ge 0 -and $adc[$i] -lt 0) { $negCross += $i }
}
Write-Host "`nPositive crossings: $($posCross -join ', ')"
Write-Host "Negative crossings: $($negCross -join ', ')"

if ($posCross.Count -gt 1) {
    $periods = @()
    for ($i = 1; $i -lt $posCross.Count; $i++) {
        $periods += ($posCross[$i] - $posCross[$i-1])
    }
    Write-Host "`nPeriods: $($periods -join ', ')"
    $avg = ($periods | Measure-Object -Average).Average
    Write-Host "Avg period: $avg samples"
    Write-Host "Estimated freq: $([math]::Round(4e6/$avg, 2)) Hz"
}

# Min/Max
$max = ($adc | Measure-Object -Maximum).Maximum
$min = ($adc | Measure-Object -Minimum).Minimum
Write-Host "`nMax: $max, Min: $min, P2P: $($max - $min)"
