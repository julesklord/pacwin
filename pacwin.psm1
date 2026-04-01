# ============================================================
#  pacwin.psm1  —  Universal Package Layer for Windows
#  Abstraction over: winget | chocolatey | scoop
# ============================================================

#region ── Helpers & Detection ─────────────────────────────

function _pw_color { param([string]$text, [string]$color = "White"); Write-Host $text -ForegroundColor $color }

function _pw_header {
    _pw_color ""
    _pw_color "  ╔══════════════════════════════════════╗" Cyan
    _pw_color "  ║  pacwin  —  universal package layer  ║" Cyan
    _pw_color "  ╚══════════════════════════════════════╝" Cyan
    _pw_color ""
}

function _pw_detect_managers {
    $managers = [ordered]@{}
    if (Get-Command winget -ErrorAction SilentlyContinue) { $managers["winget"] = $true }
    if (Get-Command choco -ErrorAction SilentlyContinue)  { $managers["choco"]  = $true }
    if (Get-Command scoop -ErrorAction SilentlyContinue)  { $managers["scoop"]  = $true }
    return $managers
}

function _pw_assert_managers {
    param($managers)
    if ($managers.Count -eq 0) {
        _pw_color "  [!] No se detectó ningún gestor de paquetes." Red
        _pw_color "      Instala winget, chocolatey o scoop para usar pacwin." Yellow
        return $false
    }
    return $true
}

#endregion

#region ── Search Engine ────────────────────────────────────

function _pw_search_winget {
    param([string]$query)
    $results = @()
    try {
        $raw = winget search --query $query --accept-source-agreements 2>$null |
               Select-String -Pattern "^\S" |
               Where-Object { $_ -notmatch "^Name|^-{3,}|^$" }
        foreach ($line in $raw) {
            $parts = ($line.Line -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 2) {
                $results += [PSCustomObject]@{
                    Name    = $parts[0]
                    ID      = if ($parts.Count -ge 3) { $parts[1] } else { "-" }
                    Version = if ($parts.Count -ge 3) { $parts[2] } else { $parts[1] }
                    Source  = "winget"
                    Manager = "winget"
                }
            }
        }
    } catch {}
    return $results
}

function _pw_search_choco {
    param([string]$query)
    $results = @()
    try {
        $raw = choco search $query --limit-output 2>$null
        foreach ($line in $raw) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 2) {
                $results += [PSCustomObject]@{
                    Name    = $parts[0]
                    ID      = $parts[0]
                    Version = $parts[1]
                    Source  = "chocolatey"
                    Manager = "choco"
                }
            }
        }
    } catch {}
    return $results
}

function _pw_search_scoop {
    param([string]$query)
    $results = @()
    try {
        $raw = scoop search $query 2>$null | Where-Object { $_ -match "\S" }
        $inResults = $false
        foreach ($line in $raw) {
            if ($line -match "^Results from") { $inResults = $true; continue }
            if ($inResults -and $line -match "^\s+(\S+)\s+\((\S+)\)") {
                $results += [PSCustomObject]@{
                    Name    = $Matches[1]
                    ID      = $Matches[1]
                    Version = $Matches[2]
                    Source  = "scoop"
                    Manager = "scoop"
                }
            } elseif ($inResults -and $line -match "^\s+'([^']+)'\s+bucket:\s+(\S+)") {
                # newer scoop format
            } elseif ($inResults -and $line -notmatch "^\s*$" -and $line -notmatch "^-") {
                $parts = ($line.Trim() -split "\s+")
                if ($parts.Count -ge 1 -and $parts[0] -notmatch "^[Nn]ame") {
                    $results += [PSCustomObject]@{
                        Name    = $parts[0]
                        ID      = $parts[0]
                        Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                        Source  = "scoop"
                        Manager = "scoop"
                    }
                }
            }
        }
    } catch {}
    return $results
}

#endregion

#region ── Result Renderer ──────────────────────────────────

