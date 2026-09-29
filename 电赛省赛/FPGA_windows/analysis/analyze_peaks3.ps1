$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$results = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts[5] -ne '0') {
        $mag = [int]$parts[3]
        $bin = [int]$parts[4]
        $freq_khz = $bin * 4e6 / 8192 / 1000
        $results += New-Object PSObject -Property @{
            bin = $bin
            mag = $mag
            freq_khz = [math]::Round($freq_khz, 2)
        }
    }
}

Write-Host "--- All bins sorted by frequency ---"
$results | Sort-Object bin | Format-Table -AutoSize

Write-Host "--- Find bins where mag is very large (top 5%) ---"
$maxMag = ($results | Measure-Object mag -Maximum).Maximum
$threshold = $maxMag * 0.001
Write-Host "Max mag: $maxMag, Threshold (0.1%): $threshold"
$results | Where-Object { $_.mag -ge $threshold } | Sort-Object bin | Format-Table -AutoSize
