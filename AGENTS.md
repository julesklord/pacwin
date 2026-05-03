# AGENTS.md - AI Agent Instructions for pacwin

## Project

Single-file PowerShell module (~1400 lines, `pacwin.psm1`). No build step. Edit the `.psm1` directly; manifest is `pacwin.psd1`.

## Conventions

- **Internal functions**: `_pw_` prefix (e.g., `_pw_search_all`). Module-scoped.
- **StrictMode**: `Set-StrictMode -Version 2.0` enforced module-wide.
- **Security**: No `Invoke-Expression`. Input sanitization via `_pw_sanitize` (allows `a-zA-Z0-9._\-@/`).
- **Output**: ASCII tables, colored (Green/Yellow/Red). Pacman flags (`-S`/`-R`) and verbose commands.

## Commands

- **Search interactive**: `pacwin search <q>` or `pacwin -Ss <q>` — shows numbered list, prompts for selection, installs chosen package. This is the default behavior.
- **Search non-interactive**: `pacwin search <q> -NoInteractive` or `-ni` — just lists results.
- **Test all**: `Import-Module ./tests/modules/Pester; Invoke-Pester ./tests`
- **Test single file**: `Invoke-Pester ./tests/parsers.Tests.ps1`
- **Install locally**: `.\install.ps1`
- **CI**: GitHub Actions installs Pester from gallery; local uses bundled Pester 5.5.

## Architecture

- **Concurrency**: RunspacePool (PS 5.1) or `ForEach-Object -Parallel` (PS 7+). Same-process.
- **Parsers**: Per-manager output → `[List[PSCustomObject]]` with unary comma wrapping.
- **Installs**: Synchronous to prevent conflicts.

## Pitfalls

- Needs ≥1 package manager (winget/choco/scoop) in PATH. `pacwin doctor` to verify.
- Admin rights for choco/winget; warn, don't auto-elevate.
- Scoop searches timeout on stale buckets; `scoop update` to refresh.
- PS 5.1 Runspaces may mangle encoding.
- Execution policy may block scripts; `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

## Tooling

- **Lint**: Trunk (`.trunk/trunk.yaml`) with prettier, node@22.16.0, python@3.10.8
