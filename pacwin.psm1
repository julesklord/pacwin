# ============================================================
#  pacwin.psm1  -  Universal Package Layer for Windows
#  Abstraction over: winget | chocolatey | scoop
#  Compatible: PowerShell 5.1 + PowerShell 7+
#  v1.2.1 (i18n + Cleanup)
# ============================================================

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

#region -- Security & Validation -----------------------------

function _pw_sanitize {
    param([string]$targetInput)
    if (-not $targetInput) { return $null }
    if ($targetInput -match '^[a-zA-Z0-9\._\-@/]+$') {
        return $targetInput
    }
    _pw_color "  [!] Input detected as a potential security risk: '$targetInput'" Red
    return $null
}

#endregion

#region -- Helpers ------------------------------------------

function _pw_color {
    param(
        [string]$text,
        [string]$color = "White",
        [switch]$NoNewline
    )
    if ($NoNewline) {
        Write-Host $text -ForegroundColor $color -NoNewline
    }
    else {
        Write-Host $text -ForegroundColor $color
    }
}

function _pw_header {
    _pw_color "  +--------------------------------------+" Cyan
    _pw_color "  |   pacwin  -  universal pkg layer     |" Cyan
    _pw_color "  +--------------------------------------+" Cyan
}

function _pw_sep { _pw_color ("  " + ("-" * 68)) DarkGray }

