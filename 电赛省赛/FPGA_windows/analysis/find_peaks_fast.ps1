$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
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

$peaks = @()
$sortedBins = $binMag.Keys | Sort-Object
for ($i = 1; $i -lt $sortedBins.Count - 1; $i++) {
    $prev = $sortedBins[$i-1]
    $curr = $sortedBins[$i]
    $next = $sortedBins[$i+1]
    $mag_curr = $binMag[$curr]
    $mag_prev = $binMag[$prev]
    $mag_next = $binMag[$next]
    if ($mag_curr -gt $mag_prev -and $mag_curr -gt $mag_next -and $mag_curr -gt 1000) {
        $freq_khz = [math]::Round($curr * 4e6 / 8192 / 1000, 2)
        $peaks += "$curr | $mag_curr | $freq_khz"
    }
}
Write-Host "--- All local peaks (mag > 1000) ---"
$peaks | ForEach-Object { Write-Host $_ }
