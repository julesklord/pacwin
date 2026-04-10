# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-09

### Added

- **Hybrid Search Engine**: New search core that automatically detects PowerShell version.
  - PowerShell 7+: Uses `ForEach-Object -Parallel` for native threading.
  - PowerShell 5.1: Uses `RunspacePool` for lightweight asynchronous execution.
- **Error Interpretation System**: Logic to parse and report manager-specific exit codes and console output for Winget, Chocolatey, and Scoop.
- **Remote Installer**: Added `get-pacwin.ps1` for automated installation via `curl | powershell`.
- **Technical Documentation**: Comprehensive `DOCUMENTATION.md` detailing architecture and API.

### Changed

- **Internationalization**: Full project refactor to English (Code, Comments, UI).
- **Aesthetic Overhaul**: Replaced extended ASCII box characters with standard ASCII for better indentation and compatibility.
- **Installer Refactor**: Simplified `install.ps1` with automatic profile detection and standard module pathing.
- **README Update**: New production-grade README with status badges and pacman mapping table.

### Fixed

- High CPU usage during searches by replacing `Start-Job` with `Runspaces`.
- Syntax errors and reserved variable warnings ($input renamed to $targetInput).
- Encoding issues in PowerShell 5.1 (all files saved with UTF-8 BOM).

### Security

- Reinforced input sanitization logic in `_pw_sanitize`.

---
*Release v0.1.0*
