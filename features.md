# pacwin — Feature Roadmap & Implementation Guide

Cada feature incluye el código PowerShell completo listo para integrar en `pacwin.psm1`
y la entrada correspondiente en el switch de `pacwin`.

---

## Feature 1: `pacwin pin` / `pacwin hold`

**Problema que resuelve:** Freezar un paquete para que `update --all` lo ignore.
Winget tiene `pin`, choco tiene `pin`, scoop tiene `hold`. Los tres son distintos.

### Implementación

```powershell
#region -- Pin / Hold ---------------------------------------

function _pw_do_pin {
    param([string]$id, [string]$mgr, [switch]$Unpin)

    $action = if ($Unpin) { "Unpinning" } else { "Pinning" }
    _pw_color "  -> $action '$id' with $mgr ..." Cyan
    _pw_sep

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
        # Scoop no tiene comando de lista de held; lee el JSON directamente
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
```

### Entrada en el switch de `pacwin`

```powershell
"^(pin|hold)$" {
    if (-not $Query) {
        # Sin query: listar todos los pineados
        _pw_do_pin_list $targetManagers
        return
    }
    if (-not $Manager) {
        _pw_color "  [!] Especifica un manager con -Manager (winget|choco|scoop)" Yellow
        return
    }
    _pw_do_pin $Query $Manager
}

"^(unpin|unhold|-Sp)$" {
    if (-not $Query -or -not $Manager) {
        _pw_color "  [!] Requiere -Query y -Manager." Yellow; return
    }
    _pw_do_pin $Query $Manager -Unpin
}
```

### Uso

```powershell
pacwin pin vlc -Manager choco          # freezar
pacwin unpin vlc -Manager choco        # liberar
pacwin pin                             # listar todos los pineados
```

---

## Feature 2: `pacwin export` / `pacwin import`

**Problema que resuelve:** Backup de todo lo instalado como script reproducible.
Útil para reinstalar Windows, setups de máquinas nuevas, onboarding de equipo.

### Implementación

```powershell
#region -- Export / Import ----------------------------------

function _pw_do_export {
    param($managers, [string]$outPath)

    if (-not $outPath) {
        $outPath = Join-Path $HOME "pacwin-export-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
    }

    _pw_color "  Collecting installed packages..." Cyan
    $export = [ordered]@{ generated = (Get-Date -Format 'o'); packages = @() }

    if ($managers["winget"]) {
        $raw = winget export - 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($raw.Sources) {
            foreach ($src in $raw.Sources) {
                foreach ($pkg in $src.Packages) {
                    $export.packages += [ordered]@{
                        manager = "winget"; id = $pkg.PackageIdentifier
                    }
                }
            }
        }
    }
    if ($managers["choco"]) {
        $raw = choco list --local-only --limit-output 2>$null
        foreach ($line in $raw) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 1 -and $parts[0].Trim()) {
                $export.packages += [ordered]@{
                    manager = "choco"; id = $parts[0].Trim()
                }
            }
        }
    }
    if ($managers["scoop"]) {
        $raw = scoop export 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($raw.apps) {
            foreach ($app in $raw.apps) {
                $export.packages += [ordered]@{
                    manager = "scoop"; id = $app.Name
                }
            }
        }
    }

    $export | ConvertTo-Json -Depth 5 | Out-File $outPath -Encoding UTF8
    _pw_color "  [OK] Exported $($export.packages.Count) packages to:" Green
    _pw_color "       $outPath" DarkGray
}

function _pw_do_import {
    param($managers, [string]$inPath)

    if (-not $inPath -or -not (Test-Path $inPath)) {
        _pw_color "  [!] File not found: '$inPath'" Red; return
    }

    $data = Get-Content $inPath -Raw | ConvertFrom-Json -ErrorAction Stop
    _pw_color "  Importing $($data.packages.Count) packages from export..." Cyan
    _pw_sep

    $failed = @()
    foreach ($pkg in $data.packages) {
        if (-not $managers[$pkg.manager]) {
            _pw_color "  [SKIP] $($pkg.id) — manager '$($pkg.manager)' not available." DarkGray
            continue
        }
        _pw_color "  -> $($pkg.manager): $($pkg.id)" Cyan
        $output = @()
        switch ($pkg.manager) {
            "winget" { $output = winget install --id $pkg.id --accept-package-agreements --accept-source-agreements 2>&1 }
            "choco"  { $output = choco install $pkg.id -y 2>&1 }
            "scoop"  { $output = scoop install $pkg.id 2>&1 }
        }
        if ($LASTEXITCODE -ne 0) { $failed += $pkg.id }
    }

    _pw_sep
    if ($failed.Count -eq 0) {
        _pw_color "  [OK] All packages installed successfully." Green
    } else {
        _pw_color "  [!] Failed: $($failed -join ', ')" Red
    }
}

#endregion
```

