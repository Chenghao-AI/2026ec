$lines = Get-Content 'C:\Users\24307\Desktop\FPGA_windows\Vivado\result\iladata.csv'
$maxMagRaw = ""
$maxDec = 0
$maxBinRaw = ""
$maxBinDec = 0

# 只看 mag 字段的 hex 字符串长度
$lengthCount = @{}
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $magStr = $parts[3]
    $binStr = $parts[4]
    $len = $magStr.Length
    if (-not $lengthCount.ContainsKey($len)) { $lengthCount[$len] = 0 }
    $lengthCount[$len]++
    
    # 计算 hex 值
    $magDec = 0
    try { $magDec = [Convert]::ToInt32($magStr, 16) } catch {}
    if ($magDec -gt $maxDec) {
        $maxDec = $magDec
        $maxMagRaw = $magStr
        $maxBinRaw = $binStr
        $maxBinDec = [Convert]::ToInt32($binStr, 16)
    }
}

Write-Host "Mag hex string length distribution:"
$lengthCount.Keys | Sort-Object | ForEach-Object { "{0} chars: {1} samples" -f $_, $lengthCount[$_] }

Write-Host "`nMax mag (hex): $maxMagRaw = $maxDec (dec)"
Write-Host "At bin (hex): $maxBinRaw = $maxBinDec (dec)"
Write-Host "Freq at max mag: $([math]::Round($maxBinDec * 4e6 / 8192 / 1000, 2)) kHz"

# 列出所有 mag 的最大值（top 20）
$allMags = @()
foreach ($line in ($lines | Select-Object -Skip 2)) {
    $parts = $line.Split(',')
    if ($parts.Length -lt 7) { continue }
    $valid = 0
    try { $valid = [Convert]::ToInt32($parts[5], 16) } catch {}
    if ($valid -ne 0) {
        $magDec = 0
        try { $magDec = [Convert]::ToInt32($parts[3], 16) } catch {}
        if ($magDec -gt 0) {
            $allMags += $magDec
        }
    }
}

Write-Host "`nTop 30 mag values from ILA CSV:"
$allMags | Sort-Object -Descending | Select-Object -First 30 | ForEach-Object { Write-Host $_ }
