$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$valid0Count = 0
$valid1Count = 0

for ($i = 2; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try {
        $valid = [int]$parts[5]
    } catch { continue }
    if ($valid -eq 1) {
        $valid1Count++
    } else {
        $valid0Count++
    }
}

Write-Host "valid=0 count: $valid0Count"
Write-Host "valid=1 count: $valid1Count"

# Find first valid=1
$firstValidIdx = -1
for ($i = 2; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try { $valid = [int]$parts[5] } catch { continue }
    if ($valid -eq 1) {
        $firstValidIdx = $i
        break
    }
}
Write-Host "First valid=1 at line $firstValidIdx"
for ($j = [Math]::Max(0, $firstValidIdx-3); $j -lt [Math]::Min($lines.Count, $firstValidIdx+5); $j++) {
    $line = $lines[$j]
    Write-Host ("  line {0}: {1}" -f $j, $line)
}

# Find last valid=1
$lastValidIdx = -1
for ($i = 2; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try { $valid = [int]$parts[5] } catch { continue }
    if ($valid -eq 1) {
        $lastValidIdx = $i
    }
}
Write-Host "`nLast valid=1 at line $lastValidIdx"
for ($j = [Math]::Max(0, $lastValidIdx-3); $j -lt [Math]::Min($lines.Count, $lastValidIdx+5); $j++) {
    $line = $lines[$j]
    Write-Host ("  line {0}: {1}" -f $j, $line)
}