function _pw_render_results {
    param($results, [string]$query)

    if ($results.Count -eq 0) {
        _pw_color "  Sin resultados para '$query'." Yellow
        return
    }

    $sourceColors = @{
        "winget"     = "Cyan"
        "chocolatey" = "Yellow"
        "scoop"      = "Green"
    }

    _pw_color ("  {0,-40} {1,-20} {2,-12} {3}" -f "Nombre","ID","Versión","Fuente") DarkGray
    _pw_color ("  " + ("-" * 80)) DarkGray

    $i = 1
    foreach ($r in $results) {
        $col = $sourceColors[$r.Source]
        $idx = "[$i]".PadRight(4)
        $name = $r.Name.Substring(0, [Math]::Min($r.Name.Length, 38)).PadRight(40)
        $id   = $r.ID.Substring(0, [Math]::Min($r.ID.Length, 18)).PadRight(20)
        $ver  = $r.Version.PadRight(12)
        Write-Host ("  " + $idx) -ForegroundColor DarkGray -NoNewline
        Write-Host ($name + $id + $ver) -NoNewline
        Write-Host $r.Source -ForegroundColor $col
        $i++
    }
    _pw_color ""
}

#endregion

#region ── Install / Uninstall / Update ─────────────────────

function _pw_install_with {
    param([PSCustomObject]$pkg)

    _pw_color "  → Instalando '$($pkg.Name)' desde $($pkg.Source) ..." Cyan
    _pw_color ""

    switch ($pkg.Manager) {
        "winget" { winget install --id $pkg.ID --accept-package-agreements --accept-source-agreements }
        "choco"  { choco install $pkg.ID -y }
        "scoop"  { scoop install $pkg.ID }
    }
}

function _pw_uninstall_with {
    param([string]$packageName, [string]$manager)

    _pw_color "  → Desinstalando '$packageName' con $manager ..." Yellow

    switch ($manager) {
        "winget" { winget uninstall --name $packageName }
        "choco"  { choco uninstall $packageName -y }
        "scoop"  { scoop uninstall $packageName }
    }
}

function _pw_update_all {
    param($managers)

    _pw_color "  Actualizando todos los gestores activos..." Cyan
    _pw_color ""

    if ($managers["winget"]) {
        _pw_color "  [winget] actualizando..." Cyan
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }
    if ($managers["choco"]) {
        _pw_color "  [choco] actualizando..." Yellow
        choco upgrade all -y
    }
    if ($managers["scoop"]) {
        _pw_color "  [scoop] actualizando..." Green
        scoop update *
    }
}

#endregion

#region ── Info ─────────────────────────────────────────────

function _pw_info_package {
    param([string]$query, $managers)

    _pw_color "  Info para: $query" Cyan
    _pw_color ""

    if ($managers["winget"]) {
        _pw_color "  ── winget ─────────────────────────────" Cyan
        winget show $query 2>$null
    }
    if ($managers["choco"]) {
        _pw_color "  ── chocolatey ─────────────────────────" Yellow
        choco info $query 2>$null
    }
}

#endregion

#region ── List Installed ───────────────────────────────────

function _pw_list_installed {
    param($managers, [string]$filter = "")

    _pw_color "  Paquetes instalados:" Cyan
    _pw_color ""

    if ($managers["winget"]) {
        _pw_color "  ── winget ─────────────────────────────" Cyan
        if ($filter) { winget list --query $filter } else { winget list }
    }
    if ($managers["choco"]) {
        _pw_color "  ── chocolatey ─────────────────────────" Yellow
        if ($filter) { choco list --local-only | Where-Object { $_ -match $filter } }
        else { choco list --local-only }
    }
    if ($managers["scoop"]) {
        _pw_color "  ── scoop ──────────────────────────────" Green
        if ($filter) { scoop list | Where-Object { $_ -match $filter } }
        else { scoop list }
    }
}

#endregion

#region ── Interactive Source Selector ──────────────────────

function _pw_pick_source {
    param($matches_for_pkg)

    if ($matches_for_pkg.Count -eq 1) {
        return $matches_for_pkg[0]
    }

    _pw_color "  Múltiples fuentes disponibles para este paquete:" Yellow
    _pw_color ""

    $sourceColors = @{ "winget" = "Cyan"; "chocolatey" = "Yellow"; "scoop" = "Green" }

    $i = 1
    foreach ($m in $matches_for_pkg) {
        $col = $sourceColors[$m.Source]
        Write-Host ("    [{0}] " -f $i) -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-30}" -f $m.Name) -NoNewline
        Write-Host ("v{0,-15}" -f $m.Version) -NoNewline
        Write-Host $m.Source -ForegroundColor $col
        $i++
    }

    _pw_color ""
    $choice = Read-Host "  Elige fuente (número)"

    $idx = [int]$choice - 1
    if ($idx -ge 0 -and $idx -lt $matches_for_pkg.Count) {
        return $matches_for_pkg[$idx]
    } else {
        _pw_color "  Selección inválida." Red
        return $null
    }
}

#endregion

#region ── Main Entry Point ─────────────────────────────────

