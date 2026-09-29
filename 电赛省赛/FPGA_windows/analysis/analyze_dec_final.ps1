$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$binMag = @{}
$adcVals = @()
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
    
    $adc = 0
    try { $adc = [int]$parts[6] } catch {}
    $adcVals += $adc
}

Write-Host "Total unique bins (decoded): $($binMag.Count)"
Write-Host "Max bin: $(($binMag.Keys | Measure-Object -Maximum).Maximum)"
Write-Host "Min bin: $(($binMag.Keys | Measure-Object -Minimum).Minimum)"

# Find top peaks (mag > 5000)
$sortedBins = $binMag.Keys | Sort-Object
Write-Host "`nTop bins by mag:"
$binMag.Keys | ForEach-Object { 
    New-Object PSObject -Property @{ bin = [int]$_; mag = $binMag[$_] }
} | Sort-Object mag -Descending | Select-Object -First 30 | Format-Table -AutoSize

Write-Host "`nBins 405-415 (200 kHz area):"
for ($b = 405; $b -le 415; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

Write-Host "`nBins 345-365 (around user-mentioned 351):"
for ($b = 345; $b -le 365; $b++) {
    $m = if ($binMag.ContainsKey($b)) { $binMag[$b] } else { 0 }
    "{0} : {1}" -f $b, $m
}

# Find local peaks
$peaks = @()
for ($i = 1; $i -lt $sortedBins.Count - 1; $i++) {
    $prev = $sortedBins[$i-1]
    $curr = $sortedBins[$i]
    $next = $sortedBins[$i+1]
    if ($binMag[$curr] -gt $binMag[$prev] -and $binMag[$curr] -gt $binMag[$next] -and $binMag[$curr] -gt 1000) {
        $peaks += [PSCustomObject]@{
            bin = [int]$curr
            mag = [int]$binMag[$curr]
            freq_khz = [math]::Round($curr * 4e6 / 8192 / 1000, 3)
        }
    }
}
Write-Host "`nLocal peaks (mag > 1000):"
$peaks | Sort-Object mag -Descending | Format-Table -AutoSize
