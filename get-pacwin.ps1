# pacwin Remote Installer
# Usage: curl -sSL <URL_TO_THIS_SCRIPT> | powershell -Command -

# --- CONFIGURATION (Change this to your actual repository URL) ---
$repoBaseUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/pacwin/main"
$moduleName = "pacwin"
$psm1Url = "$repoBaseUrl/pacwin.psm1"

Write-Host "--- pacwin Automated Installer ---" -ForegroundColor Cyan

# Determine Module Path
$destDir = if ($PSVersionTable.PSVersion.Major -ge 7) {
    Join-Path $HOME "Documents\PowerShell\Modules\$moduleName"
} else {
    Join-Path $HOME "Documents\WindowsPowerShell\Modules\$moduleName"
}

if (-not (Test-Path $destDir)) { 
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null 
}

$destFile = Join-Path $destDir "pacwin.psm1"

Write-Host "Downloading module from: $psm1Url" -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $psm1Url -OutFile $destFile -ErrorAction Stop
} catch {
    Write-Error "Failed to download $psm1Url. Check the URL and your connection."
    exit 1
}

# Register in Profile
$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$importCmd = "Import-Module $moduleName"
$profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue
if ($profileContent -notcontains $importCmd) {
    Add-Content $profilePath "`n# pacwin - Universal Package Layer`n$importCmd"
    Write-Host "Registered pacwin in: $profilePath" -ForegroundColor Green
}

Write-Host "`n[SUCCESS] pacwin has been installed!" -ForegroundColor Cyan
Write-Host "Restart your terminal or run: . `$PROFILE" -ForegroundColor Gray