function pacwin {
    param(
        [Parameter(Position = 0)] [string]$Command = "help",
        [Parameter(Position = 1)] [string]$Query    = "",
        [switch]$All,
        [string]$Manager = ""
    )

    $managers = _pw_detect_managers

    switch ($Command.ToLower()) {

        # ── SEARCH ──────────────────────────────────────────
        "search" {
            if (-not $Query) { _pw_color "  Uso: pacwin search <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }

            _pw_header
            _pw_color "  Buscando '$Query' en: $($managers.Keys -join ', ')..." DarkGray
            _pw_color ""

            $all_results = @()
            $jobs = @{}

            # Búsqueda paralela con jobs
            if ($managers["winget"]) {
                $jobs["winget"] = Start-Job -ScriptBlock {
                    param($q)
                    $r = @()
                    $raw = winget search --query $q --accept-source-agreements 2>$null |
                           Select-String -Pattern "^\S" |
                           Where-Object { $_ -notmatch "^Name|^-{3,}|^$" }
                    foreach ($line in $raw) {
                        $parts = ($line.Line -split "\s{2,}").Where({ $_ -ne "" })
                        if ($parts.Count -ge 2) {
                            $r += [PSCustomObject]@{
                                Name    = $parts[0]
                                ID      = if ($parts.Count -ge 3) { $parts[1] } else { "-" }
                                Version = if ($parts.Count -ge 3) { $parts[2] } else { $parts[1] }
                                Source  = "winget"; Manager = "winget"
                            }
                        }
                    }
                    return $r
                } -ArgumentList $Query
            }

            if ($managers["choco"]) {
                $jobs["choco"] = Start-Job -ScriptBlock {
                    param($q)
                    $r = @()
                    $raw = choco search $q --limit-output 2>$null
                    foreach ($line in $raw) {
                        $parts = $line -split "\|"
                        if ($parts.Count -ge 2) {
                            $r += [PSCustomObject]@{
                                Name    = $parts[0]; ID = $parts[0]
                                Version = $parts[1]; Source = "chocolatey"; Manager = "choco"
                            }
                        }
                    }
                    return $r
                } -ArgumentList $Query
            }

            if ($managers["scoop"]) {
                $jobs["scoop"] = Start-Job -ScriptBlock {
                    param($q)
                    $r = @()
                    $raw = scoop search $q 2>$null | Where-Object { $_ -match "\S" }
                    $inResults = $false
                    foreach ($line in $raw) {
                        if ($line -match "^Results from") { $inResults = $true; continue }
                        if ($inResults) {
                            $parts = ($line.Trim() -split "\s+")
                            if ($parts.Count -ge 1 -and $parts[0] -notmatch "^[Nn]ame|^-") {
                                $r += [PSCustomObject]@{
                                    Name    = $parts[0]; ID = $parts[0]
                                    Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                                    Source  = "scoop"; Manager = "scoop"
                                }
                            }
                        }
                    }
                    return $r
                } -ArgumentList $Query
            }

            # Esperar y recolectar
            foreach ($key in $jobs.Keys) {
                $job = $jobs[$key]
                $job | Wait-Job | Out-Null
                $res = Receive-Job $job
                if ($res) { $all_results += $res }
                Remove-Job $job
            }

            _pw_render_results $all_results $Query

            if ($all_results.Count -gt 0) {
                _pw_color "  Total: $($all_results.Count) resultado(s). Usa 'pacwin install <nombre>' para instalar." DarkGray
            }
        }

        # ── INSTALL ─────────────────────────────────────────
        "install" {
            if (-not $Query) { _pw_color "  Uso: pacwin install <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }

            _pw_header
            _pw_color "  Buscando '$Query'..." DarkGray
            _pw_color ""

            $all_results = @()
            if ($managers["winget"])  { $all_results += _pw_search_winget $Query }
            if ($managers["choco"])   { $all_results += _pw_search_choco  $Query }
            if ($managers["scoop"])   { $all_results += _pw_search_scoop  $Query }

            if ($all_results.Count -eq 0) {
                _pw_color "  Sin resultados para '$Query'." Yellow
                return
            }

            # Filtrar por coincidencia exacta primero, luego mostrar todo
            $exact = $all_results | Where-Object {
                $_.Name -like "*$Query*" -or $_.ID -like "*$Query*"
            }

            $pool = if ($exact.Count -gt 0) { $exact } else { $all_results }

            _pw_render_results $pool $Query

            # Si el Manager fue forzado, filtrar por ese
            if ($Manager) {
                $pool = $pool | Where-Object { $_.Manager -eq $Manager }
                if ($pool.Count -eq 0) {
                    _pw_color "  No hay resultados en el gestor '$Manager'." Red
                    return
                }
            }

            $choice = Read-Host "  Número a instalar (Enter para cancelar)"
            if ([string]::IsNullOrWhiteSpace($choice)) { return }

            $idx = [int]$choice - 1
            if ($idx -lt 0 -or $idx -ge $pool.Count) {
                _pw_color "  Número inválido." Red
                return
            }

            $selected = $pool[$idx]

            # Ver si el mismo nombre existe en múltiples fuentes
            $same_name = $pool | Where-Object { $_.Name -eq $selected.Name -and $_.Source -ne $selected.Source }

            if ($same_name.Count -gt 0) {
                $candidates = @($selected) + $same_name
                $final = _pw_pick_source $candidates
                if ($null -eq $final) { return }
                _pw_install_with $final
            } else {
                _pw_install_with $selected
            }
        }

        # ── UNINSTALL ────────────────────────────────────────
        "uninstall" {
            if (-not $Query) { _pw_color "  Uso: pacwin uninstall <nombre>" Yellow; return }

            $mgr = if ($Manager) { $Manager } else {
                _pw_color "  ¿Con qué gestor desinstalar? [winget/choco/scoop]: " Yellow -NoNewline
                Read-Host
            }

            _pw_color ""
            _pw_uninstall_with $Query $mgr
        }

        # ── UPDATE ───────────────────────────────────────────
        "update" {
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header

            if ($Query) {
                # actualizar paquete específico
                $mgr = if ($Manager) { $Manager } else { "winget" }
                _pw_color "  Actualizando '$Query' con $mgr..." Cyan
                switch ($mgr) {
                    "winget" { winget upgrade --id $Query --accept-package-agreements --accept-source-agreements }
                    "choco"  { choco upgrade $Query -y }
                    "scoop"  { scoop update $Query }
                }
            } else {
                _pw_update_all $managers
            }
        }

        # ── LIST ─────────────────────────────────────────────
        "list" {
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header
            _pw_list_installed $managers $Query
        }

        # ── INFO ─────────────────────────────────────────────
        "info" {
            if (-not $Query) { _pw_color "  Uso: pacwin info <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header
            _pw_info_package $Query $managers
        }

        # ── STATUS ───────────────────────────────────────────
        "status" {
            _pw_header
            _pw_color "  Gestores detectados:" Cyan
            _pw_color ""

            $sourceColors = @{ "winget" = "Cyan"; "chocolatey" = "Yellow"; "scoop" = "Green" }

            $all = @("winget", "choco", "scoop")
            foreach ($m in $all) {
                $available = $managers[$m]
                $col  = if ($available) { $sourceColors[$m] ?? "White" } else { "DarkGray" }
                $mark = if ($available) { "✓" } else { "✗" }
                Write-Host ("    {0} " -f $mark) -ForegroundColor $col -NoNewline
                Write-Host $m -ForegroundColor $col
            }
            _pw_color ""
        }

        # ── HELP ─────────────────────────────────────────────
        default {
            _pw_header
            _pw_color "  Uso:" Cyan
            _pw_color ""
            _pw_color "    pacwin search  <nombre>              Busca en todos los gestores activos" White
            _pw_color "    pacwin install <nombre>              Busca e instala (con selector de fuente)" White
            _pw_color "    pacwin uninstall <nombre>            Desinstala un paquete" White
            _pw_color "    pacwin update   [nombre]             Actualiza todo o un paquete específico" White
            _pw_color "    pacwin list     [filtro]             Lista paquetes instalados" White
            _pw_color "    pacwin info     <nombre>             Muestra info detallada del paquete" White
            _pw_color "    pacwin status                        Muestra gestores disponibles" White
            _pw_color ""
            _pw_color "  Flags opcionales:" DarkGray
            _pw_color "    -Manager winget|choco|scoop          Fuerza un gestor específico" DarkGray
            _pw_color ""
            _pw_color "  Ejemplos:" DarkGray
            _pw_color "    pacwin search vlc" DarkGray
            _pw_color "    pacwin install nodejs" DarkGray
            _pw_color "    pacwin install nodejs -Manager scoop" DarkGray
            _pw_color "    pacwin update" DarkGray
            _pw_color "    pacwin uninstall vlc" DarkGray
            _pw_color ""
        }
    }
}

Export-ModuleMember -Function pacwin
