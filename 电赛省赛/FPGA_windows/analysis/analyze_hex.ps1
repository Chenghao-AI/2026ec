$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$validRows = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    if ($parts[5].StartsWith('0x') -or $parts[5].StartsWith('0X')) {
        $valid = [Convert]::ToInt32($parts[5].Substring(2), 16)
    } else {
        try {
            $valid = [Convert]::ToInt32($parts[5], 16)
        } catch {
            $valid = [int]$parts[5]
        }
    }
    $mag = 0
    try {
        $mag = [Convert]::ToInt32($parts[3], 16)
    } catch {
        $mag = 0
    }
    $bin = 0
    try {
        $bin = [Convert]::ToInt32($parts[4], 16)
    } catch {
        $bin = 0
    }
    if ($valid -ne 0 -and $mag -ne 0) {
        $validRows += New-Object PSObject -Property @{
            mag = $mag
            bin = $bin
        }
    }
}

Write-Host "--- Per-bin max mag (HEX decoded as int) ---"
$groups = $validRows | Group-Object bin | ForEach-Object {
    New-Object PSObject -Property @{
        bin = [int]$_.Name
        maxMag = ($_.Group | Measure-Object mag -Maximum).Maximum
        count = $_.Count
    }
}
$groups | Sort-Object maxMag -Descending | Select-Object -First 10 | Format-Table -AutoSize
Write-Host "`n--- Top bins near target 200 kHz ---"
$groups | Where-Object { $_.bin -ge 400 -and $_.bin -le 420 } | Sort-Object bin | Format-Table -AutoSize
Write-Host "`n--- Around bin 350 ---"
$groups | Where-Object { $_.bin -ge 340 -and $_.bin -le 360 } | Sort-Object bin | Format-Table -AutoSize
Write-Host "`n--- Around bin 449 ---"
$groups | Where-Object { $_.bin -ge 440 -and $_.bin -le 460 } | Sort-Object bin | Format-Table -AutoSize
