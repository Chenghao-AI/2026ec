$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$results = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts[5] -ne '0') {
        $mag = [int]$parts[3]
        $bin = [int]$parts[4]
        $results += New-Object PSObject -Property @{
            bin = $bin
            mag = $mag
        }
    }
}

Write-Host "--- Bins around 351 (around actual peak) ---"
$results | Where-Object { ($_.bin -ge 340) -and ($_.bin -le 360) } | Sort-Object bin | Format-Table -AutoSize

Write-Host "--- Bins around 449 (around GUI reported peak) ---"
$results | Where-Object { ($_.bin -ge 440) -and ($_.bin -le 460) } | Sort-Object bin | Format-Table -AutoSize

Write-Host "--- Bins around 351 (high mag) compared to other bins ---"
$maxMag = 24146
Write-Host "Mag near peak 351:"
foreach ($bin in (340..360)) { 
    $m = $results | Where-Object { $_.bin -eq $bin } | Measure-Object mag -Maximum
    "{0}`t{1}" -f $bin, $m.Maximum
}
Write-Host "--- Mag near 449 ---"
foreach ($bin in (440..460)) {
    $m = $results | Where-Object { $_.bin -eq $bin } | Measure-Object mag -Maximum
    "{0}`t{1}" -f $bin, $m.Maximum
}
