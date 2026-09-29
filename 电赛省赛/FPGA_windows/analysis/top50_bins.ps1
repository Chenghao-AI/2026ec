$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$binMag = @{}
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [int]$parts[5] } catch { continue }
    if ($valid -eq 0) { continue }
    $mag = 0
    try { $mag = [int]$parts[3] } catch { continue }
    if ($mag -eq 0) { continue }
    $bin = 0
    try { $bin = [int]$parts[4] } catch { continue }
    if (-not $binMag.ContainsKey($bin)) { $binMag[$bin] = 0 }
    if ($mag -gt $binMag[$bin]) { $binMag[$bin] = $mag }
}

# Print top 50 bins (DEC)
Write-Host "Top 50 bins (DEC encoding) by mag:"
$binMag.Keys | ForEach-Object { 
    New-Object PSObject -Property @{ bin = [int]$_; mag = $binMag[$_] }
} | Sort-Object mag -Descending | Select-Object -First 50 | Format-Table -AutoSize

Write-Host "`nAll bins >= 200:"
$binMag.Keys | ForEach-Object { 
    if ($binMag[$_] -ge 200) {
        New-Object PSObject -Property @{ bin = [int]$_; mag = $binMag[$_] }
    }
} | Sort-Object bin | Format-Table -AutoSize
