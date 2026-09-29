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

Write-Host "=== Bins 1-15 (DC/+DC) ==="
for ($b = 1; $b -le 15; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`n=== Bins 408-409 (200 kHz signal) ==="
for ($b = 405; $b -le 412; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`n=== Bins 845-855 (414.55 kHz peak) ==="
for ($b = 845; $b -le 855; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`n=== Average power in 200 kHz area (bins 400-420) ==="
$sum = 0; $count = 0
for ($b = 400; $b -le 420; $b++) {
    if ($binMag.ContainsKey($b)) {
        $sum += $binMag[$b]
        $count++
    }
}
if ($count -gt 0) { Write-Host "Avg: $($sum / $count)" }

Write-Host "`n=== Average power in 410 kHz area (bins 820-880) ==="
$sum = 0; $count = 0
for ($b = 820; $b -le 880; $b++) {
    if ($binMag.ContainsKey($b)) {
        $sum += $binMag[$b]
        $count++
    }
}
if ($count -gt 0) { Write-Host "Avg: $($sum / $count), count = $count" }

Write-Host "`n=== Average power in 414.55 kHz region (bins 840-855) ==="
$sum = 0; $count = 0
for ($b = 840; $b -le 855; $b++) {
    if ($binMag.ContainsKey($b)) {
        $sum += $binMag[$b]
        $count++
    }
}
if ($count -gt 0) { Write-Host "Avg: $($sum / $count), count = $count, sum = $sum" }
