$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$state = "init"  # init, found_valid
$validCount = 0
$runCount = 0
$runs = @()
$run = 0

for ($i = 2; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try {
        $valid = [int]$parts[5]
    } catch { continue }
    
    if ($valid -eq 1) {
        $run++
    } else {
        if ($run -gt 0) {
            $runs += $run
            $run = 0
        }
    }
}
if ($run -gt 0) { $runs += $run }

Write-Host "Total valid runs: $($runs.Count)"
Write-Host "Run lengths (first 30):"
for ($i = 0; $i -lt [Math]::Min(30, $runs.Count); $i++) {
    Write-Host "  run $($i+1): length=$($runs[$i])"
}
Write-Host "`nTotal sum of run lengths: $(($runs | Measure-Object -Sum).Sum)"
Write-Host "Run length stats: min=$((($runs | Measure-Object -Minimum).Minimum)), max=$((($runs | Measure-Object -Maximum).Maximum)), avg=$([math]::Round(($runs | Measure-Object -Average).Average, 2))"