function _pw_exe {
    param([string]$name)
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

#endregion

#region -- Manager Detection --------------------------------

function _pw_detect_managers {
    $m = [ordered]@{}
    $wingetExe = _pw_exe "winget"
    $chocoExe = _pw_exe "choco"
    $scoopExe = _pw_exe "scoop"
    if ($wingetExe) { $m["winget"] = $wingetExe }
    if ($chocoExe) { $m["choco"] = $chocoExe }
    if ($scoopExe) { $m["scoop"] = $scoopExe }
    return $m
}

function _pw_assert_managers {
    param($managers)
    if ($managers.Count -eq 0) {
        _pw_color "  [!] No package manager detected." Red
        _pw_color "      Install winget, chocolatey, or scoop to use pacwin." Yellow
        return $false
    }
    return $true
}

function _pw_filter_manager {
    param($managers, [string]$mgr)
    if (-not $mgr) { return $managers }
    if (-not $managers[$mgr]) {
        _pw_color "  [!] Manager '$mgr' not available on this system." Red
        return $null
    }
    $sub = [ordered]@{}
    $sub[$mgr] = $managers[$mgr]
    return $sub
}

#endregion

#region -- Parsers ------------------------------------------

function _pw_parse_winget_lines {
    param([string[]]$lines)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $headerLine = $lines | Where-Object { $_ -match "^Name\s+Id\s+Version" } | Select-Object -First 1

    if (-not $headerLine) {
        foreach ($line in $lines) {
            # Skip progress bars, speeds, and headers
            if ($line -match "^\s*$|^-{3,}|^Name\s|[â—Æê]|%|[\d.]+\s+[KMG]B\s*/") { continue }
            $parts = ($line -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 2) {
                $results.Add([PSCustomObject]@{
                        Name    = $parts[0].Trim()
                        ID      = if ($parts.Count -ge 3) { $parts[1].Trim() } else { $parts[0].Trim() }
                        Version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { $parts[1].Trim() }
                        Source  = "winget"
                        Manager = "winget"
                    })
            }
        }
        return $results
    }

    $nameOff = $headerLine.IndexOf("Name")
    $idOff = $headerLine.IndexOf("Id")
    $versionOff = $headerLine.IndexOf("Version")
    $sourceOff = $headerLine.IndexOf("Source")

    $dataStart = $false
    foreach ($line in $lines) {
        if ($line -match "^-{3,}") { $dataStart = $true; continue }
        if (-not $dataStart -or $line -match "^\s*$|[â—Æê]|%|[\d.]+\s+[KMG]B\s*/") { continue }
        $len = $line.Length
        if ($len -le $nameOff) { continue }

        try {
            $vEnd = if ($sourceOff -gt 0) { $sourceOff } else { $len }
            $name = $line.Substring($nameOff, [Math]::Min($idOff - $nameOff, $len - $nameOff)).Trim()
            $id = if ($len -gt $idOff) { $line.Substring($idOff, [Math]::Min($versionOff - $idOff, $len - $idOff)).Trim() } else { "" }
            $ver = if ($len -gt $versionOff) { $line.Substring($versionOff, [Math]::Min($vEnd - $versionOff, $len - $versionOff)).Trim() } else { "?" }
            if ($name -and $id) {
                $results.Add([PSCustomObject]@{
                        Name    = $name
                        ID      = $id
                        Version = if ($ver) { $ver } else { "?" }
                        Source  = "winget"
                        Manager = "winget"
                    })
            }
        }
        catch { continue }
    }
    return $results
}

function _pw_parse_choco_lines {
    param([string[]]$lines)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($line in $lines) {
        $parts = $line -split "\|"
        if ($parts.Count -ge 2 -and $parts[0].Trim() -ne "") {
            $results.Add([PSCustomObject]@{
                    Name    = $parts[0].Trim()
                    ID      = $parts[0].Trim()
                    Version = $parts[1].Trim()
                    Source  = "chocolatey"
                    Manager = "choco"
                })
        }
    }
    return $results
}

function _pw_parse_scoop_lines {
    param([string[]]$lines)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $inResults = $false
    foreach ($line in $lines) {
        if ($line -match "^Results from") { $inResults = $true; continue }
        if (-not $inResults -or $line -match "^\s*$|^-{3,}") { continue }

        if ($line -match "^\s+(\S+)\s+\(([^)]+)\)") {
            $results.Add([PSCustomObject]@{
                    Name = $Matches[1]; ID = $Matches[1]
                    Version = $Matches[2]; Source = "scoop"; Manager = "scoop"
                })
            continue
        }
        $parts = ($line.Trim() -split "\s{2,}").Where({ $_ -ne "" })
        if ($parts.Count -ge 1 -and $parts[0] -notmatch "^[Nn]ame$|^Source$") {
            $results.Add([PSCustomObject]@{
                    Name = $parts[0]; ID = $parts[0]
                    Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                    Source = "scoop"; Manager = "scoop"
                })
        }
    }
    return $results
}

#endregion

#region -- Search Engine ------------------------------------

function _pw_search_all {
    param($managers, [string]$query, [int]$limit = 40)

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $scripts = [ordered]@{}

    if ($managers["winget"]) {
        $scripts["winget"] = { param($exe, $q) try { & $exe search --query $q --accept-source-agreements --no-upgrade 2>$null } catch { @() } }
    }
    if ($managers["choco"]) {
        $scripts["choco"] = { param($exe, $q) try { & $exe search $q --limit-output 2>$null } catch { @() } }
    }
    if ($managers["scoop"]) {
        $scripts["scoop"] = { param($exe, $q) try { & $exe search $q 2>$null } catch { @() } }
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # High-performance Parallel execution for PowerShell 7+
        $jobResults = $scripts.Keys | ForEach-Object -Parallel {
            $key = $_
            $script = $using:scripts[$key]
            $exe = $using:managers[$key]
            $q = $using:query
            $raw = & $script $exe $q
            return @{ Key = $key; Raw = $raw }
        } -ThrottleLimit 3
        
        foreach ($res in $jobResults) {
            $lines = @($res.Raw | ForEach-Object { "$_" })
            switch ($res.Key) {
                "winget" { $parsed = _pw_parse_winget_lines $lines }
                "choco"  { $parsed = _pw_parse_choco_lines  $lines }
                "scoop"  { $parsed = _pw_parse_scoop_lines  $lines }
            }
            foreach ($r in $parsed) { $results.Add($r) }
        }
    }
    else {
        # Efficient Runspace implementation for PowerShell 5.1
        $runspaces = New-Object System.Collections.Generic.List[Object]
        $rsPool = [runspacefactory]::CreateRunspacePool(1, 3)
        $rsPool.Open()

        foreach ($key in $scripts.Keys) {
            $ps = [powershell]::Create().AddScript($scripts[$key]).AddArgument($managers[$key]).AddArgument($query)
            $ps.RunspacePool = $rsPool
            $runspaces.Add(@{ Key = $key; PowerShell = $ps; AsyncResult = $ps.BeginInvoke() })
        }

        foreach ($rs in $runspaces) {
            # Wait with 25s timeout
            $waitCount = 0
            while (-not $rs.AsyncResult.IsCompleted -and $waitCount -lt 250) {
                Start-Sleep -Milliseconds 100
                $waitCount++
            }
            if ($rs.AsyncResult.IsCompleted) {
                $raw = $rs.PowerShell.EndInvoke($rs.AsyncResult)
                $lines = @($raw | ForEach-Object { "$_" })
                switch ($rs.Key) {
                    "winget" { $parsed = _pw_parse_winget_lines $lines }
                    "choco"  { $parsed = _pw_parse_choco_lines  $lines }
                    "scoop"  { $parsed = _pw_parse_scoop_lines  $lines }
                }
                foreach ($r in $parsed) { $results.Add($r) }
            }
            else { _pw_color "  [!] Timeout in $($rs.Key)." DarkGray }
            $rs.PowerShell.Dispose()
        }
        $rsPool.Close()
    }

    if ($results.Count -gt $limit) { return $results | Select-Object -First $limit }
    return $results
}

#endregion

#region -- Main Entry Point ---------------------------------

function pacwin {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$Query,

        [Parameter()]
        [ValidateSet("winget", "choco", "scoop")]
        [string]$Manager,

        [Parameter()]
        [int]$Limit = 40
    )

    _pw_header
    $managers = _pw_detect_managers
    if (-not (_pw_assert_managers $managers)) { return }

    $targetManagers = _pw_filter_manager $managers $Manager
    if (-not $targetManagers) { return }

    if ($Query) {
        $Query = _pw_sanitize $Query
        if (-not $Query) { return }
    }

    switch -Regex ($Command) {
        "^(search|-S)$" {
            if (-not $Query) { _pw_color "  [!] Search term missing." Yellow; return }
            _pw_color "  > Searching for '$Query'..." Cyan
            $results = _pw_search_all $targetManagers $Query $Limit
            _pw_render_results $results $Query
        }

        "^(info|-Si)$" {
            if (-not $Query) { _pw_color "  [!] Package name missing." Yellow; return }
            _pw_do_info $targetManagers $Query
        }

        "^(install|-S)$" {
            if (-not $Query) { _pw_color "  [!] Package name missing." Yellow; return }
            _pw_color "  Looking for candidates for '$Query'..." Cyan
            $results = _pw_search_all $targetManagers $Query $Limit
            
            if ($results.Count -eq 0) {
                _pw_color "  No packages found for '$Query'." Yellow
                return
            }

            $pkg = _pw_pick_source $results
            if ($pkg) { _pw_do_install $pkg }
        }

        "^(uninstall|-R)$" {
            if (-not $Query) { _pw_color "  [!] Package name missing." Yellow; return }
            if (-not $Manager) {
                _pw_color "  [!] Specify a manager with -Manager (winget|choco|scoop)" Yellow
                return
            }
            _pw_do_uninstall $Query $Manager
        }

        "^(update|upgrade|-Syu)$" {
            if ($Query) {
                _pw_color "  Individual update not yet implemented." Yellow
            }
            else {
                _pw_do_update_all $targetManagers
            }
        }

        "^(outdated|-Qu)$" {
            _pw_do_outdated $targetManagers
        }

        "^(list|-Q)$" {
            _pw_do_list $targetManagers $Query
        }

        "^(status)$" {
            _pw_color "  Detected Managers:" Cyan
            $managers.Keys | ForEach-Object {
                _pw_color "  * $_ " Cyan -NoNewline
                _pw_color "-> $($managers[$_])" DarkGray
            }
        }

        "^(help|--help|-h)$" {
            _pw_color "  Usage:" Yellow
            _pw_color "    pacwin search <query>      (or pacwin -S <query>)" White
            _pw_color "    pacwin install <query>     (or pacwin -S <query>)" White
            _pw_color "    pacwin uninstall <name>    (or pacwin -R <name>)" White
            _pw_color "    pacwin update              (or pacwin -Syu)" White
            _pw_color "    pacwin outdated            (or pacwin -Qu)" White
            _pw_color "    pacwin list [filter]       (or pacwin -Q [filter])" White
            _pw_color "    pacwin status" White
        }

        Default {
            _pw_color "  Unknown command '$Command'. Use 'pacwin help'." Yellow
        }
    }
}

