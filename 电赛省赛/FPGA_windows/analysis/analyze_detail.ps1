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

Write-Host "=== Bins 400-420 (200 kHz signal area) ==="
for ($b = 400; $b -le 420; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`n=== Bins 340-360 (apparent peak at 171 kHz) ==="
for ($b = 340; $b -le 360; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`n=== Bins 415-435 (200 kHz*2.07-2.13, possible harmonic) ==="
for ($b = 415; $b -le 435; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}
