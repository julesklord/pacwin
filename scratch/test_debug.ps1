$pesterPath = Join-Path (Get-Location) "tests\modules\Pester"
Import-Module $pesterPath -Force

$config = [PesterConfiguration]::Default
$config.Run.Path = "./tests/pacwin.Tests.ps1"
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config
$result.Tests | ForEach-Object {
    Write-Host "Test: $($_.ExpandedName) - Status: $($_.Result)"
    if ($_.Result -eq 'Failed') {
        Write-Host "Error: $($_.ErrorRecord)" -ForegroundColor Red
    }
}