#endregion

#region -- Renderer -----------------------------------------

$script:SRC_COLORS = @{
    "winget"     = "Cyan"
    "chocolatey" = "Yellow"
    "scoop"      = "Green"
}

function _pw_truncate {
    param([string]$str, [int]$max)
    if (-not $str) { return "".PadRight($max) }
    if ($str.Length -le $max) { return $str.PadRight($max) }
    return ($str.Substring(0, $max - 1) + ".")
}

function _pw_render_results {
    param([object]$results, [string]$query = "", [switch]$NoIndex)

    $arr = @($results)
    if ($arr.Count -eq 0) {
        if ($query) { _pw_color "  No results for '$query'." Yellow }
        return
    }

    _pw_color ""
    if (-not $NoIndex) {
        _pw_color ("  {0,-4} {1,-36} {2,-24} {3,-14} {4}" -f "#", "Name", "ID", "Version", "Source") DarkGray
    }
    else {
        _pw_color ("  {0,-36} {1,-24} {2,-14} {3}" -f "Name", "ID", "Version", "Source") DarkGray
    }
    _pw_sep

    $i = 1
    foreach ($r in $arr) {
        $col = if ($script:SRC_COLORS[$r.Source]) { $script:SRC_COLORS[$r.Source] } else { "White" }
        $name = _pw_truncate $r.Name 34
        $id = _pw_truncate $r.ID   22
        $ver = _pw_truncate $r.Version 12

        if (-not $NoIndex) {
            _pw_color ("  [{0,-2}] " -f $i) DarkGray -NoNewline
        }
        else {
            _pw_color "  " DarkGray -NoNewline
        }
        _pw_color ("{0,-36}{1,-24}{2,-14}" -f $name, $id, $ver) White -NoNewline
        _pw_color $r.Source $col
        $i++
    }
    _pw_color ""
}

