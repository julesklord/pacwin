# Installation Guide

**Updated:** 2026-04-10 | **Read time:** 2 min | **Difficulty:** Beginner

## Prerequisites

- **OS:** Windows 10 or Windows 11.
- **Engine:** PowerShell 5.1 or PowerShell 7.2+.
- **Managers:** At least one of `winget`, `choco`, or `scoop` installed and available in `$env:PATH`.

## Installation Methods

### Method 1: Automated Script (Recommended)

You can deploy `pacwin` directly from the remote repository using `curl`. This script will download the module and update your `$PROFILE` automatically.

```powershell
PS> curl -sSL https://raw.githubusercontent.com/julesklord/pacwin/main/get-pacwin.ps1 | powershell -Command -
```

### Method 2: Manual Clone

If you prefer to review the code or want to contribute:

```powershell
PS> git clone https://github.com/julesklord/pacwin.git
PS> cd pacwin
PS> .\install.ps1
```

## Setup Verification

After installation, restart your PowerShell session or dot-source your profile. Verify the installation by running the status check:

```powershell
PS> pacwin status
  +--------------------------------------+
  |   pacwin  -  universal pkg layer     |
  +--------------------------------------+
  Detected Managers:
  * winget -> C:\Users\user\AppData\Local\Microsoft\WindowsApps\winget.exe
  * choco -> C:\ProgramData\chocolatey\bin\choco.exe
  * scoop -> C:\Users\user\scoop\shims\scoop.ps1
```

> [!WARNING]
> If a manager is installed but not listed, check your `$env:PATH` environment variable. `pacwin` relies on `Get-Command` to detect them.

## Troubleshooting Installation

**Symptom:** `pacwin : The term 'pacwin' is not recognized...`

- **Fix:** Your `$PROFILE` might not have loaded the module. Open your profile (`notepad $PROFILE`) and ensure `Import-Module <path>\pacwin.psm1` exists. Make sure your Execution Policy allows running scripts (`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`).

---
**Next:** [Command Reference](03-COMMAND_REFERENCE.md)
