# Installation Guide

**Updated:** 2026-04-17 | **Read time:** 2 min | **Difficulty:** Beginner

## Prerequisites

- **OS:** Windows 10 or Windows 11.
- **Engine:** PowerShell 5.1 or PowerShell 7.2+.
- **Privileges:** **Administrator privileges** are required for Chocolatey and system-wide Winget operations.
- **Managers:** At least one of `winget`, `choco`, or `scoop` installed and available in `$env:PATH`.

## Installation Methods

### Method 1: PowerShell Gallery (Recommended)

The most professional and easiest way to install `pacwin`:

```pwsh
PS> Install-Module -Name pacwin -Scope CurrentUser
```

### Method 2: Automated Script

You can deploy `pacwin` directly from the remote repository using `curl`. This script will download the module and update your `$PROFILE` automatically.

```pwsh
PS> curl -sSL https://raw.githubusercontent.com/julesklord/pacwin/main/get-pacwin.ps1 | powershell -Command -
```

### Method 3: Manual Clone (for developers)

```pwsh
PS> git clone https://github.com/julesklord/pacwin.git
PS> cd pacwin
PS> .\install.ps1
```

## Setup Verification

After installation, restart your PowerShell session or dot-source your profile. Verify the installation by running the status check:

```pwsh
PS> pacwin doctor
  >> pacwin v0.2.4  --  universal package layer
  [ winget + | choco + | scoop + ]
  ===============================================================================
  Detected Managers:
  * winget -> C:\Users\user\AppData\Local\Microsoft\WindowsApps\winget.exe
  * choco -> C:\ProgramData\chocolatey\bin\choco.exe
  * scoop -> C:\Users\user\scoop\shims\scoop.ps1

You should also run the health check:

```pwsh
PS> pacwin doctor
```

```pwsh

> [!WARNING]
> If a manager is installed but not listed, check your `$env:PATH` environment variable. `pacwin` relies on `Get-Command` to detect them.

## Troubleshooting Installation

**Symptom:** `pacwin : The term 'pacwin' is not recognized...`

- **Fix:** Your `$PROFILE` might not have loaded the module. Open your profile (`notepad $PROFILE`) and ensure `Import-Module <path>\pacwin.psm1` exists. Make sure your Execution Policy allows running scripts (`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`).

---
**Next:** [Command Reference](03-COMMAND_REFERENCE.md)
