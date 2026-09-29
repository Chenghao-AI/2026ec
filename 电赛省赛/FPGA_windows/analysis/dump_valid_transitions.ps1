$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
# At valid=1 transition, look at mag and bin
Write-Host "Valid=1 starting at line 4098:"
Write-Host "idx, mag, bin"
for ($i = 4098; $i -lt 4128; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try {
        $mag = [int]$parts[3]
        $bin = [int]$parts[4]
        $valid = [int]$parts[5]
        $adc = $parts[6]
    } catch { continue }
    Write-Host ("{0}: mag={1,6}, bin={2,5}, valid={3}, adc={4}" -f $i, $mag, $bin, $valid, $adc)
}

Write-Host "`nValid=1 ending at line 8193:"
for ($i = 8163; $i -lt 8193; $i++) {
    $parts = $lines[$i].Split(',')
    if ($parts.Length -lt 7) { continue }
    try {
        $mag = [int]$parts[3]
        $bin = [int]$parts[4]
        $valid = [int]$parts[5]
        $adc = $parts[6]
    } catch { continue }
    Write-Host ("{0}: mag={1,6}, bin={2,5}, valid={3}, adc={4}" -f $i, $mag, $bin, $valid, $adc)
}
