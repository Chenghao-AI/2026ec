$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$allData = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    $sample = [int]$parts[0]
    $mag = 0
    if ($parts[3].StartsWith('0x') -or $parts[3].StartsWith('0X')) {
        $mag = [Convert]::ToInt32($parts[3].Substring(2), 16)
    } else {
        $mag = [int]$parts[3]
    }
    $bin = 0
    if ($parts[4].StartsWith('0x') -or $parts[4].StartsWith('0X')) {
        $bin = [Convert]::ToInt32($parts[4].Substring(2), 16)
    } else {
        $bin = [int]$parts[4]
    }
    $valid = 0
    if ($parts[5].StartsWith('0x') -or $parts[5].StartsWith('0X')) {
        $valid = [Convert]::ToInt32($parts[5].Substring(2), 16)
    } else {
        $valid = [int]$parts[5]
    }
    $allData += New-Object PSObject -Property @{
        sample = $sample
        mag = $mag
        bin = $bin
        valid = $valid
    }
}

Write-Host "--- DECODED CSV (showing full data) ---"
Write-Host "Total entries: $($allData.Count)"

# Separate valid/invalid
$valid = $allData | Where-Object { $_.valid -ne 0 -and $_.mag -ne 0 }
$invalid = $allData | Where-Object { $_.valid -eq 0 -or $_.mag -eq 0 }

Write-Host "Valid (mag>0 and valid>0): $($valid.Count)"
Write-Host "Invalid: $($invalid.Count)"

Write-Host "`nFirst 10 valid entries (sample, mag_decimal, bin_decimal, valid):"
$valid | Select-Object -First 10 | Format-Table -AutoSize

Write-Host "`nValid data around bin 351 (target=200kHz sample 0 region):"
$valid | Where-Object { $_.bin -ge 345 -and $_.bin -le 360 } | Format-Table -AutoSize

Write-Host "`nAll unique bins (decoded) sorted:"
$valid | Group-Object bin | ForEach-Object {
    New-Object PSObject -Property @{
        bin = [int]$_.Name
        maxMag = ($_.Group | Measure-Object mag -Maximum).Maximum
        count = $_.Count
    }
} | Sort-Object bin | Format-Table -AutoSize
