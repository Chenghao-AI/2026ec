$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$results = @()
$cnt = 0
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $cnt++
    if ($cnt -lt 4096) { continue }
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [Convert]::ToInt32($parts[5], 16) } catch {}
    if ($valid -eq 0) { continue }
    $magStr = $parts[3]
    $binStr = $parts[4]
    $adcStr = $parts[6]
    $mag_dec = 0
    $mag_hex = 0
    try { $mag_dec = [int]$parts[3] } catch {}
    try { $mag_hex = [Convert]::ToInt32($parts[3], 16) } catch {}
    $bin_dec = 0
    $bin_hex = 0
    try { $bin_dec = [int]$parts[4] } catch {}
    try { $bin_hex = [Convert]::ToInt32($parts[4], 16) } catch {}
    "{0,-8} | mag(str={1,5} dec={2,5} hex={3,5}) | bin(str={4,5} dec={5,5} hex={6,5}) | adc(str={7})" -f $parts[0], $parts[3], $mag_dec, $mag_hex, $parts[4], $bin_dec, $bin_hex, $parts[6]
    if ($cnt -gt 4455) { break }
}
