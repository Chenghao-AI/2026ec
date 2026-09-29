$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$validRows = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [Convert]::ToInt32($parts[5], 16) } catch {}
    $mag = 0
    try { $mag = [Convert]::ToInt32($parts[3], 16) } catch {}
    $bin = 0
    try { $bin = [Convert]::ToInt32($parts[4], 16) } catch {}
    if ($valid -ne 0 -and $mag -ne 0) {
        $validRows += New-Object PSObject -Property @{
            mag = $mag
            bin = $bin
        }
    }
}

# Find all peaks (mag > 200)
$allBins = $validRows | Group-Object bin | ForEach-Object {
    [int]$_.Name
}
$allBins = $allBins | Sort-Object
$peaks = @()
for ($i = 1; $i -lt $allBins.Count - 1; $i++) {
    $prev = $allBins[$i-1]
    $curr = $allBins[$i]
    $next = $allBins[$i+1]
    $mag_curr = ($validRows | Where-Object { $_.bin -eq $curr } | Measure-Object mag -Maximum).Maximum
    $mag_prev = ($validRows | Where-Object { $_.bin -eq $prev } | Measure-Object mag -Maximum).Maximum
    $mag_next = ($validRows | Where-Object { $_.bin -eq $next } | Measure-Object mag -Maximum).Maximum
    if ($mag_curr -gt $mag_prev -and $mag_curr -gt $mag_next -and $mag_curr -gt 1000) {
        $freq = $curr * 4e6 / 8192
        $peaks += New-Object PSObject -Property @{
            bin = $curr
            mag = $mag_curr
            freq_khz = [math]::Round($freq/1000, 2)
        }
    }
}

Write-Host "--- All local peaks (mag > 1000) ---"
$peaks | Sort-Object mag -Descending | Format-Table -AutoSize
Write-Host "--- Top 10 peaks by magnitude ---"
$peaks | Sort-Object mag -Descending | Select-Object -First 10 | Format-Table -AutoSize
Write-Host "--- Peaks in 160-240 kHz range ---"
$peaks | Where-Object { $_.freq_khz -ge 160 -and $_.freq_khz -le 240 } | Format-Table -AutoSize
