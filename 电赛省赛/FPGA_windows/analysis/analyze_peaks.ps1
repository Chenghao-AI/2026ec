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
$results | Sort-Object mag -Descending | Select-Object -First 20 | Format-Table -AutoSize

Write-Host "--- Peak bins (sorted by bin) ---"
$results | Sort-Object bin | Group-Object bin | ForEach-Object {
    $maxMag = ($_.Group | Measure-Object mag -Maximum).Maximum
    "{0}|{1}" -f $_.Name, $maxMag
} | Sort-Object {[regex]::Replace($_, '^\d+', { '$(& )'.PadLeft(5) }) } -Descending | Select-Object -First 30

Write-Host "--- Top bins by max mag (sorted numerically) ---"
$results | Sort-Object bin | Group-Object bin | ForEach-Object {
    $maxMag = ($_.Group | Measure-Object mag -Maximum).Maximum
    New-Object PSObject -Property @{
        bin = [int]$_.Name
        maxMag = [int]$maxMag
    }
} | Sort-Object maxMag -Descending | Select-Object -First 20 | Format-Table -AutoSize
