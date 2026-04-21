# pacwin Installer - Simple & Fast
$moduleName = "pacwin"
$psm1Source = Join-Path $PSScriptRoot "pacwin.psm1"

if (-not (Test-Path $psm1Source)) {
    Write-Error "pacwin.psm1 not found in $PSScriptRoot"
    exit 1
}

# Determine Base Documents Path (Handles redirected folders like F:\Documents)
$docsPath = [Environment]::GetFolderPath("MyDocuments")

# Determine Module Paths (Register in both for compatibility)
$destDirs = @(
    (Join-Path $docsPath "WindowsPowerShell\Modules\$moduleName"),
    (Join-Path $docsPath "PowerShell\Modules\$moduleName")
)

foreach ($destDir in $destDirs) {
    if (-not (Test-Path (Split-Path $destDir))) { continue } # Skip if shell base dir doesn't exist

    Write-Host "Installing pacwin to: $destDir" -ForegroundColor Cyan
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $psm1Source (Join-Path $destDir "pacwin.psm1") -Force
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
        Write-Host "Added 'Import-Module $moduleName' to profile: $pPath" -ForegroundColor Green
    } else {
        Write-Host "pacwin is already registered in: $pPath" -ForegroundColor Yellow
    }
}

Write-Host "`nInstallation Complete! Restart your shell or run: . `$PROFILE" -ForegroundColor Cyan
