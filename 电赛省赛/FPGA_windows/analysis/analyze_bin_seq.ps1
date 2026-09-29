$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$valid_count = 0
$bin_count = @{}
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    try {
        $valid = [int]$parts[5]
        $bin = [int]$parts[4]
        $mag = [int]$parts[3]
    } catch { continue }
    if ($valid -eq 1) {
        $valid_count++
        if (-not $bin_count.ContainsKey($bin)) { $bin_count[$bin] = 0 }
        $bin_count[$bin]++
    }
}

Write-Host "Total valid=1 samples: $valid_count"
Write-Host "Total unique bins: $($bin_count.Count)"

# Check if bins are contiguous
$bins = $bin_count.Keys | Sort-Object
Write-Host "`nFirst 20 bins: $($bins[0..19] -join ', ')"
Write-Host "Last 20 bins: $($bins[-20..-1] -join ', ')"

# Find any gaps
$gaps = @()
for ($i = 0; $i -lt $bins.Count - 1; $i++) {
    if ($bins[$i+1] - $bins[$i] -ne 1) {
        $gaps += "gap $($bins[$i]) -> $($bins[$i+1])"
    }
}
Write-Host "`nGaps found: $($gaps -join '; ')"
