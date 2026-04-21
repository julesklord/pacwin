# pacwin

<!-- markdownlint-disable MD033 -->
<p align="center">
  <img src="docs/logo_pacwin.png" width="800" alt="pacwin logo">
</p>
<!-- markdownlint-enable MD033 -->

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/pacwin.svg?color=blue&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/pacwin)
[![Downloads](https://img.shields.io/powershellgallery/dt/pacwin.svg?color=blue&label=Downloads)](https://www.powershellgallery.com/packages/pacwin)
![PowerShell](https://img.shields.io/badge/powershell-5.1%20%7C%207%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-blue)

Unify winget, chocolatey, and scoop under a fast, secure, pacman-like CLI for Windows.

- **🚀 Concurrent Performance**: Multi-threaded engine for snappy package operations.
- **✨ Rich Terminal based UI**: Real-time status indicators and polished ASCII dashboard.
- **🤖 Scripting Ready**: Silent modes and header suppression (`-NoHeader`) for CI/CD.
- **🛡️ Intelligent Parsing**: Precise conflict resolution and exit-code interpretation.

![pacwin demo](docs/demo.gif)

## Why it exists

Managing software on Windows typically requires interacting with three distinct tools (winget, choco, scoop), each with its own syntax, output formats, and silent failure modes. Existing solutions often lack a unified search across all managers or introduce significant performance overhead by spawning multiple heavy PowerShell processes.

`pacwin` solves this by:

- Providing a **single point of entry** for searching and installing packages.
- Interpreting **cryptic exit codes** (like 3010 or 0x8A15002E) into clear status messages.
- Using a **Hybrid Engine** (Runspaces/Threads) to execute searches in parallel without spiking CPU usage.

## Quick start and Installation

### Method 1: PowerShell Gallery (Recommended)

The easiest way to install `pacwin` is directly from the [PowerShell Gallery](https://www.powershellgallery.com/packages/pacwin):

```powershell
Install-Module -Name pacwin -Scope CurrentUser
```

### Method 2: Automated Install (via curl)

If you want an all-in-one setup that also updates your `$PROFILE`:

```powershell
curl -sSL https://raw.githubusercontent.com/julesklord/pacwin/main/get-pacwin.ps1 | powershell -Command -
```

### Method 3: Manual Install (from source)

1. Open PowerShell (**Run as Administrator** - recommended for Chocolatey).
2. Clone and run the installer:

   ```powershell
   git clone https://github.com/julesklord/pacwin.git
   cd pacwin
   .\install.ps1
   ```

3. Restart your terminal and search for a package:

   ```powershell
   pacwin search vlc
   ```

**Expected Output:**

```text
  #    Name           ID               Version    Source
  -----------------------------------------------------------
  [1 ] vlc            vlc              3.0.21     chocolatey
  [2 ] VideoLAN.VLC   VideoLAN.VLC     3.0.21     winget
```

## Core Features

- **Parallel Search**: Aggregates results from all detected managers simultaneously.
- **Smart Result Picker**: Interactive source selection when a package exists in multiple repositories.
- **Error Interpretation**: Real-time analysis of installer output to detect reboots or missing manifests.
- **Security Sanitization**: Regex-based input validation to block command injection.
- **Support for `-WhatIf`**: Native PowerShell integration to simulate operations before execution.
- **Low-Resource Engine**: Automatically switches to thread-based execution (Runspaces) in PS 5.1 and Parallel loops in PS 7.

## Installation

### Dependencies

- **Windows 10/11**
- **PowerShell 5.1** or **PowerShell 7+**
- (Optional) `winget`, `choco`, or `scoop` (at least one must be in your PATH).

## Usage

### Common Commands

| Task               | Command                 | Pacman Flag          |
| :----------------- | :---------------------- | :------------------- |
| **Search**         | `pacwin search <query>` | `pacwin -Ss <query>` |
| **Install**        | `pacwin install <id>`   | `pacwin -S <id>`     |
| **Uninstall**      | `pacwin uninstall <id>` | `pacwin -R <id>`     |
| **Update**         | `pacwin update [id]`    | `pacwin -Syu`        |
| **List Installed** | `pacwin list`           | `pacwin -Q`          |
| **Check Outdated** | `pacwin outdated`       | `pacwin -Qu`         |
| **Hold (Pin)**     | `pacwin hold <id>`      | `pacwin pin <id>`    |
| **Health Check**   | `pacwin doctor`         | `pacwin check`       |
| **Deduplicate**    | `pacwin sync`           | `pacwin dupes`       |
| **Self-Update**    | `pacwin self-update`    | `pacwin update-self` |

### Identifying Sources

If you want to force a search or install using a specific manager:

```powershell
pacwin search nodejs -Manager scoop
```

### Advanced Usage

- **Search Timeout**: Control the maximum wait time for parallel searches.

  ```powershell
  pacwin search git -Timeout 45
  ```

- **Quiet Mode**: Suppress the banner for scripting.

  ```powershell
  pacwin search python -NoHeader
  ```

## Architecture & Design Philosophy

`pacwin` is built as a **Script Module (.psm1)** for zero-installation overhead.

**Runspaces over Jobs**: The primary design goal was to avoid the high CPU usage of `Start-Job`. In PowerShell 5.1, `pacwin` uses a `RunspacePool` to execute CLI calls in background threads within the same process. This reduces startup time for searches by up to 3 seconds compared to traditional background jobs.

## Contributing

1. **Reporting Issues**: Use the GitHub issue tracker.
2. **Testing**: Run the test suite using the bundled Pester 5 engine:

   ```powershell
   # Use the local Pester module to avoid version conflicts
   Import-Module ./tests/modules/Pester
   Invoke-Pester ./tests/pacwin.Tests.ps1
   ```

3. **Internal Functions**: All core logic resides in `_pw_` prefixed functions to avoid polluting your global namespace.

## License

MIT License. See [LICENSE](LICENSE) for details.

---

### Metadata

- **Status**: Stable (v0.2.5)
- **Requirements**: Windows PowerShell 5.1 or PS 7.2+
- **Maintainers**: julesklord
- **Known issues**: Scoop searches can timeout if bucket metadata is stale; run `scoop update` to fix.
