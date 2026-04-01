# ============================================================
#  install.ps1  —  Instalador de pacwin
#  Copia el módulo al directorio de módulos del usuario y
#  agrega la función al perfil de PowerShell si hace falta.
# ============================================================

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-OK    { param([string]$msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail  { param([string]$msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  ╔════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   pacwin installer                 ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── 1. Destino del módulo ────────────────────────────────────
$modulePath = "$HOME\Documents\PowerShell\Modules\pacwin"
if ($PSVersionTable.PSEdition -eq "Desktop") {
    $modulePath = "$HOME\Documents\WindowsPowerShell\Modules\pacwin"
}

Write-Step "Creando directorio del módulo: $modulePath"
New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
Write-OK "Directorio listo"

# ── 2. Copiar módulo ─────────────────────────────────────────
$source = Join-Path $PSScriptRoot "pacwin.psm1"
if (-not (Test-Path $source)) {
    Write-Fail "No se encontró pacwin.psm1 en $PSScriptRoot"
    exit 1
}

Write-Step "Copiando pacwin.psm1..."
Copy-Item $source -Destination "$modulePath\pacwin.psm1" -Force

# Crear manifest mínimo
$manifest = @"
@{
    ModuleVersion = '1.0.0'
    RootModule    = 'pacwin.psm1'
    Author        = 'pacwin'
    Description   = 'Universal package layer for Windows (winget + choco + scoop)'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('pacwin')
}
"@
$manifest | Set-Content "$modulePath\pacwin.psd1" -Encoding UTF8
Write-OK "Módulo copiado"

# ── 3. Verificar auto-import en perfil ───────────────────────
Write-Step "Verificando perfil de PowerShell..."

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
    Write-OK "Perfil creado: $PROFILE"
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
$importLine = "Import-Module pacwin"

if ($profileContent -notmatch "Import-Module pacwin") {
    Add-Content $PROFILE "`n# pacwin — universal package layer`n$importLine"
    Write-OK "Import-Module pacwin agregado al perfil"
} else {
    Write-OK "Import-Module ya estaba en el perfil"
}

# ── 4. Verificar módulo en sesión actual ─────────────────────
Write-Step "Cargando módulo en sesión actual..."
try {
    Import-Module pacwin -Force
    Write-OK "Módulo cargado. Ya puedes usar: pacwin help"
} catch {
    Write-Host "  ! El módulo se instaló pero no se pudo cargar en esta sesión." -ForegroundColor Yellow
    Write-Host "    Reinicia PowerShell y ejecuta: pacwin help" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Instalación completa." -ForegroundColor Green
Write-Host "  Prueba con: pacwin status" -ForegroundColor DarkGray
Write-Host ""
