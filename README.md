# pacwin

<!-- markdownlint-disable MD033 -->

<!-- markdownlint-enable MD033 -->

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/pacwin.svg?color=blue&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/pacwin)
[![Downloads](https://img.shields.io/powershellgallery/dt/pacwin.svg?color=blue&label=Downloads)](https://www.powershellgallery.com/packages/pacwin)
![PowerShell](https://img.shields.io/badge/powershell-5.1%20%7C%207%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-blue)

**One CLI. Three managers. Zero excuses for missing `pacman`.**

`pacwin` unifies **winget**, **chocolatey**, and **scoop** behind a single, `pacman`-inspired interface for Windows. If you've ever typed `pacman -Syu` out of pure muscle memory on a PowerShell prompt—and felt the void when it didn't work—this tool was written for you.

![pacwin demo](docs/demo.gif)

---

## The Problem

You know the drill. You grew up on `pacman`, `apt`, or `dnf`. Package management was a solved problem: one tool, one syntax, done. Then corporate IT handed you a Windows laptop.

Now you juggle **three** separate package managers, each with its own quirks:

| Pain Point | winget | chocolatey | scoop |
|:-----------|:-------|:-----------|:------|
| Search syntax | `winget search` | `choco search` | `scoop search` |
| Install syntax | `winget install` | `choco install` | `scoop install` |
| Output format | Column-based, locale-dependent | Pipe-delimited (`\|`) | Bracket-based or columnar |
| Silent failure mode | Cryptic HRESULT codes | Exit code 1 for everything | Bucket not found, no error |
| Requires admin? | Sometimes | Almost always | Never |

Three tools. Three syntaxes. Three failure modes. Zero consistency. That's not package management—that's archaeology.

## The Solution

`pacwin` gives you back what Windows took away: **one command to rule them all.**

```
pacwin -Ss vim        # Search across all managers
pacwin -S neovim      # Install from the best available source
pacwin -Syu           # Update everything
pacwin -R nodejs      # Uninstall cleanly
pacwin -Q             # List all installed packages
```

If you can use `pacman`, you already know `pacwin`. And if your team prefers verbose syntax, that works too—`pacwin search`, `pacwin install`, `pacwin update`. No gatekeeping.

### Why Not Just Use [insert wrapper here]?

- Most wrappers spawn a **new PowerShell process per manager**. That's 3+ seconds of overhead on every search.
- `pacwin` uses a **hybrid concurrency engine**: `RunspacePool` threads on PS 5.1, `ForEach-Object -Parallel` on PS 7+. Same process, shared memory, minimal overhead.
- Exit codes like `3010` (reboot needed) or `0x8A15002E` (no manifest) are **decoded in real time**, not silently swallowed.

---

## Quick Start

### Install from PowerShell Gallery (Recommended)

```powershell
Install-Module -Name pacwin -Scope CurrentUser
```

That's it. No `makepkg`, no `PKGBUILD`, no AUR helper—just one line. (We know. It feels wrong. But it works.)

### Install via curl (One-Liner)

For the `curl | sh` crowd (we see you):

```powershell
curl -sSL https://raw.githubusercontent.com/julesklord/pacwin/main/get-pacwin.ps1 | powershell -Command -
```

### Install from Source

For those who read every line before running anything (respect):

```powershell
git clone https://github.com/julesklord/pacwin.git
cd pacwin
.\install.ps1
```

Restart your terminal. Then:

```powershell
pacwin search vlc
```

**Expected output:**

```text
  #    Name           ID               Version    Source
  -----------------------------------------------------------
  [1 ] vlc            vlc              3.0.21     chocolatey
  [2 ] VideoLAN.VLC   VideoLAN.VLC     3.0.21     winget
```

Multiple sources, one table. Pick your poison.

---

## Command Reference

`pacwin` speaks two dialects: **pacman-style flags** for muscle memory, and **verbose commands** for readability. Both are first-class citizens.

| Task | Verbose | pacman-style |
|:-----|:--------|:-------------|
| **Search** | `pacwin search <query>` | `pacwin -Ss <query>` |
| **Install** | `pacwin install <id>` | `pacwin -S <id>` |
| **Uninstall** | `pacwin uninstall <id>` | `pacwin -R <id>` |
| **Update all** | `pacwin update` | `pacwin -Syu` |
| **List installed** | `pacwin list` | `pacwin -Q` |
| **Check outdated** | `pacwin outdated` | `pacwin -Qu` |
| **Hold / Pin** | `pacwin hold <id>` | `pacwin pin <id>` |
| **Health check** | `pacwin doctor` | `pacwin check` |
| **Deduplicate** | `pacwin sync` | `pacwin dupes` |
| **Self-update** | `pacwin self-update` | `pacwin update-self` |

### Filter by Manager

Don't trust one of the backends? Force a specific source:

```powershell
pacwin search nodejs -Manager scoop    # scoop only
pacwin install git -Manager winget     # winget only
```

### Search Timeout

Some scoop buckets are *glacially* slow. Set a ceiling:

```powershell
pacwin search python -Timeout 45
```

### Scripting & CI/CD

Suppress the banner for automation pipelines:

```powershell
pacwin search terraform -NoHeader
```

Combine with `-WhatIf` for dry runs (native PowerShell `SupportsShouldProcess` integration):

```powershell
pacwin install docker -WhatIf
```

---

## Architecture

`pacwin` is a single **Script Module (`.psm1`)** file. No compiled binaries, no DLL hell, no build step. Load it, use it, read it if you want—it's ~1400 lines of annotated PowerShell.

### Concurrency Engine

The core design decision was performance without complexity:

| PowerShell Version | Concurrency Model | Why |
|:-------------------|:-------------------|:----|
| **5.1** | `RunspacePool` (threads) | Avoids `Start-Job` overhead (~3s saved per search) |
| **7+** | `ForEach-Object -Parallel` | Native pipeline parallelism, cleaner syntax |

Both paths execute manager CLI calls concurrently within the **same process**. No child processes, no serialization overhead.

### Parser Architecture

Each manager has a dedicated output parser because, of course, none of them agree on a format:

- **`_pw_parse_winget_lines`** — Heuristic column-boundary detection. Handles locale-dependent headers (Spanish, German, etc.) without hardcoding column names.
- **`_pw_parse_choco_lines`** — Pipe-delimited (`|`) split with whitespace trimming.
- **`_pw_parse_scoop_lines`** — Dual-mode: modern bracket format `name (version) [bucket]` and legacy columnar output.

All parsers return `[System.Collections.Generic.List[PSCustomObject]]` with unary comma wrapping to prevent PowerShell's collection unrolling under `Strict Mode 2.0`.

### Security Model

- **Input sanitization** via `_pw_sanitize`: strict regex validation (`a-zA-Z0-9._\-@/`). Anything else is rejected before it reaches a shell call.
- **Path validation** via `_pw_validate_path`: blocks directory traversal and null-byte injection.
- **`Set-StrictMode -Version 2.0`** enforced module-wide. No uninitialized variables, no silent property access failures.
- **No `Invoke-Expression`**. Ever. All external calls go through direct invocation.

### Internal Naming

All internal functions use the `_pw_` prefix to avoid polluting your global namespace. If you `Get-Command _pw_*` after loading the module, that's by design—they're scoped to the module.

---

## Requirements

| Component | Minimum | Recommended |
|:----------|:--------|:------------|
| **OS** | Windows 10 | Windows 11 |
| **PowerShell** | 5.1 | 7.2+ |
| **Package Managers** | At least one of: `winget`, `choco`, `scoop` | All three in PATH |

Run `pacwin doctor` to verify your environment.

---

## Testing

The test suite uses a **bundled Pester 5.5** module (no global install required):

```powershell
Import-Module ./tests/modules/Pester
Invoke-Pester ./tests
```

Current coverage:

| Suite | Tests | Scope |
|:------|:------|:------|
| `pacwin.Tests.ps1` | 12 | Core logic, security, command dispatch, parsers, string truncation |
| `parsers.Tests.ps1` | 12 | Scoop multi-format, choco pipe-split, edge cases, legacy formats |
| **Total** | **24** | All passing ✅ |

---

## Contributing

1. **Issues**: Use the [GitHub issue tracker](https://github.com/julesklord/pacwin/issues). Bug reports with `pacwin doctor` output are appreciated.
2. **Pull Requests**: Fork, branch, test, PR. Keep the `_pw_` prefix convention. Run the full test suite before submitting.
3. **Code Style**: Single `.psm1` file, `#region` blocks for organization, `Strict Mode 2.0` compliance mandatory.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

Use it, fork it, ship it. Just don't blame us if you start missing `pacman` even *more*.

---

### Metadata

- **Status**: Stable (v0.2.6)
- **Requirements**: Windows PowerShell 5.1 or PS 7.2+
- **Maintainers**: [julesklord](https://github.com/julesklord)
- **Known issues**: Scoop searches can timeout if bucket metadata is stale — run `scoop update` to refresh. Same energy as `pacman -Syy`, different tool.
