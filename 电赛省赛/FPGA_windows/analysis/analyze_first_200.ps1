$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$adc = @()
$idx = 0
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $adc_v = 0
    try { $adc_v = [Convert]::ToInt32($parts[6], 16) } catch {}
    if ($adc_v -ge 2048) {
        $signed = $adc_v - 4096
    } else {
        $signed = $adc_v
    }
    $adc += [int]$signed
    $idx++
    if ($idx -ge 200) { break }
}

Write-Host "First 200 ADC samples (signed):"
for ($i = 0; $i -lt $adc.Count; $i++) {
    "{0,4}: {1,5}" -f $i, $adc[$i]
    if (($i + 1) % 5 -eq 0) { Write-Host "" }
}

# 显示完整时域细节
$minVal = ($adc | Measure-Object -Minimum).Minimum
$maxVal = ($adc | Measure-Object -Maximum).Maximum
$minIdx = 0; $maxIdx = 0
for ($i = 0; $i -lt $adc.Count; $i++) {
    if ($adc[$i] -eq $minVal -and $minIdx -eq 0) { $minIdx = $i }
    if ($adc[$i] -eq $maxVal -and $maxIdx -eq 0) { $maxIdx = $i }
}
Write-Host "`nMin: $minVal at sample $minIdx"
Write-Host "Max: $maxVal at sample $maxIdx"

# 寻找所有正过零（升沿）和负过零（降沿）
$posCross = @()
$negCross = @()
for ($i = 1; $i -lt $adc.Count; $i++) {
    if ($adc[$i-1] -le 0 -and $adc[$i] -gt 0) { $posCross += $i }
    if ($adc[$i-1] -ge 0 -and $adc[$i] -lt 0) { $negCross += $i }
}
Write-Host "`nPositive crossings (samples): $($posCross -join ', ')"
Write-Host "Negative crossings (samples): $($negCross -join ', ')"

# 计算周期
if ($posCross.Count -gt 1) {
    $periods = @()
    for ($i = 1; $i -lt $posCross.Count; $i++) {
        $periods += ($posCross[$i] - $posCross[$i-1])
    }
    Write-Host "`nPeriods (samples between positive crossings): $($periods -join ', ')"
    $avgPeriod = ($periods | Measure-Object -Average).Average
    Write-Host "Avg period: $avgPeriod samples"
    if ($avgPeriod -gt 0) {
        $f = 4e6 / $avgPeriod
        Write-Host "Frequency: $([math]::Round($f, 2)) Hz"
    }
}
