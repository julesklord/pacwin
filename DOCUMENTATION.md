# pacwin Technical Documentation

A high-performance universal package management layer for Windows.

## Table of Contents

1. [Overview](#1-overview)
2. [Core Concepts](#2-core-concepts)
3. [Architecture](#3-architecture)
4. [API & Command Interface](#4-api--command-interface)
5. [Error Interpretation System](#5-error-interpretation-system)
6. [Examples & Use Cases](#6-examples--use-cases)
7. [Troubleshooting](#7-troubleshooting)
8. [Maintenance & Dependencies](#8-maintenance--dependencies)

---

## 1. Overview

`pacwin` is a PowerShell-based abstraction layer designed for system administrators and power users who need to manage multiple Windows package managers (**winget**, **chocolatey**, **scoop**) through a single, consistent CLI. It adopts the Arch Linux `pacman` syntax to provide a streamlined, predictable experience while solving common issues like asynchronous output noise and cryptic exit codes.

## 2. Core Concepts

- **Manager Abstraction**: Code that wraps specific CLI tools into generic objects.
- **Hybrid Search Engine**: A version-aware engine that switches between multi-process (Jobs) and multi-threaded (Runspaces) execution.
- **Source Picking**: The logic used to resolve conflicts when a search query returns matches across multiple managers.
- **Sanitization Layer**: A regex-based security gate that validates all user inputs before passing them to the underlying shells.

## 3. Architecture

The project follows a modular functional design within a single `.psm1` file to minimize loading overhead.

### Design Decisions

- **Process Isolation (PS 5.1)**: We use `RunspacePool` instead of `Start-Job` to avoid the 3x process overhead of starting multiple `powershell.exe` instances.
- **Thread Parallelism (PS 7+)**: We leverage `ForEach-Object -Parallel` for native, high-speed execution.
- **Synchronous Locking**: Commands like `install` and `uninstall` are synchronous to prevent installer conflict (e.g., Windows Installer Service locks).

### Data Flow Diagram (ASCII)

```text
[User Command] -> [Sanitizer] -> [Manager Detector] -> [Hybrid Engine]
                                                               |
    +----------------------------------------------------------+
    |                         |                        |
[winget task]           [choco task]             [scoop task]
    |                         |                        |
    +-----------[ Results Aggregator / Picker ]--------+
                               |
                        [UI Renderer]
```

## 4. API & Command Interface

### `pacwin` Main Entry Point

**Parameters:**

- `$Command` (string, position 0): The action to perform (e.g., `search`, `install`, `-Syu`).
- `$Query` (string, position 1): The search term or package ID.
- `$Manager` (string, optional): One of `winget`, `choco`, `scoop`. Forces the operation to a specific manager.
- `$Limit` (int, default: 40): Maximum results to display in search.

**Returns:**
Returns an array of `PSCustomObject` for search operations or boolean success/fail states for actions.

## 5. Error Interpretation System

Located in `_pw_handle_result` ([pacwin.psm1](file:///g:/DEVELOPMENT/pacwin/pacwin.psm1)), this system translates internal manager states:

- **Winget**: Detects `0x8A15002E` (Restart Required) and maps it to a human-readable status.
- **Chocolatey**: Handles exit codes `1641` and `3010` as success-with-reboot.
- **Scoop**: Performs text-analysis on the output because Scoop often returns `ExitCode 0` even when a manifest is missing or access is denied.

## 6. Examples & Use Cases

### Real-world scenario: Unified System Update

```powershell
# Updates everything: winget sources, choco packages, and scoop buckets.
pacwin update
```

### Scenario: Resolving Source Conflicts

When searching for "vlc", you might find it in `winget` and `choco`.

```powershell
pacwin install vlc
# Output: Package available in multiple sources — pick one:
# [1] vlc (choco)
# [2] VideoLAN.VLC (winget)
# Source index: _
```

## 7. Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `[!] Timeout in scoop` | Scoop bucket update is slow | Run `scoop update` manually to warm the cache. |
| Characters like `Ôûê` | CLI output encoding mismatch | Ensure terminal uses UTF-8 (`chcp 65001`). `pacwin` forces UTF8 BOM internally. |
| `Command Not Found` | Module path not in env | Run `.\install.ps1` to update your `$PROFILE`. |

## 8. Maintenance & Dependencies

- **Dependencies**: PowerShell 5.1+ (Win10 Default) or PowerShell 7.2+.
- **Version Constraint**: Pester 3.4.0 (for legacy test support) or Pester 5.0+ (for modern dev).
- **Maintenance Note**: Always prioritize ASCII characters for UI elements to maintain compatibility with legacy `conhost.exe`.

---
**Last updated**: 2026-04-09
**Maintainer**: pacwin contributors
**Known Limitations**: `pacwin update` for individual packages is currently restricted to "Update All" or sequential manual updates.
