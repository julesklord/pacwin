# VHS tape for pacwin demo (Dynamic Version)
# Generate with: Get-Content demo.tape | vhs

Output docs/demo.gif

Set Shell powershell
Set FontSize 20
Set Width 1200
Set Height 600
Set Padding 20
Set Theme "Catppuccin Mocha"

# Initial Setup
Hide
Type "Import-Module ./pacwin.psm1 -Force"
Enter
Type "Clear-Host"
Enter
Show

# 1. Main Help
Type "pacwin"
Enter
Sleep 1.5s

# 2. Status Dashboard (Instant)
Type "pacwin status"
Enter
Sleep 1s

# 3. Parallel Search (Simulated instant results)
Type "pacwin search fastfetch"
Enter
Hide
Sleep 4s
Show
Sleep 2s

# 4. Detailed Info
Type "pacwin info fastfetch"
Enter
Hide
Sleep 2s
Show
Sleep 1.5s

# 5. Maintenance check
Type "pacwin doctor"
Enter
Hide
Sleep 1.5s
Show
Sleep 1.5s

# 6. Outdated & Sync
Type "pacwin outdated"
Enter
Hide
Sleep 3s
Show
Sleep 1s

Type "pacwin sync"
Enter
Hide
Sleep 2s
Show
Sleep 1s

# 7. Scriptability (-NoHeader)
Type "pacwin list fast -NoHeader"
Enter
Sleep 1.5s

# Final message
Type "# pacwin: unified, fast, elegant."
Sleep 1s
Enter
Sleep 1s
