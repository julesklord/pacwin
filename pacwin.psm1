# ============================================================
#  pacwin.psm1  -  Universal Package Layer for Windows
#  Abstraction over: winget | chocolatey | scoop
#  Compatible: PowerShell 5.1 + PowerShell 7+
#  v0.2.0 (New Features & PS 5.1 Fixes)
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
    if (-not $name) { return $null }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function _pw_is_admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
            if ($line -match "^\s*$|^-{3,}|^Name\s|[^\x00-\x7F]|%|[\d.]+\s+[KMG]B\s*/") { continue }
            $parts = ($line -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 2) {
                $results.Add([PSCustomObject]@{
                        Name    = $parts[0].Trim()
                        ID      = $(if ($parts.Count -ge 3) { $parts[1].Trim() } else { $parts[0].Trim() })
                        Version = $(if ($parts.Count -ge 3) { $parts[2].Trim() } else { $parts[1].Trim() })
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
        if (-not $dataStart -or $line -match "^\s*$|[^\x00-\x7F]|%|[\d.]+\s+[KMG]B\s*/") { continue }
        $len = $line.Length
        if ($len -le $nameOff) { continue }

        try {
            $vEnd = $(if ($sourceOff -gt 0) { $sourceOff } else { $len })
            $name = $line.Substring($nameOff, [Math]::Min($idOff - $nameOff, $len - $nameOff)).Trim()
            $id = $(if ($len -gt $idOff) { $line.Substring($idOff, [Math]::Min($versionOff - $idOff, $len - $idOff)).Trim() } else { "" })
            $ver = $(if ($len -gt $versionOff) { $line.Substring($versionOff, [Math]::Min($vEnd - $versionOff, $len - $versionOff)).Trim() } else { "?" })
            if ($name -and $id) {
                $results.Add([PSCustomObject]@{
                        Name    = $name
                        ID      = $id
                        Version = $(if ($ver) { $ver } else { "?" })
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
                    Version = $(if ($parts.Count -ge 2) { $parts[1] } else { "?" })
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
            $local_scripts = $using:scripts
            $local_managers = $using:managers
            $script = $local_scripts[$key]
            $exe = $local_managers[$key]
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
        [int]$Limit = 40,

        [Parameter()]
        [switch]$WhatIf
    )

    _pw_header
    $managers = _pw_detect_managers
    if (-not (_pw_assert_managers $managers)) { return }

    $targetManagers = _pw_filter_manager $managers $Manager
    if (-not $targetManagers) { return }

    # Global Admin check for choco/winget operations
    if (-not (_pw_is_admin)) {
        if ($Manager -eq "choco" -or ($null -eq $Manager -and $managers["choco"])) {
            if ($Command -match "^(install|uninstall|update|upgrade|import|pin|unpin|hold|unhold)") {
                _pw_color "  [!] Warning: You are running as a standard user." Yellow
                _pw_color "      Chocolatey (choco) usually requires Administrator privileges to perform this action." Yellow
                _pw_color ""
            }
        }
    }

    if ($Query) {
        $Query = _pw_sanitize $Query
        if (-not $Query) { return }
    }

    switch -Regex ($Command) {
        "^(search|-Ss)$" {
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
            if ($pkg) { _pw_do_install $pkg -WhatIf:$WhatIf }
        }

        "^(uninstall|-R)$" {
            if (-not $Query) { _pw_color "  [!] Package name missing." Yellow; return }
            if (-not $Manager) {
                _pw_color "  [!] Specify a manager with -Manager (winget|choco|scoop)" Yellow
                return
            }
            _pw_do_uninstall $Query $Manager -WhatIf:$WhatIf
        }

        "^(update|upgrade|-Syu)$" {
            if ($Query) {
                _pw_color "  Looking for update candidates for '$Query'..." Cyan
                if ($Manager) {
                    _pw_do_update_single $Query $Manager -WhatIf:$WhatIf
                }
                else {
                    # Try to find which manager has it
                    _pw_color "  Searching in outdated packages..." Gray
                    $outdated = _pw_do_outdated $targetManagers -Silent
                    $matches = $outdated | Where-Object { $_.ID -eq $Query -or $_.Name -eq $Query }
                    
                    if ($matches.Count -eq 0) {
                        _pw_color "  No outdated package found matching '$Query'. Trying direct update..." Gray
                        # Fallback: Try all target managers
                        foreach ($m in $targetManagers.Keys) {
                            _pw_do_update_single $Query $m -WhatIf:$WhatIf
                        }
                    }
                    elseif ($matches.Count -eq 1) {
                        _pw_do_update_single $matches[0].ID $matches[0].Manager -WhatIf:$WhatIf
                    }
                    else {
                        _pw_color "  Multiple managers have updates for '$Query':" Yellow
                        $pkg = _pw_pick_source $matches
                        if ($pkg) { _pw_do_update_single $pkg.ID $pkg.Manager -WhatIf:$WhatIf }
                    }
                }
            }
            else {
                _pw_do_update_all $targetManagers -WhatIf:$WhatIf
            }
        }

        "^(outdated|-Qu)$" {
            _pw_do_outdated $targetManagers
        }

        "^(list|-Q)$" {
            _pw_do_list $targetManagers $Query
        }

        "^(export)$" {
            _pw_do_export $targetManagers $Query
        }

        "^(import)$" {
            if (-not $Query) { _pw_color "  [!] Specify the export file path." Yellow; return }
            _pw_do_import $targetManagers $Query -WhatIf:$WhatIf
        }

        "^(pin|hold)$" {
            if (-not $Query) {
                _pw_do_pin_list $targetManagers
                return
            }
            if (-not $Manager) {
                _pw_color "  [!] Specify a manager with -Manager (winget|choco|scoop)" Yellow
                return
            }
            _pw_do_pin $Query $Manager -WhatIf:$WhatIf
        }

        "^(unpin|unhold)$" {
            if (-not $Query -or -not $Manager) {
                _pw_color "  [!] Requires -Query and -Manager." Yellow; return
            }
            _pw_do_pin $Query $Manager -Unpin -WhatIf:$WhatIf
        }

        "^(doctor|check)$" {
            _pw_do_doctor $targetManagers
        }

        "^(sync|dupes|dedup)$" {
            _pw_do_sync $targetManagers
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
            _pw_color "    pacwin search <query>      (or pacwin -Ss <query>)" White
            _pw_color "    pacwin install <query>     (or pacwin -S <query>)" White
            _pw_color "    pacwin uninstall <name>    (or pacwin -R <name>)" White
            _pw_color "    pacwin update              (or pacwin -Syu)" White
            _pw_color "    pacwin outdated            (or pacwin -Qu)" White
            _pw_color "    pacwin list [filter]       (or pacwin -Q [filter])" White
            _pw_color "    pacwin pin [name]          (freeze a package)" White
            _pw_color "    pacwin unpin <name>        (unfreeze a package)" White
            _pw_color "    pacwin doctor              (environment diagnostics)" White
            _pw_color "    pacwin sync                (detect duplicates)" White
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

#region -- Pin / Hold ---------------------------------------

function _pw_do_pin {
    param([string]$id, [string]$mgr, [switch]$Unpin, [switch]$WhatIf)

    $action = if ($Unpin) { "Unpinning" } else { "Pinning" }
    _pw_color "  -> $action '$id' with $mgr ..." Cyan
    _pw_sep

    if ($WhatIf) {
        _pw_color "  [WhatIf] Would run: " Yellow -NoNewline
        switch ($mgr) {
            "winget" { _pw_color "winget pin $(if ($Unpin) { 'remove' } else { 'add' }) --id $id" White }
            "choco"  { _pw_color "choco pin $(if ($Unpin) { 'remove' } else { 'add' }) --name $id" White }
            "scoop"  { _pw_color "scoop $(if ($Unpin) { 'unhold' } else { 'hold' }) $id" White }
        }
        return
    }

    switch ($mgr) {
        "winget" {
            if ($Unpin) { winget pin remove --id $id }
            else        { winget pin add --id $id --accept-source-agreements }
        }
        "choco"  {
            if ($Unpin) { choco pin remove --name $id }
            else        { choco pin add --name $id }
        }
        "scoop"  {
            if ($Unpin) { scoop unhold $id }
            else        { scoop hold $id }
        }
    }
    _pw_handle_result $mgr $LASTEXITCODE @()
}

function _pw_do_pin_list {
    param($managers)
    _pw_color "  Pinned / held packages:" Cyan
    _pw_sep
    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        winget pin list
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        choco pin list
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        # Scoop doesn't have a direct list command; we check for .hold file
        $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
        $apps = Get-ChildItem "$scoopDir\apps" -Directory -ErrorAction SilentlyContinue
        foreach ($app in $apps) {
            $holdFile = Join-Path $app.FullName "current\.hold"
            if (Test-Path $holdFile) {
                _pw_color "  * $($app.Name) [held]" Green
            }
        }
    }
}

#endregion

#region -- Export / Import ----------------------------------

function _pw_do_export {
    param($managers, [string]$outPath)

    if (-not $outPath) {
        $outPath = Join-Path $HOME "pacwin-export-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
    }

    _pw_color "  Collecting installed packages..." Cyan
    $export = [ordered]@{ generated = (Get-Date -Format 'o'); packages = [System.Collections.Generic.List[Object]]::new() }

    if ($managers["winget"]) {
        # winget export can be slow, we use --accept-source-agreements
        $raw = winget export - --accept-source-agreements 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($raw.Sources) {
            foreach ($src in $raw.Sources) {
                foreach ($pkg in $src.Packages) {
                    $export.packages.Add([ordered]@{
                        manager = "winget"; id = $pkg.PackageIdentifier
                    })
                }
            }
        }
    }
    if ($managers["choco"]) {
        $raw = choco list --local-only --limit-output 2>$null
        foreach ($line in $raw) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 1 -and $parts[0].Trim()) {
                    $export.packages.Add([ordered]@{
                    manager = "choco"; id = $parts[0].Trim()
                    })
            }
        }
    }
    if ($managers["scoop"]) {
        $raw = scoop export 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($raw.apps) {
            foreach ($app in $raw.apps) {
                    $export.packages.Add([ordered]@{
                    manager = "scoop"; id = $app.Name
                    })
            }
        }
    }

    $export | ConvertTo-Json -Depth 5 | Out-File $outPath -Encoding UTF8
    _pw_color "  [OK] Exported $($export.packages.Count) packages to:" Green
    _pw_color "       $outPath" DarkGray
}

function _pw_do_import {
    param($managers, [string]$inPath, [switch]$WhatIf)

    if (-not $inPath -or -not (Test-Path $inPath)) {
        _pw_color "  [!] File not found: '$inPath'" Red; return
    }

    $data = Get-Content $inPath -Raw | ConvertFrom-Json -ErrorAction Stop
    _pw_color "  Importing $($data.packages.Count) packages from export..." Cyan
    _pw_sep

    $failed = @()
    foreach ($pkg in $data.packages) {
        if (-not $managers[$pkg.manager]) {
            _pw_color "  [SKIP] $($pkg.id) - manager '$($pkg.manager)' not available." DarkGray
            continue
        }
        _pw_color "  -> $($pkg.manager): $($pkg.id)" Cyan
        
        if ($WhatIf) {
             _pw_color "     [WhatIf] Would install $($pkg.id) via $($pkg.manager)" Yellow
             continue
        }

        $output = @()
        switch ($pkg.manager) {
            "winget" { $output = winget install --id $pkg.id --accept-package-agreements --accept-source-agreements 2>&1 }
            "choco"  { $output = choco install $pkg.id -y 2>&1 }
            "scoop"  { $output = scoop install $pkg.id 2>&1 }
        }
        if ($LASTEXITCODE -ne 0) { $failed += $pkg.id }
    }

    _pw_sep
    if ($WhatIf) {
        _pw_color "  [WhatIf] Import simulation completed." Yellow
    }
    elseif ($failed.Count -eq 0) {
        _pw_color "  [OK] All packages installed successfully." Green
    } else {
        _pw_color "  [!] Failed: $($failed -join ', ')" Red
    }
}

#endregion

#region -- Doctor -------------------------------------------

function _pw_do_doctor {
    param($managers)

    _pw_color "  Running diagnostics..." Cyan
    _pw_sep
    $issues = 0

    # Administrator check
    $isAdmin = _pw_is_admin
    _pw_color ("  Privileges   : {0}" -f $(if ($isAdmin) { "Administrator" } else { "User" })) $(if ($isAdmin) { "Green" } else { "Yellow" })
    if (-not $isAdmin -and $managers["choco"]) {
        _pw_color "  [!] Warning: Chocolatey (choco) usually requires Administrator privileges." Yellow
        $issues++
    }

    # PowerShell version
    $psv = $PSVersionTable.PSVersion
    _pw_color ("  PS Version   : {0}" -f $psv) $(if ($psv.Major -ge 5) { "Green" } else { "Red" })
    if ($psv.Major -lt 5) { _pw_color "  [!] PowerShell 5.1+ required." Red; $issues++ }

    # Manager presence & version
    foreach ($mgr in @("winget","choco","scoop")) {
        $exe = _pw_exe $mgr
        if ($exe) {
            $ver = try {
                switch ($mgr) {
                    "winget" { (winget --version 2>$null) -replace "[^\d\.]","" }
                    "choco"  { (choco --version 2>$null) }
                    "scoop"  { (scoop --version 2>$null) | Select-Object -First 1 }
                }
            } catch { "Error" }
            _pw_color ("  {0,-12} : OK  {1}" -f $mgr, $ver) Green
        } else {
            _pw_color ("  {0,-12} : NOT FOUND" -f $mgr) DarkGray
        }
    }

    # Connectivity check
    _pw_color "" 
    _pw_color "  Connectivity:" DarkGray
    $hosts = @("winget.azureedge.net","community.chocolatey.org","github.com")
    foreach ($h in $hosts) {
        $ok = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue
        _pw_color ("  {0,-32} : {1}" -f $h, $(if ($ok) { "OK" } else { "UNREACHABLE" })) $(if ($ok) { "Green" } else { "Red" })
        if (-not $ok) { $issues++ }
    }

    # Scoop buckets stale check
    if ($managers["scoop"]) {
        _pw_color ""
        _pw_color "  Scoop buckets:" DarkGray
        $buckets = scoop bucket list 2>$null
        foreach ($b in $buckets) {
            $name = ($b -split "\s+")[0]
            _pw_color "  Bucket: $name" DarkGray
        }
        # Check last update time of main bucket
        $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
        $mainBucket = "$scoopDir\buckets\main"
        if (Test-Path $mainBucket) {
            $lastFetch = Get-Item "$mainBucket\.git\FETCH_HEAD" -ErrorAction SilentlyContinue
            if ($lastFetch) {
                $age = (Get-Date) - $lastFetch.LastWriteTime
                $ageStr = "{0}d {1}h" -f [int]$age.TotalDays, $age.Hours
                $stale = $age.TotalDays -gt 3
                _pw_color ("  main bucket age  : {0}" -f $ageStr) $(if ($stale) { "Yellow" } else { "Green" })
                if ($stale) {
                    _pw_color "  [!] Stale bucket. Run: scoop update" Yellow
                    $issues++
                }
            }
        }
    }

    _pw_sep
    if ($issues -eq 0) {
        _pw_color "  [OK] No issues detected." Green
    } else {
        _pw_color ("  [{0} issue(s) found]" -f $issues) Yellow
    }
}

#endregion

#region -- Sync (duplicate detection) ----------------------

function _pw_do_sync {
    param($managers)

    _pw_color "  Scanning for cross-manager duplicates..." Cyan
    _pw_sep

    $installed = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($managers["winget"]) {
        $raw = winget list --accept-source-agreements 2>$null
        $lines = @($raw | ForEach-Object { "$_" })
        $parsed = _pw_parse_winget_lines $lines
        foreach ($p in $parsed) { $installed.Add($p) }
    }
    if ($managers["choco"]) {
        $raw = choco list --local-only --limit-output 2>$null
        foreach ($line in $raw) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 1 -and $parts[0].Trim()) {
                $installed.Add([PSCustomObject]@{
                    Name = $parts[0].Trim(); ID = $parts[0].Trim()
                    Version = $(if ($parts.Count -ge 2) { $parts[1] } else { "?" })
                    Source = "chocolatey"; Manager = "choco"
                })
            }
        }
    }
    if ($managers["scoop"]) {
        $raw = scoop list 2>$null
        foreach ($line in $raw) {
            $parts = ("$line".Trim() -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 1 -and $parts[0] -notmatch "^Name$|^Installed") {
                $installed.Add([PSCustomObject]@{
                    Name = $parts[0]; ID = $parts[0]
                    Version = $(if ($parts.Count -ge 2) { $parts[1] } else { "?" })
                    Source = "scoop"; Manager = "scoop"
                })
            }
        }
    }

    # Normalize name (lowercase, no symbols) for grouping
    $groups = $installed | Group-Object { $_.Name.ToLower() -replace "[\-_\. ]","" }
    $dupes  = $groups | Where-Object { $_.Count -gt 1 }

    if ($dupes.Count -eq 0) {
        _pw_color "  [OK] No duplicate packages detected." Green
        return
    }

    _pw_color ("  Found {0} potential duplicate(s):" -f $dupes.Count) Yellow
    _pw_color ""

    foreach ($dupe in $dupes) {
        _pw_color ("  Package: {0}" -f $dupe.Group[0].Name) White
        foreach ($pkg in $dupe.Group) {
            $col = if ($script:SRC_COLORS[$pkg.Source]) { $script:SRC_COLORS[$pkg.Source] } else { "White" }
            _pw_color ("    [{0}] v{1}" -f $pkg.Source, $pkg.Version) $col
        }
        _pw_color "  Suggestion: keep one, run 'pacwin uninstall <id> -Manager <mgr>'" DarkGray
        _pw_color ""
    }
}

#endregion

#region -- Operations ---------------------------------------

function _pw_do_install {
    param([PSCustomObject]$pkg, [switch]$WhatIf)
    _pw_color ""
    _pw_color "  -> Installing: $($pkg.Name)  [$($pkg.Source)  v$($pkg.Version)]" Cyan
    _pw_sep
    
    if ($WhatIf) {
        _pw_color "  [WhatIf] Would run: " Yellow -NoNewline
        switch ($pkg.Manager) {
            "winget" { _pw_color "winget install --id $($pkg.ID) --accept-package-agreements --accept-source-agreements" White }
            "choco"  { _pw_color "choco install $($pkg.ID) -y" White }
            "scoop"  { _pw_color "scoop install $($pkg.ID)" White }
        }
        return
    }

    $output = @()
    switch ($pkg.Manager) {
        "winget" { $output = winget install --id $pkg.ID --accept-package-agreements --accept-source-agreements 2>&1 }
        "choco"  { $output = choco install $pkg.ID -y 2>&1 }
        "scoop"  { $output = scoop install $pkg.ID 2>&1 }
    }
    _pw_handle_result $pkg.Manager $LASTEXITCODE $output
}

function _pw_do_uninstall {
    param([string]$name, [string]$mgr, [switch]$WhatIf)
    _pw_color ""
    _pw_color "  -> Uninstalling '$name' with $mgr ..." Yellow
    _pw_sep
    
    if ($WhatIf) {
        _pw_color "  [WhatIf] Would run: " Yellow -NoNewline
        switch ($mgr) {
            "winget" { _pw_color "winget uninstall --name $name" White }
            "choco"  { _pw_color "choco uninstall $name -y" White }
            "scoop"  { _pw_color "scoop uninstall $name" White }
        }
        return
    }

    $output = @()
    switch ($mgr) {
        "winget" { $output = winget uninstall --name $name 2>&1 }
        "choco"  { $output = choco uninstall $name -y 2>&1 }
        "scoop"  { $output = scoop uninstall $name 2>&1 }
    }
    _pw_handle_result $mgr $LASTEXITCODE $output
}

function _pw_do_update_single {
    param([string]$id, [string]$mgr, [switch]$WhatIf)
    _pw_color ""
    _pw_color "  -> Updating '$id' with $mgr ..." Cyan
    _pw_sep
    
    if ($WhatIf) {
        _pw_color "  [WhatIf] Would run: " Yellow -NoNewline
        switch ($mgr) {
            "winget" { _pw_color "winget upgrade --id $id --accept-package-agreements --accept-source-agreements" White }
            "choco"  { _pw_color "choco upgrade $id -y" White }
            "scoop"  { _pw_color "scoop update $id" White }
        }
        return
    }

    $output = @()
    switch ($mgr) {
        "winget" { $output = winget upgrade --id $id --accept-package-agreements --accept-source-agreements 2>&1 }
        "choco"  { $output = choco upgrade $id -y 2>&1 }
        "scoop"  { $output = scoop update $id 2>&1 }
    }
    _pw_handle_result $mgr $LASTEXITCODE $output
}

function _pw_do_update_all {
    param($managers, [switch]$WhatIf)
    if ($WhatIf) {
        _pw_color "  [WhatIf] Performing dry-run update for all managers..." Yellow
    }

    if ($managers["winget"]) {
        _pw_color "  -- winget -----------------------------" Cyan
        if ($WhatIf) { _pw_color "  [WhatIf] Would run: winget upgrade --all --accept-package-agreements --accept-source-agreements" White }
        else         { winget upgrade --all --accept-package-agreements --accept-source-agreements }
    }
    if ($managers["choco"]) {
        _pw_color "  -- chocolatey -------------------------" Yellow
        if ($WhatIf) { _pw_color "  [WhatIf] Would run: choco upgrade all -y" White }
        else         { choco upgrade all -y }
    }
    if ($managers["scoop"]) {
        _pw_color "  -- scoop ------------------------------" Green
        if ($WhatIf) { _pw_color "  [WhatIf] Would run: scoop update *" White }
        else         { scoop update * }
    }
}

function _pw_do_outdated {
    param($managers, [switch]$Silent)

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($managers["winget"]) {
        if (-not $Silent) { _pw_color "  -- winget -----------------------------" Cyan }
        $out = winget upgrade --accept-source-agreements 2>$null
        $lines = @($out | ForEach-Object { "$_" })
        $parsed = _pw_parse_winget_lines $lines
        foreach ($p in $parsed) { $allResults.Add($p) }
    }
    if ($managers["choco"]) {
        if (-not $Silent) { _pw_color "  -- chocolatey -------------------------" Yellow }
        $out = choco outdated --limit-output 2>$null
        foreach ($line in $out) {
            if ($line -match "^\s*$") { continue }
            $parts = $line -split "\|"
            if ($parts.Count -ge 3) {
                $allResults.Add([PSCustomObject]@{
                    Name    = $parts[0]; ID = $parts[0]
                    Version = $parts[2]; Source = "chocolatey"; Manager = "choco"
                })
            }
        }
    }
    if ($managers["scoop"]) {
        if (-not $Silent) { _pw_color "  -- scoop ------------------------------" Green }
        $out = scoop status 2>$null
        foreach ($line in $out) {
            if ($line -match "(\S+)\s+has\s+a\s+new\s+version") {
                $allResults.Add([PSCustomObject]@{
                    Name    = $Matches[1]; ID = $Matches[1]
                    Version = "Later"; Source = "scoop"; Manager = "scoop"
                })
            }
        }
    }

    if ($Silent) { return $allResults }

    # Non-silent: render results via standard table
    if ($allResults.Count -eq 0) {
        _pw_color "  [OK] All packages are up to date." Green
    }
    else {
        _pw_color "  Outdated packages ($($allResults.Count) found):" Yellow
        _pw_render_results $allResults
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
        if ($filter) { choco list --local-only $filter } else { choco list --local-only }
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

#region -- Tab Completion -----------------------------------

Register-ArgumentCompleter -CommandName pacwin -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $cmds = @(
        'search','install','uninstall','update','outdated','list',
        'info','pin','unpin','export','import','doctor','status','help'
    )
    $cmds | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_,                                      # completionText
            $_,                                      # listItemText
            [System.Management.Automation.CompletionResultType]::ParameterValue,
            $_                                       # toolTip
        )
    }
}

Register-ArgumentCompleter -CommandName pacwin -ParameterName Manager -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    @('winget','choco','scoop') | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 
            [System.Management.Automation.CompletionResultType]::ParameterValue, $_)
    }
}

# Completar -Query con paquetes instalados cuando el comando es uninstall/pin/update
Register-ArgumentCompleter -CommandName pacwin -ParameterName Query -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $cmd = $fakeBoundParameters['Command']
    if ($cmd -notin @('uninstall','pin','unpin','update','info')) { return }
    # Intenta completar con winget list (rÃ¡pido)
    $raw = winget list --query $wordToComplete 2>$null | Select-Object -Skip 3
    foreach ($line in $raw) {
        $parts = ($line -split "\s{2,}").Where({ $_ -ne "" })
        if ($parts.Count -ge 2 -and $parts[0] -notmatch "^-{3}") {
            $id = $parts[1]
            [System.Management.Automation.CompletionResult]::new($id, $id,
                [System.Management.Automation.CompletionResultType]::ParameterValue, $parts[0])
        }
    }
}

#endregion

