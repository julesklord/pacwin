# ============================================================
#  pacwin.psm1  —  Universal Package Layer for Windows
#  Abstraction over: winget | chocolatey | scoop
#  Compatible: PowerShell 5.1 + PowerShell 7+
# ============================================================

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"

#region ── Helpers ──────────────────────────────────────────

function _pw_color {
    param(
        [string]$text,
        [string]$color    = "White",
        [switch]$NoNewline
    )
    if ($NoNewline) {
        Write-Host $text -ForegroundColor $color -NoNewline
    } else {
        Write-Host $text -ForegroundColor $color
    }
}

function _pw_header {
    _pw_color ""
    _pw_color "  ╔══════════════════════════════════════╗" Cyan
    _pw_color "  ║   pacwin  —  universal pkg layer     ║" Cyan
    _pw_color "  ╚══════════════════════════════════════╝" Cyan
    _pw_color ""
}

function _pw_sep { _pw_color ("  " + ("─" * 68)) DarkGray }

# Resuelve ruta absoluta del ejecutable — necesario para jobs PS5.1
# que no heredan PATH del proceso padre
function _pw_exe {
    param([string]$name)
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}


#endregion

#region ── Manager Detection ────────────────────────────────

function _pw_detect_managers {
    $m = [ordered]@{}
    # Guardamos la ruta del exe, no solo $true — los jobs necesitan la ruta
    $wingetExe = _pw_exe "winget"
    $chocoExe  = _pw_exe "choco"
    $scoopExe  = _pw_exe "scoop"
    if ($wingetExe) { $m["winget"] = $wingetExe }
    if ($chocoExe)  { $m["choco"]  = $chocoExe  }
    if ($scoopExe)  { $m["scoop"]  = $scoopExe  }
    return $m
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

#region ── Parsers (síncronos, sin jobs) ────────────────────

function _pw_parse_winget_lines {
    param([string[]]$lines)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # winget imprime una tabla con columnas separadas por ≥2 espacios
    # La primera línea útil es el header — la usamos para detectar offsets exactos
    $headerLine = $lines | Where-Object { $_ -match "^Name\s+Id\s+Version" } | Select-Object -First 1
    if (-not $headerLine) {
        # fallback: parseo genérico por espacios múltiples
        foreach ($line in $lines) {
            if ($line -match "^\s*$" -or $line -match "^-{3,}" -or $line -match "^Name\s") { continue }
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

    # Calcular offsets por posición de columna
    $nameOff    = $headerLine.IndexOf("Name")
    $idOff      = $headerLine.IndexOf("Id")
    $versionOff = $headerLine.IndexOf("Version")
    $sourceOff  = $headerLine.IndexOf("Source")

    $dataStart = $false
    foreach ($line in $lines) {
        if ($line -match "^-{3,}") { $dataStart = $true; continue }
        if (-not $dataStart) { continue }
        if ($line -match "^\s*$") { continue }
        $len = $line.Length
        if ($len -le $nameOff) { continue }

        $name    = ""
        $id      = ""
        $version = ""
        $src     = "winget"

        try {
            $name    = if ($len -gt $nameOff)    { $line.Substring($nameOff,    [Math]::Min($idOff - $nameOff,       $len - $nameOff)).Trim()    } else { "" }
            $id      = if ($len -gt $idOff)      { $line.Substring($idOff,      [Math]::Min($versionOff - $idOff,   $len - $idOff)).Trim()      } else { "" }
            $version = if ($len -gt $versionOff) { $line.Substring($versionOff, [Math]::Min(($sourceOff -gt 0 ? $sourceOff : $len) - $versionOff, $len - $versionOff)).Trim() } else { "" }
        } catch { continue }

        if ($name -and $id) {
            $results.Add([PSCustomObject]@{
                Name    = $name
                ID      = $id
                Version = if ($version) { $version } else { "?" }
                Source  = $src
                Manager = "winget"
            })
        }
    }
    return $results
}


function _pw_parse_choco_lines {
    param([string[]]$lines)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($line in $lines) {
        # choco --limit-output produce: NombrePaquete|versión
        $parts = $line -split "\|"
        if ($parts.Count -ge 2 -and $parts[0] -notmatch "^\s*$") {
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
        if (-not $inResults) { continue }
        if ($line -match "^\s*$" -or $line -match "^-{3,}") { continue }

        # Formato moderno: "  nombre (versión) [bucket]"
        if ($line -match "^\s+(\S+)\s+\(([^)]+)\)") {
            $results.Add([PSCustomObject]@{
                Name    = $Matches[1]
                ID      = $Matches[1]
                Version = $Matches[2]
                Source  = "scoop"
                Manager = "scoop"
            })
            continue
        }
        # Formato antiguo: columnas separadas
        $parts = ($line.Trim() -split "\s{2,}").Where({ $_ -ne "" })
        if ($parts.Count -ge 1 -and $parts[0] -notmatch "^[Nn]ame$|^Source$") {
            $results.Add([PSCustomObject]@{
                Name    = $parts[0]
                ID      = $parts[0]
                Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                Source  = "scoop"
                Manager = "scoop"
            })
        }
    }
    return $results
}

#endregion

#region ── Search Engine (Jobs con exePath explícito) ────────

function _pw_search_all {
    param($managers, [string]$query, [int]$limit = 40)

    $results   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $jobs      = @{}
    $exePaths  = @{}   # guardamos exe paths para pasarlos a los jobs

    # ── Lanzar jobs ──────────────────────────────────────────
    if ($managers["winget"]) {
        $exe = $managers["winget"]
        $jobs["winget"] = Start-Job -ScriptBlock {
            param($exe, $q)
            try { & $exe search --query $q --accept-source-agreements 2>$null }
            catch { @() }
        } -ArgumentList $exe, $query
    }

    if ($managers["choco"]) {
        $exe = $managers["choco"]
        $jobs["choco"] = Start-Job -ScriptBlock {
            param($exe, $q)
            try { & $exe search $q --limit-output 2>$null }
            catch { @() }
        } -ArgumentList $exe, $query
    }

    if ($managers["scoop"]) {
        $exe = $managers["scoop"]
        $jobs["scoop"] = Start-Job -ScriptBlock {
            param($exe, $q)
            try { & $exe search $q 2>$null }
            catch { @() }
        } -ArgumentList $exe, $query
    }

    # ── Recolectar con timeout por job ───────────────────────
    foreach ($key in $jobs.Keys) {
        $job = $jobs[$key]
        $finished = $job | Wait-Job -Timeout 25
        if ($finished) {
            $raw = Receive-Job $job -ErrorAction SilentlyContinue
            $lines = @($raw | ForEach-Object { "$_" })  # asegurar strings
            switch ($key) {
                "winget" { $parsed = _pw_parse_winget_lines $lines }
                "choco"  { $parsed = _pw_parse_choco_lines  $lines }
                "scoop"  { $parsed = _pw_parse_scoop_lines  $lines }
            }
            foreach ($r in $parsed) { $results.Add($r) }
        } else {
            _pw_color "  [!] Timeout en $key — omitiendo." DarkGray
            $job | Stop-Job
        }
        Remove-Job $job -Force
    }

    # Limitar resultados si hay demasiados
    if ($results.Count -gt $limit) {
        return $results | Select-Object -First $limit
    }
    return $results
}

#endregion


#region ── Renderer ─────────────────────────────────────────

$script:SRC_COLORS = @{
    "winget"     = "Cyan"
    "chocolatey" = "Yellow"
    "scoop"      = "Green"
}

function _pw_render_results {
    param(
        [object]$results,
        [string]$query    = "",
        [switch]$NoIndex
    )

    # Garantizar array aunque sea 1 objeto o nulo
    $arr = @($results)

    if ($arr.Count -eq 0) {
        if ($query) { _pw_color "  Sin resultados para '$query'." Yellow }
        return
    }

    # Header tabla
    _pw_color ""
    if (-not $NoIndex) {
        _pw_color ("  {0,-4} {1,-36} {2,-24} {3,-14} {4}" -f "#","Nombre","ID","Versión","Fuente") DarkGray
    } else {
        _pw_color ("  {0,-36} {1,-24} {2,-14} {3}" -f "Nombre","ID","Versión","Fuente") DarkGray
    }
    _pw_sep

    $i = 1
    foreach ($r in $arr) {
        $col  = $script:SRC_COLORS[$r.Source]
        if (-not $col) { $col = "White" }

        $name = _pw_truncate $r.Name 34
        $id   = _pw_truncate $r.ID   22
        $ver  = _pw_truncate $r.Version 12

        if (-not $NoIndex) {
            _pw_color ("  [{0,-2}] " -f $i) DarkGray -NoNewline
            _pw_color ("{0,-36}{1,-24}{2,-14}" -f $name,$id,$ver) White -NoNewline
        } else {
            _pw_color ("  {0,-36}{1,-24}{2,-14}" -f $name,$id,$ver) White -NoNewline
        }
        _pw_color $r.Source $col
        $i++
    }
    _pw_color ""
}

function _pw_truncate {
    param([string]$str, [int]$max)
    if (-not $str) { return "".PadRight($max) }
    if ($str.Length -le $max) { return $str.PadRight($max) }
    return ($str.Substring(0, $max - 1) + "…")
}

#endregion

#region ── Install / Uninstall / Update / Outdated ──────────

function _pw_do_install {
    param([PSCustomObject]$pkg)
    _pw_color ""
    _pw_color "  → Instalando: $($pkg.Name)  [$($pkg.Source)  v$($pkg.Version)]" Cyan
    _pw_sep
    switch ($pkg.Manager) {
        "winget" { winget install --id $pkg.ID --accept-package-agreements --accept-source-agreements }
        "choco"  { choco install $pkg.ID -y }
        "scoop"  { scoop install $pkg.ID }
    }
}

function _pw_do_uninstall {
    param([string]$name, [string]$mgr)
    _pw_color ""
    _pw_color "  → Desinstalando '$name' con $mgr ..." Yellow
    _pw_sep
    switch ($mgr) {
        "winget" { winget uninstall --name $name }
        "choco"  { choco uninstall $name -y }
        "scoop"  { scoop uninstall $name }
    }
}

function _pw_do_update_all {
    param($managers)
    _pw_color "  Actualizando todos los gestores activos..." Cyan
    _pw_color ""
    if ($managers["winget"]) {
        _pw_color "  ── winget ──────────────────────" Cyan
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }
    if ($managers["choco"]) {
        _pw_color "  ── chocolatey ──────────────────" Yellow
        choco upgrade all -y
    }
    if ($managers["scoop"]) {
        _pw_color "  ── scoop ───────────────────────" Green
        scoop update *
    }
}

function _pw_do_outdated {
    param($managers)
    _pw_color "  Paquetes con actualizaciones disponibles:" Cyan
    _pw_color ""
    if ($managers["winget"]) {
        _pw_color "  ── winget ──────────────────────" Cyan
        winget upgrade --accept-source-agreements 2>$null | Where-Object { $_ -notmatch "^\s*$" }
    }
    if ($managers["choco"]) {
        _pw_color "  ── chocolatey ──────────────────" Yellow
        choco outdated 2>$null
    }
    if ($managers["scoop"]) {
        _pw_color "  ── scoop ───────────────────────" Green
        scoop status 2>$null
    }
}

#endregion


#region ── Source Picker ────────────────────────────────────

function _pw_pick_source {
    param([object]$candidates)
    $arr = @($candidates)
    if ($arr.Count -eq 1) { return $arr[0] }

    _pw_color "  Mismo paquete disponible en múltiples fuentes:" Yellow
    _pw_color ""
    _pw_render_results $arr -NoIndex:$false

    $choice = Read-Host "  Elige fuente (número, Enter=cancelar)"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $null }

    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx)) {
        _pw_color "  Entrada inválida." Red; return $null
    }
    $idx--
    if ($idx -lt 0 -or $idx -ge $arr.Count) {
        _pw_color "  Número fuera de rango." Red; return $null
    }
    return $arr[$idx]
}

#endregion

#region ── Main Entry Point ─────────────────────────────────

function pacwin {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("search","install","uninstall","remove","update","upgrade",
                     "list","info","outdated","status","help","")]
        [string]$Command = "help",

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$Args = @(),

        # Fuerza un gestor específico para la operación
        [ValidateSet("winget","choco","scoop","")]
        [string]$Manager = "",

        # Límite de resultados en search/install
        [int]$Limit = 40
    )

    # Unir args en query string
    $Query = ($Args -join " ").Trim()

    $managers = _pw_detect_managers

    switch ($Command.ToLower()) {

        # ── SEARCH ──────────────────────────────────────────
        "search" {
            if (-not $Query) { _pw_color "  Uso: pacwin search <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }

            _pw_header
            # Filtrar por Manager si se especificó
            if ($Manager) {
                $active = [ordered]@{}
                if ($managers[$Manager]) { $active[$Manager] = $managers[$Manager] }
                else { _pw_color "  [!] Gestor '$Manager' no disponible." Red; return }
                $managers = $active
            }

            _pw_color "  Buscando '$Query' en: $(($managers.Keys) -join ', ') ..." DarkGray
            $all = _pw_search_all $managers $Query $Limit
            _pw_render_results $all $Query

            if ($all.Count -gt 0) {
                _pw_color "  $($all.Count) resultado(s)  ·  pacwin install <nombre> para instalar" DarkGray
            }
        }

        # ── INSTALL ─────────────────────────────────────────
        "install" {
            if (-not $Query) { _pw_color "  Uso: pacwin install <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }

            _pw_header
            _pw_color "  Buscando '$Query'..." DarkGray

            $searchMgr = $managers
            if ($Manager) {
                $searchMgr = [ordered]@{}
                if ($managers[$Manager]) { $searchMgr[$Manager] = $managers[$Manager] }
                else { _pw_color "  [!] Gestor '$Manager' no disponible." Red; return }
            }

            $all = _pw_search_all $searchMgr $Query $Limit

            if ($all.Count -eq 0) {
                _pw_color "  Sin resultados para '$Query'." Yellow; return
            }

            # Priorizar coincidencias exactas
            $exact = @($all | Where-Object { $_.Name -like "*$Query*" -or $_.ID -like "*$Query*" })
            $pool  = if ($exact.Count -gt 0) { $exact } else { @($all) }

            _pw_render_results $pool $Query

            $choice = Read-Host "  Número a instalar (Enter=cancelar)"
            if ([string]::IsNullOrWhiteSpace($choice)) { return }

            $idx = 0
            if (-not [int]::TryParse($choice, [ref]$idx)) {
                _pw_color "  Entrada inválida." Red; return
            }
            $idx--
            if ($idx -lt 0 -or $idx -ge $pool.Count) {
                _pw_color "  Número fuera de rango." Red; return
            }

            $selected = $pool[$idx]

            # Verificar si hay el mismo ID disponible en otras fuentes
            $dupes = @($pool | Where-Object {
                $_.ID -eq $selected.ID -and $_.Source -ne $selected.Source
            })

            if ($dupes.Count -gt 0) {
                $final = _pw_pick_source (@($selected) + $dupes)
                if ($null -eq $final) { return }
                _pw_do_install $final
            } else {
                _pw_do_install $selected
            }
        }


        # ── UNINSTALL / REMOVE ───────────────────────────────
        { $_ -in "uninstall","remove" } {
            if (-not $Query) { _pw_color "  Uso: pacwin uninstall <nombre>" Yellow; return }

            $mgr = $Manager
            if (-not $mgr) {
                _pw_color "  ¿Con qué gestor? [winget/choco/scoop]: " Yellow -NoNewline
                $mgr = (Read-Host).Trim()
            }
            if ($mgr -notin @("winget","choco","scoop")) {
                _pw_color "  Gestor inválido: '$mgr'" Red; return
            }
            _pw_do_uninstall $Query $mgr
        }

        # ── UPDATE / UPGRADE ─────────────────────────────────
        { $_ -in "update","upgrade" } {
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header

            if ($Query) {
                $mgr = if ($Manager) { $Manager } else { "winget" }
                _pw_color "  Actualizando '$Query' con $mgr..." Cyan
                switch ($mgr) {
                    "winget" { winget upgrade --id $Query --accept-package-agreements --accept-source-agreements }
                    "choco"  { choco upgrade $Query -y }
                    "scoop"  { scoop update $Query }
                }
            } else {
                $active = $managers
                if ($Manager) {
                    $active = [ordered]@{}
                    if ($managers[$Manager]) { $active[$Manager] = $managers[$Manager] }
                }
                _pw_do_update_all $active
            }
        }

        # ── OUTDATED ─────────────────────────────────────────
        "outdated" {
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header
            $active = $managers
            if ($Manager) {
                $active = [ordered]@{}
                if ($managers[$Manager]) { $active[$Manager] = $managers[$Manager] }
            }
            _pw_do_outdated $active
        }

        # ── LIST ─────────────────────────────────────────────
        "list" {
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header
            _pw_color "  Paquetes instalados:" Cyan
            _pw_color ""

            $active = $managers
            if ($Manager) {
                $active = [ordered]@{}
                if ($managers[$Manager]) { $active[$Manager] = $managers[$Manager] }
            }

            if ($active["winget"]) {
                _pw_color "  ── winget ──────────────────────────────" Cyan
                if ($Query) { winget list --query $Query } else { winget list }
            }
            if ($active["choco"]) {
                _pw_color "  ── chocolatey ──────────────────────────" Yellow
                # choco list (sin --local-only, deprecado en v2)
                if ($Query) { choco list | Where-Object { $_ -match $Query } }
                else { choco list }
            }
            if ($active["scoop"]) {
                _pw_color "  ── scoop ───────────────────────────────" Green
                if ($Query) { scoop list | Where-Object { $_ -match $Query } }
                else { scoop list }
            }
        }

        # ── INFO ─────────────────────────────────────────────
        "info" {
            if (-not $Query) { _pw_color "  Uso: pacwin info <nombre>" Yellow; return }
            if (-not (_pw_assert_managers $managers)) { return }
            _pw_header
            _pw_color "  Info: $Query" Cyan
            _pw_color ""
            if ($managers["winget"]) {
                _pw_color "  ── winget ──────────────────────────────" Cyan
                winget show $Query 2>$null
            }
            if ($managers["choco"]) {
                _pw_color "  ── chocolatey ──────────────────────────" Yellow
                choco info $Query 2>$null
            }
        }


        # ── STATUS ───────────────────────────────────────────
        "status" {
            _pw_header
            _pw_color "  Gestores detectados en este sistema:" Cyan
            _pw_color ""
            $all_mgr = @("winget","choco","scoop")
            foreach ($m in $all_mgr) {
                if ($managers[$m]) {
                    _pw_color "  ✓ " Green -NoNewline
                    _pw_color ("{0,-10}" -f $m) Green -NoNewline
                    _pw_color $managers[$m] DarkGray
                } else {
                    _pw_color "  ✗ " DarkGray -NoNewline
                    _pw_color $m DarkGray
                }
            }
            _pw_color ""
            _pw_color "  PowerShell: $($PSVersionTable.PSVersion)" DarkGray
        }

        # ── HELP ─────────────────────────────────────────────
        default {
            _pw_header
            _pw_color "  Comandos:" Cyan
            _pw_color ""
            _pw_color "    pacwin search   <nombre>         Busca en gestores activos" White
            _pw_color "    pacwin install  <nombre>         Busca, lista y deja elegir + fuente" White
            _pw_color "    pacwin uninstall <nombre>        Desinstala" White
            _pw_color "    pacwin update   [nombre]         Actualiza todo o un paquete" White
            _pw_color "    pacwin outdated                  Lista paquetes con updates disponibles" White
            _pw_color "    pacwin list     [filtro]         Lista instalados" White
            _pw_color "    pacwin info     <nombre>         Detalles del paquete" White
            _pw_color "    pacwin status                    Gestores disponibles + rutas" White
            _pw_color ""
            _pw_color "  Flags:" DarkGray
            _pw_color "    -Manager  winget|choco|scoop     Restringe a un gestor específico" DarkGray
            _pw_color "    -Limit    N                      Máximo de resultados (default 40)" DarkGray
            _pw_color ""
            _pw_color "  Ejemplos:" DarkGray
            _pw_color "    pacwin search vlc" DarkGray
            _pw_color "    pacwin install node" DarkGray
            _pw_color "    pacwin install node -Manager scoop" DarkGray
            _pw_color "    pacwin update -Manager choco" DarkGray
            _pw_color "    pacwin outdated" DarkGray
            _pw_color "    pacwin list reaper" DarkGray
            _pw_color "    pacwin search ffmpeg -Limit 10" DarkGray
            _pw_color ""
        }
    }
}

Export-ModuleMember -Function pacwin
