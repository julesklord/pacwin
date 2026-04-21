# AGENTS.md - AI Agent Instructions for pacwin

## Project Overview

pacwin is a PowerShell module that unifies winget, chocolatey, and scoop under a fast, pacman-like CLI for Windows package management. It uses a hybrid concurrency engine (Runspaces in PS 5.1, Parallel in PS 7+) for performance.

## Key Conventions

- **Internal Functions**: Prefix with `_pw_` (e.g., `_pw_search_all`) to avoid global namespace pollution.
- **Error Handling**: Use colored output (Green/Yellow/Red) and custom exit-code parsing for manager-specific errors.
- **Input Validation**: Regex sanitization blocks injection; only allows `a-zA-Z0-9\._\-@/`.
- **Code Organization**: Use `#region` blocks for logical sections.
- **UI**: ASCII tables, real-time indicators, pacman-like flags (`-S` install, `-R` remove).

## Build and Test Commands

- **Run Tests**: `Import-Module ./tests/modules/Pester; Invoke-Pester ./tests/pacwin.Tests.ps1`
- **Install Locally**: `.\install.ps1` (copies module and updates profile)
- **No Formal Build**: Script module; edit `pacwin.psm1` directly.

## Common Pitfalls

- Requires at least one manager (winget/choco/scoop) in PATH.
- Admin rights needed for choco/winget; warn but don't auto-elevate.
- Scoop searches timeout if buckets stale; run `scoop update`.
- PS 5.1 lacks Parallel; uses Runspaces but may have encoding issues.
- Execution policy may block scripts; suggest `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

## Architecture Notes

- Single `.psm1` file for zero overhead.
- Manager abstraction with per-manager parsers.
- Synchronous installs to prevent conflicts.

## Links to Documentation

- **[README.md](README.md)**: Overview and quick start.
- **[wiki/Command_Reference.md](wiki/Command_Reference.md)**: Full command syntax.
- **[wiki/Installation.md](wiki/Installation.md)**: Detailed installation.
- **[CHANGELOG.md](CHANGELOG.md)**: Version history.
- **[scratch/DOCUMENTATION.md](scratch/DOCUMENTATION.md)**: Technical deep-dive.
- **[scratch/features.md](scratch/features.md)**: Feature roadmap.
