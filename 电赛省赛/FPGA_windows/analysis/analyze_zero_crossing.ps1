$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$adc = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $adc_v = 0
    try { $adc_v = [Convert]::ToInt32($parts[6], 16) } catch {}
    # Convert 12-bit offset binary to 2's complement (signed)
    if ($adc_v -ge 2048) {
        $signed = $adc_v - 4096
    } else {
        $signed = $adc_v
    }
    $adc += [int]$signed
}

Write-Host "Total ADC samples: $($adc.Count)"

# 找过零点（用 2048 中点），然后测过零间距
$crossings = @()
for ($i = 1; $i -lt $adc.Count; $i++) {
    if ($adc[$i-1] -ge 0 -and $adc[$i] -lt 0) {
        $crossings += $i
    }
}
Write-Host "Zero crossings (positive to negative): $($crossings.Count)"

# 计算相邻过零间距（半个周期）
if ($crossings.Count -gt 1) {
    $halfPeriods = @()
    for ($i = 1; $i -lt $crossings.Count; $i++) {
        $d = $crossings[$i] - $crossings[$i-1]
        $halfPeriods += $d
    }
    $avg = ($halfPeriods | Measure-Object -Average).Average
    $sum = 0
    foreach ($d in $halfPeriods) { $sum += $d }
    $avg = $sum / $halfPeriods.Count
    $variance = 0
    foreach ($d in $halfPeriods) { $variance += ($d - $avg) * ($d - $avg) }
    $variance = $variance / $halfPeriods.Count
    $std = [math]::Sqrt($variance)
    
    Write-Host "Average half period: $avg samples"
    Write-Host "Std: $std samples"
    Write-Host "Estimated full period: $($avg * 2) samples"
    
    # fs = 4 MHz, period samples -> freq
    $periodSamples = $avg * 2
    $f_estimated = 4e6 / $periodSamples
    Write-Host "Estimated frequency: $([math]::Round($f_estimated, 2)) Hz"
    
    Write-Host "`nHalf periods:"
    foreach ($d in $halfPeriods) {
        Write-Host "  $d samples ($([math]::Round(4e6/($d*2))) Hz)"
    }
}
