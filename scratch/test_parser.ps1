
# Mock winget output for different locales

$spanishOutput = @(
    "Nombre                         Id                                         Versión          Origen",
    "-------------------------------------------------------------------------------------------------",
    "Node.js (LTS)                  OpenJS.NodeJS.LTS                          20.12.2          winget",
    "Git                            Git.Git                                    2.44.0.windows.1 winget"
)

$germanOutput = @(
    "Name                           ID                                         Version          Quelle",
    "-------------------------------------------------------------------------------------------------",
    "Node.js (LTS)                  OpenJS.NodeJS.LTS                          20.12.2          winget",
    "Visual Studio Code             Microsoft.VisualStudioCode                 1.88.1           winget"
)

# Load the module logic (simplified for test)
function _pw_parse_winget_lines {
    param([string[]]$lines)
    $results = New-Object System.Collections.Generic.List[PSCustomObject]
    
    $separatorLine = $lines | Where-Object { $_ -match "^-{5,}" } | Select-Object -First 1
    
    if (-not $separatorLine) {
        foreach ($line in $lines) {
            if ($line -match "^\s*$|^-{3,}|[^\x00-\x7F]|%|[\d.]+\s+[KMG]B\s*/") { continue }
            $parts = ($line.Trim() -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 2) {
                $results.Add([PSCustomObject]@{ Name = $parts[0].Trim(); ID = $parts[1].Trim(); Version = "?" })
            }
        }
        return $results
    }

    $matches = [regex]::Matches($separatorLine, "-+")
    
    if ($matches.Count -ge 2) {
        $nameOff    = $matches[0].Index
        $nameLen    = $matches[0].Length
        $idOff      = $matches[1].Index
        $idLen      = $matches[1].Length
        $versionOff = if ($matches.Count -ge 3) { $matches[2].Index } else { -1 }
        $versionLen = if ($matches.Count -ge 3) { $matches[2].Length } else { -1 }
        $sourceOff  = if ($matches.Count -ge 4) { $matches[3].Index } else { -1 }
    }
    else {
        $sepIdx = [array]::IndexOf($lines, $separatorLine)
        if ($sepIdx -gt 0) {
            $headerLine = $lines[$sepIdx - 1]
            $parts = [regex]::Matches($headerLine, "\S+")
            if ($parts.Count -ge 2) {
                $nameOff = $parts[0].Index
                $idOff = $parts[1].Index
                $versionOff = if ($parts.Count -ge 3) { $parts[2].Index } else { -1 }
                $sourceOff = if ($parts.Count -ge 4) { $parts[3].Index } else { -1 }
                $nameLen = $idOff - $nameOff
                $idLen = if ($versionOff -gt 0) { $versionOff - $idOff } else { 100 }
                $versionLen = if ($sourceOff -gt 0) { $sourceOff - $versionOff } else { 100 }
            }
            else { return $results }
        }
        else { return $results }
    }

    $dataStart = $false
    foreach ($line in $lines) {
        if ($line -eq $separatorLine) { $dataStart = $true; continue }
        if (-not $dataStart) { continue }
        $len = $line.Length
        if ($len -le $nameOff) { continue }
        try {
            $name = $line.Substring($nameOff, [Math]::Min($nameLen, $len - $nameOff)).Trim()
            $id = if ($idOff -lt $len) { $line.Substring($idOff, [Math]::Min($idLen, $len - $idOff)).Trim() } else { "" }
            $ver = "?"
            if ($versionOff -gt 0 -and $versionOff -lt $len) {
                $vLen = if ($sourceOff -gt $versionOff) { $sourceOff - $versionOff } else { $versionLen }
                $ver = $line.Substring($versionOff, [Math]::Min($vLen, $len - $versionOff)).Trim()
            }
            if ($name -and $id) { $results.Add([PSCustomObject]@{ Name = $name; ID = $id; Version = $ver }) }
        } catch { }
    }
    return $results
}

Write-Host "Testing Spanish Output..." -ForegroundColor Cyan
$resES = _pw_parse_winget_lines $spanishOutput
$resES | Format-Table

Write-Host "Testing German Output..." -ForegroundColor Cyan
$resDE = _pw_parse_winget_lines $germanOutput
$resDE | Format-Table