### Entrada en el switch

```powershell
"^(export)$" {
    _pw_do_export $targetManagers $Query   # $Query puede ser path de salida
}

"^(import)$" {
    if (-not $Query) { _pw_color "  [!] Especifica la ruta del archivo de export." Yellow; return }
    _pw_do_import $targetManagers $Query
}
```

### Uso

```powershell
pacwin export                                      # guarda en $HOME con timestamp
pacwin export C:\backup\pkgs.json                  # ruta custom
pacwin import C:\backup\pkgs.json                  # restaurar
```

---

## Feature 3: `pacwin doctor`

**Problema que resuelve:** Diagnosticar el entorno antes de culpar a pacwin.
Verifica versiones, conectividad, buckets de scoop stale, y permisos.

### Implementación

```powershell
#region -- Doctor -------------------------------------------

function _pw_do_doctor {
    param($managers)

    _pw_color "  Running diagnostics..." Cyan
    _pw_sep
    $issues = 0

    # PowerShell version
    $psv = $PSVersionTable.PSVersion
    _pw_color ("  PS Version   : {0}" -f $psv) $(if ($psv.Major -ge 5) { "Green" } else { "Red" })
    if ($psv.Major -lt 5) { _pw_color "  [!] PowerShell 5.1+ required." Red; $issues++ }

    # Manager presence & version
    foreach ($mgr in @("winget","choco","scoop")) {
        $exe = _pw_exe $mgr
        if ($exe) {
            $ver = switch ($mgr) {
                "winget" { (winget --version 2>$null) -replace "[^\d\.]","" }
                "choco"  { (choco --version 2>$null) }
                "scoop"  { (scoop --version 2>$null) | Select-Object -First 1 }
            }
            _pw_color ("  {0,-12} : OK  {1}" -f $mgr, $ver) Green
        } else {
            _pw_color ("  {0,-12} : NOT FOUND" -f $mgr) DarkGray
        }
    }

    # Connectivity check (fast ping to winget source)
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
```

### Entrada en el switch

```powershell
"^(doctor|check)$" {
    _pw_do_doctor $targetManagers
}
```

### Uso

```powershell
pacwin doctor
```

---

## Feature 4: Tab Completion

**Problema que resuelve:** Sin autocompletar, pacwin se siente como cualquier script random.
Con `Register-ArgumentCompleter`, el usuario presiona Tab y ve comandos, managers y paquetes.

### Implementación

Agregar al **final de `pacwin.psm1`**, fuera de cualquier region:

```powershell
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
    # Intenta completar con winget list (rápido)
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
```

### Uso

```powershell
pacwin <Tab>              # → search, install, uninstall, update...
pacwin install <Tab>      # → IDs de paquetes instalados (para update/uninstall)
pacwin search <Tab> -Manager <Tab>   # → winget, choco, scoop
```

---

## Feature 5: `pacwin sync`

**Problema que resuelve:** Detectar paquetes duplicados entre managers
(ej: VLC instalado por winget Y por choco) y recomendar limpiar.

### Implementación