#endregion

#region -- Operations ---------------------------------------

function _pw_do_install {
    param([PSCustomObject]$pkg)
    _pw_color ""
    _pw_color "  -> Installing: $($pkg.Name)  [$($pkg.Source)  v$($pkg.Version)]" Cyan
    _pw_sep
    
    $output = @()
    switch ($pkg.Manager) {
        "winget" { $output = winget install --id $pkg.ID --accept-package-agreements --accept-source-agreements 2>&1 }
        "choco"  { $output = choco install $pkg.ID -y 2>&1 }
        "scoop"  { $output = scoop install $pkg.ID 2>&1 }
    }
    _pw_handle_result $pkg.Manager $LASTEXITCODE $output
}

function _pw_do_uninstall {
    param([string]$name, [string]$mgr)
    _pw_color ""
    _pw_color "  -> Uninstalling '$name' with $mgr ..." Yellow
    _pw_sep
    
    $output = @()
    switch ($mgr) {
        "winget" { $output = winget uninstall --name $name 2>&1 }
        "choco"  { $output = choco uninstall $name -y 2>&1 }
        "scoop"  { $output = scoop uninstall $name 2>&1 }
    }
    _pw_handle_result $mgr $LASTEXITCODE $output
}

function _pw_do_update_all {
    param($managers)
    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        choco upgrade all -y
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        scoop update *
    }
}

function _pw_do_outdated {
    param($managers)
    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        winget upgrade --accept-source-agreements 2>$null
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        choco outdated 2>$null
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        scoop status 2>$null
    }
}

function _pw_do_list {
    param($managers, [string]$filter)
    
    _pw_color "  Listing installed packages..." Cyan
    if ($filter) { _pw_color "  (Filter: '$filter')" DarkGray }

    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        if ($filter) { winget list --query $filter } else { winget list }
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        if ($filter) { choco list -l $filter } else { choco list -l }
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        if ($filter) { scoop list $filter } else { scoop list }
    }
}

function _pw_do_info {
    param($managers, [string]$name)
    
    _pw_color "  Fetching information for '$name'..." Cyan

    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        winget show --id $name --accept-source-agreements
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        choco info $name
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        scoop info $name
    }
}

function _pw_handle_result {
    param(
        [string]$manager,
        [int]$exitCode,
        [string[]]$output
    )

    $outputText = $output -join "`n"
    $success = $false
    $msg = ""

    switch ($manager) {
        "winget" {
            if ($exitCode -eq 0) { $success = $true }
            elseif ($exitCode -eq -1978335186) { $msg = "Restart required to complete." }
            else { $msg = "Winget Error (Code: $exitCode)." }
        }
        "choco" {
            if ($exitCode -eq 0 -or $exitCode -eq 1641 -or $exitCode -eq 3010) { 
                $success = $true 
                if ($exitCode -ne 0) { $msg = "Success (Restart required)." }
            }
            else { $msg = "Chocolatey Error (Code: $exitCode)." }
        }
        "scoop" {
            if ($outputText -match "installed successfully|already installed") {
                $success = $true
            }
            elseif ($outputText -match "Couldn't find manifest|Access denied") {
                $success = $false
                $msg = "Scoop Error: " + ($output | Select-String "Error:" | Select-Object -First 1)
            }
            else {
                $success = ($exitCode -eq 0)
            }
        }
    }

    if ($success) {
        _pw_color "  [OK] Operation completed successfully. $msg" Green
    } else {
        _pw_color "  [FAILURE] The operation could not be completed." Red
        if ($msg) { _pw_color "  Detail: $msg" Yellow }
        else { _pw_color "  Check previous output for more details." DarkGray }
    }
}

#endregion

#region -- Source Picker ------------------------------------

function _pw_pick_source {
    param([object]$candidates)
    $arr = @($candidates)
    if ($arr.Count -eq 1) { return $arr[0] }

    _pw_color "  Package available in multiple sources - pick one:" Yellow
    _pw_render_results $arr

    $choice = Read-Host "  Source index (Number, Enter=cancel)"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $null }

    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $arr.Count) {
        _pw_color "  Invalid selection." Red; return $null
    }
    return $arr[$idx - 1]
}

#endregion
