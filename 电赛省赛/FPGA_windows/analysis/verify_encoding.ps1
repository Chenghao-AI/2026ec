$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$maxBinStr = ""
$maxBinDec = 0
$maxBinHex = 0
$maxMagStr = ""
$maxMagDec = 0
$maxMagHex = 0
$bins = @()
$mags = @()
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
    $bins += $bin
    $mags += $mag
    if ($bin -gt $maxBinDec) { $maxBinDec = $bin; $maxBinStr = $parts[4] }
    if ($mag -gt $maxMagDec) { $maxMagDec = $mag; $maxMagStr = $parts[3] }
}

$maxBinHexVal = [Convert]::ToInt32($maxBinStr, 16)
$maxMagHexVal = [Convert]::ToInt32($maxMagStr, 16)

Write-Host "Max bin CSV value: '$maxBinStr'"
Write-Host "  If decimal: $maxBinDec (11-bit max: 2047)"
Write-Host "  If hex    : $maxBinHexVal"
Write-Host ""
Write-Host "Max mag CSV value: '$maxMagStr'"
Write-Host "  If decimal: $maxMagDec (16-bit max: 65535)"
Write-Host "  If hex    : $maxMagHexVal"
