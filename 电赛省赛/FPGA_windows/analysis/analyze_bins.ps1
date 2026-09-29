$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$binMag = @{}
$binSampleCount = @{}
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

# 输出所有 bins (摘要：每32个一行)
for ($b = 0; $b -lt 2048; $b += 32) {
    $row = ""
    for ($i = 0; $i -lt 32; $i++) {
        $curr = $b + $i
        if ($binMag.ContainsKey($curr)) {
            $row += "{0,8} " -f $curr
        } else {
            $row += "    .    "
        }
    }
    Write-Host "Bins ${b}-$($b+31): $row"
}

# 列出 bin >= 410 的所有有 mag 的 bin
Write-Host "`n=== Bins >= 410 with mag data ==="
$bins410 = $binMag.Keys | Where-Object { $_ -ge 410 } | Sort-Object
foreach ($b in $bins410) {
    Write-Host "  bin $b : mag $($binMag[$b])"
}
