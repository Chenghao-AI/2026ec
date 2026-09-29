$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
# Find rows where bin = 408 (decoded)
$rows = @()
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
    if ($bin -eq 408) {
        $rows += $line
    }
}

Write-Host "Rows with bin = 408:"
$rows | ForEach-Object { Write-Host $_ }
