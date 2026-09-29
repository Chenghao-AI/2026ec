$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$results = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts[5] -ne '0') {
        $mag = [int]$parts[3]
        $bin = [int]$parts[4]
        $sample = [int]$parts[0]
        $results += New-Object PSObject -Property @{
            sample = $sample
            bin = $bin
            mag = $mag
        }
    }
}

Write-Host "--- All bin entries with mag > 5000 ---"
$results | Where-Object { $_.mag -ge 5000 } | Sort-Object bin | Format-Table -AutoSize

Write-Host "--- Top peaks around bin 351 ---"
$results | Where-Object { ($_.bin -ge 345) -and ($_.bin -le 360) } | Sort-Object bin | Format-Table -AutoSize

Write-Host "--- Find sample numbers for each peak bin ---"
$results | Where-Object { $_.mag -ge 5000 } | Sort-Object sample | Format-Table -AutoSize
