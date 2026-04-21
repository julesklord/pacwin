# VHS Tape for Pacwin v0.2.5
# Run with: vhs demo.tape -o docs/demo.gif

Set Shell powershell
Set FontSize 22
Set Width 1300
Set Height 800
Set Padding 30
Set WindowBar "Colorful"
Set Theme "Tomorrow Night"
Set TypingSpeed 40ms

# Initialize
Hide
Type "Import-Module ./pacwin.psm1; Clear-Host"
Enter
Show

# 1. Version check
Type "pacwin version"
Sleep 500ms
Enter
Sleep 2s

# 2. Show Help
Type "pacwin help"
Sleep 500ms
Enter
Sleep 4s

# 3. Search and Dynamic Layout
Type "pacwin search jq"
Sleep 500ms
Enter
Sleep 6s

# 4. Install (Lightweight)
Type "pacwin install jq"
Sleep 500ms
Enter
Sleep 8s

# Final tip
Type "# pacwin: The ultimate Windows package manager."
Sleep 2s
Enter

Sleep 2s