```powershell
#region -- Sync (duplicate detection) ----------------------

function _pw_do_sync {
    param($managers)

    _pw_color "  Scanning for cross-manager duplicates..." Cyan
    _pw_sep

    $installed = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($managers["winget"]) {
        $raw = winget list 2>$null
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
                    Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                    Source = "chocolatey"; Manager = "choco"
                })
            }
        }
    }
    if ($managers["scoop"]) {
        $raw = scoop list 2>$null
        foreach ($line in $raw) {
            $parts = ($line.Trim() -split "\s{2,}").Where({ $_ -ne "" })
            if ($parts.Count -ge 1 -and $parts[0] -notmatch "^Name$|^Installed") {
                $installed.Add([PSCustomObject]@{
                    Name = $parts[0]; ID = $parts[0]
                    Version = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
                    Source = "scoop"; Manager = "scoop"
                })
            }
        }
    }

    # Agrupar por nombre normalizado (lowercase, sin guiones)
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
            $col = $script:SRC_COLORS[$pkg.Source] ?? "White"
            _pw_color ("    [{0}] v{1}" -f $pkg.Source, $pkg.Version) $col
        }
        _pw_color "  Suggestion: keep one, run 'pacwin uninstall <id> -Manager <mgr>'" DarkGray
        _pw_color ""
    }
}

#endregion
```

### Entrada en el switch

```powershell
"^(sync|dupes|dedup)$" {
    _pw_do_sync $targetManagers
}
```

### Uso

```powershell
pacwin sync
# Output:
#   Package: VLC
#     [winget] v3.0.21
#     [chocolatey] v3.0.21
#   Suggestion: keep one, run 'pacwin uninstall VideoLAN.VLC -Manager winget'
```

---

## Feature 6: `-WhatIf` para operaciones destructivas

**Problema que resuelve:** Convención PowerShell estándar que la gente espera.
`-WhatIf` debe mostrar qué haría el comando SIN ejecutarlo.

### Implementación

Agregar `-WhatIf` al param block de `pacwin` y propagarlo a las funciones de operación:

```powershell
# En el param() de la función pacwin, agregar:
[Parameter()]
[switch]$WhatIf
```

Modificar `_pw_do_install`, `_pw_do_uninstall`, `_pw_do_update_single` y `_pw_do_update_all`
para aceptar y respetar el flag:

```powershell
function _pw_do_install {
    param([PSCustomObject]$pkg, [switch]$WhatIf)

    _pw_color "  -> Installing: $($pkg.Name)  [$($pkg.Source)  v$($pkg.Version)]" Cyan
    _pw_sep

    if ($WhatIf) {
        _pw_color "  [WhatIf] Would run: " Yellow -NoNewline
        switch ($pkg.Manager) {
            "winget" { _pw_color "winget install --id $($pkg.ID) --accept-package-agreements" White }
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
```

Y en el switch dispatch, pasar el flag:

```powershell
"^(install|-S)$" {
    ...
    if ($pkg) { _pw_do_install $pkg -WhatIf:$WhatIf }
}

"^(uninstall|-R)$" {
    ...
    _pw_do_uninstall $Query $Manager -WhatIf:$WhatIf
}

"^(update|upgrade|-Syu)$" {
    ...
    _pw_do_update_single $matches[0].ID $matches[0].Manager -WhatIf:$WhatIf
}
```

### Uso

```powershell
pacwin install vlc -WhatIf
# [WhatIf] Would run: winget install --id VideoLAN.VLC --accept-package-agreements

pacwin update -WhatIf
# [WhatIf] Would run: winget upgrade --all ...
# [WhatIf] Would run: choco upgrade all -y
```

---

## Resumen de prioridades

| Feature | Impacto | Esfuerzo | Prioridad |
|---------|---------|----------|-----------|
| `-WhatIf` | Alto — expectativa de PS estándar | Bajo | 🔴 Inmediato |
| Tab completion | Alto — usabilidad | Bajo | 🔴 Inmediato |
| `pin / hold` | Alto — caso de uso frecuente | Medio | 🟡 v0.2.0 |
| `export / import` | Alto — onboarding | Medio | 🟡 v0.2.0 |
| `doctor` | Medio — debugging | Medio | 🟡 v0.2.0 |
| `sync` | Medio — nicho pero útil | Alto | 🟢 v0.3.0 |
