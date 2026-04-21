# pacwin Remote Installer
# Usage: curl -sSL <URL_TO_THIS_SCRIPT> | powershell -Command -

# --- CONFIGURATION (Change this to your actual repository URL) ---
$repoBaseUrl = "https://raw.githubusercontent.com/julesklord/pacwin/main"
$moduleName = "pacwin"
$psm1Url = "$repoBaseUrl/pacwin.psm1"

Write-Host "--- pacwin Automated Installer ---" -ForegroundColor Cyan

# Determine Base Documents Path (Handles redirected folders like F:\Documents)
$docsPath = [Environment]::GetFolderPath("MyDocuments")

# Determine Module Paths (Register in both for compatibility)
$destDirs = @(
    (Join-Path $docsPath "WindowsPowerShell\Modules\$moduleName"),
    (Join-Path $docsPath "PowerShell\Modules\$moduleName")
)

foreach ($destDir in $destDirs) {
    if (-not (Test-Path (Split-Path $destDir))) { continue } # Skip if shell base dir doesn't exist

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $destFile = Join-Path $destDir "pacwin.psm1"

    Write-Host "Downloading module to: $destDir" -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $psm1Url -OutFile $destFile -ErrorAction Stop
    } catch {
        Write-Error "Failed to download $psm1Url to $destDir."
    }
}

# Register in all detected profiles (PS 5.1 and PS 7+)
$potentialProfiles = @(
    $PROFILE, # Current shell
    (Join-Path $docsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $docsPath "PowerShell\Microsoft.PowerShell_profile.ps1")
) | Select-Object -Unique

foreach ($pPath in $potentialProfiles) {
    if (-not (Test-Path (Split-Path $pPath))) { continue } # Skip if parent dir doesn't exist

    if (-not (Test-Path $pPath)) {
        New-Item -ItemType File -Path $pPath -Force | Out-Null
        Write-Host "Created new profile at: $pPath" -ForegroundColor Gray
    }

    $importCmd = "Import-Module $moduleName"
    $profileContent = Get-Content $pPath -ErrorAction SilentlyContinue
    if ($profileContent -notcontains $importCmd) {
        Add-Content $pPath "`n# pacwin - Universal Package Layer`n$importCmd"
        Write-Host "Registered pacwin in: $pPath" -ForegroundColor Green
    }
}

Write-Host "`n[SUCCESS] pacwin has been installed!" -ForegroundColor Cyan
Write-Host "Restart your terminal or run: . `$PROFILE" -ForegroundColor Gray
