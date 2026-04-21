# Welcome to pacwin Wiki

**Updated:** 2026-04-21 | **Read time:** 3 min | **Difficulty:** Beginner

`pacwin` is a Universal Package Layer for Windows. It acts as an abstraction wrapper over existing Windows package managers: `winget`, `chocolatey`, and `scoop`.

## Problem Statement

Windows package management is fragmented. Users often have to remember different commands and syntaxes depending on which repository hosts a package.

- `winget install <id>` vs `choco install <id> -y` vs `scoop install <id>`
- Each has a different search mechanism and performance penalty.
- Running multiple CLI queries sequentially scales poorly and spikes CPU usage.

`pacwin` solves this by offering a standardized, `pacman`-inspired syntax that queries and manages packages concurrently across all detected managers.

## Comparison Table

| Feature | winget | Chocolatey | Scoop | pacwin |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Scope** | MS Store, App Installers | System-wide, Admin apps | Portable, Dev tools | **All of the above** |
| **Syntax** | Verbose | Standard | Simple | `pacman`-like (`-S`, `-R`) |
| **Search Performance**| Normal | Slow (network bound) | Fast (local JSON) | **Concurrent (Hybrid)** |
| **Error Handling** | Raw | Raw | Raw | **Parsed & Intercepted** |

## 5-Minute Quickstart

1. **Verify you have a manager:** Ensure at least one of `winget`, `choco`, or `scoop` is in your PATH.
2. **Launch PowerShell:** Open a PS 5.1 or PS 7+ terminal (**Run as Administrator** is required for Chocolatey/Winget).
3. **Search for a package:**

   ```powershell
   PS> pacwin search vlc
   ```

4. **Install a package:**

   ```powershell
   PS> pacwin install vlc
   ```

5. **Update all packages:**

   ```powershell
   PS> pacwin update
   ```

> [!TIP]
> `pacwin` automatically uses parallel Runspaces (PS 5.1) or `ForEach-Object -Parallel` (PS 7) to keep your CPU overhead low during aggregate searches.

---
**Next:** [Installation Guide](02-INSTALLATION.md)
