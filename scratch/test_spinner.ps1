$spinner = "|/-\"
$spinIdx = 0
$tasks = @(
    @{ Key = "winget"; Finished = $false },
    @{ Key = "choco"; Finished = $false },
    @{ Key = "scoop"; Finished = $false }
)

Write-Host "Testing Pacwin Spinner UX..."
$startTime = Get-Date

for ($i = 0; $i -lt 50; $i++) {
    # Simulate some tasks finishing
    if ($i -eq 15) { $tasks[0].Finished = $true }
    if ($i -eq 30) { $tasks[1].Finished = $true }
    if ($i -eq 45) { $tasks[2].Finished = $true }

    Write-Host -NoNewline "`r    "
    foreach ($t in $tasks) {
        if ($t.Finished) {
            Write-Host -NoNewline "[" -ForegroundColor DarkGray
            Write-Host -NoNewline "√" -ForegroundColor Green
            Write-Host -NoNewline "] $($t.Key)  " -ForegroundColor DarkGray
        } else {
            Write-Host -NoNewline "[" -ForegroundColor DarkGray
            Write-Host -NoNewline $spinner[$spinIdx % 4] -ForegroundColor Yellow
            Write-Host -NoNewline "] $($t.Key)  " -ForegroundColor DarkGray
        }
    }
    
    Start-Sleep -Milliseconds 100
    $spinIdx++
}
Write-Host "`nDone."
