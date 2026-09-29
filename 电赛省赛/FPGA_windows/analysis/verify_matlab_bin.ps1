$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
# Find rows where (hex decoded bin) = 408
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
    $binHex = 0
    try { $binHex = [Convert]::ToInt32($parts[4], 16) } catch {}
    if ($binHex -eq 408) {
        $rows += "$($parts[0]) : bin=$($parts[4]) (dec=$bin, hex=$binHex), mag=$($parts[3]) (dec=$mag, hex=$([Convert]::ToInt32($parts[3], 16)))"
    }
}

Write-Host "Rows where bin (hex decoded) = 408:"
$rows | ForEach-Object { Write-Host $_ }
