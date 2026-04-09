# pacwin Installer - Simple & Fast
$moduleName = "pacwin"
$psm1Source = Join-Path $PSScriptRoot "pacwin.psm1"

if (-not (Test-Path $psm1Source)) {
    Write-Error "pacwin.psm1 not found in $PSScriptRoot"
    exit 1
}

# Determine Module Path (PowerShell 7 vs 5.1)
$destDir = if ($PSVersionTable.PSVersion.Major -ge 7) {
    Join-Path $HOME "Documents\PowerShell\Modules\$moduleName"
} else {
    Join-Path $HOME "Documents\WindowsPowerShell\Modules\$moduleName"
}

Write-Host "Installing pacwin to: $destDir" -ForegroundColor Cyan

if (-not (Test-Path $destDir)) { New-Object -ItemType Directory -Path $destDir -Force | Out-Null }
Copy-Item $psm1Source (Join-Path $destDir "pacwin.psm1") -Force

# Register in Current Profile
$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Object -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "Created new profile at: $profilePath" -ForegroundColor Gray
}

$importCmd = "Import-Module $moduleName"
$profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue
if ($profileContent -notcontains $importCmd) {
    Add-Content $profilePath "`n# pacwin - Universal Package Layer`n$importCmd"
    Write-Host "Added 'Import-Module $moduleName' to your profile." -ForegroundColor Green
} else {
    Write-Host "pacwin is already registered in your profile." -ForegroundColor Yellow
}

Write-Host "`nInstallation Complete! Restart your shell or run: . `$PROFILE" -ForegroundColor Cyan
