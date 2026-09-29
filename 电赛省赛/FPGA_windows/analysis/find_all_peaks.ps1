$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'

# 收集 bin -> max mag（hex 解码）
$binMag = @{}
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [Convert]::ToInt32($parts[5], 16) } catch { continue }
    if ($valid -eq 0) { continue }
    $mag = 0
    try { $mag = [Convert]::ToInt32($parts[3], 16) } catch { continue }
    if ($mag -eq 0) { continue }
    $bin = 0
    try { $bin = [Convert]::ToInt32($parts[4], 16) } catch { continue }
    if (-not $binMag.ContainsKey($bin)) { $binMag[$bin] = 0 }
    if ($mag -gt $binMag[$bin]) { $binMag[$bin] = $mag }
}

Write-Host "Total unique bins: $($binMag.Count)"

# Find local peaks (mag > 1000)
$sortedBins = $binMag.Keys | Sort-Object
$peaks = @()
for ($i = 1; $i -lt $sortedBins.Count - 1; $i++) {
    $prev = $sortedBins[$i-1]
    $curr = $sortedBins[$i]
    $next = $sortedBins[$i+1]
    if ($binMag[$curr] -gt $binMag[$prev] -and $binMag[$curr] -gt $binMag[$next] -and $binMag[$curr] -gt 1000) {
        $freq_khz = [math]::Round($curr * 4e6 / 8192 / 1000, 3)
        $peaks += [PSCustomObject]@{
            bin = $curr
            mag = $binMag[$curr]
            freq_khz = $freq_khz
        }
    }
}

Write-Host "`n--- All local peaks (mag > 1000) ---"
$peaks | Sort-Object mag -Descending | Format-Table -AutoSize

Write-Host "`n--- Sorted by bin ---"
$peaks | Sort-Object bin | Format-Table -AutoSize
