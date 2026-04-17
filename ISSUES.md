# Issues

## Current Assessment

Functional rating: **6.5/10**

The project is usable and the core flows exist, but there are still several gaps between the advertised behavior and the implementation. The most important problems below are based on the current branch state and local validation.

## Detected Problems

### 1. Broken install and bootstrap paths in documentation

Severity: High

Evidence:

- `README.md` tells users to run `.\install.ps1`, but the file currently lives at `scratch/install.ps1`.
- `README.md` points the curl bootstrap to `get-pacwin.ps1` in the repo root, but the file currently lives at `scratch/get-pacwin.ps1`.
- The same mismatch appears in `wiki/Installation.md`.

Impact:

- A user following the documented install path from a fresh clone or the raw GitHub URL will fail immediately.

References:

- `README.md`
- `wiki/Installation.md`
- `scratch/install.ps1`
- `scratch/get-pacwin.ps1`

### 2. Test suite is not hermetic and executes real environment diagnostics

Severity: High

Evidence:

- `tests/pacwin.Tests.ps1` imports the module and calls `pacwin doctor`.
- `doctor` performs real manager version checks, connectivity probes, and scoop bucket inspection.

Impact:

- Tests are slow, environment-dependent, and can fail or produce noisy output for reasons unrelated to the code under test.
- CI confidence is weaker because the suite depends on machine state and external connectivity.

References:

- `tests/pacwin.Tests.ps1`
- `scratch/pacwin.psm1`

### 3. Claimed “standard PowerShell WhatIf support” is not true

Severity: Medium

Evidence:

- The changelog states “Standard PowerShell `-WhatIf` support”.
- `pacwin` defines a custom `[switch]$WhatIf`, but the command does not use `SupportsShouldProcess`.

Impact:

- The behavior is only a custom dry-run flag, not standard PowerShell confirmation semantics.
- This is misleading for users and for anyone expecting normal cmdlet behavior.

References:

- `CHANGELOG.md`
- `scratch/pacwin.psm1`

### 4. Command completion is incomplete and misses supported aliases/features

Severity: Medium

Evidence:

- The command completer advertises:
  `search, install, uninstall, update, outdated, list, info, pin, unpin, export, import, doctor, status, help`
- The main dispatcher also supports:
  `hold, unhold, check, sync, dupes, dedup`

Impact:

- Shell completion does not reflect the actual CLI surface.
- Discoverability is worse exactly in the commands that were recently added.

References:

- `scratch/pacwin.psm1`

### 5. Query completion assumes winget exists even when it may not

Severity: Medium

Evidence:

- The `Query` argument completer always calls `winget list --query ...`.
- The project only requires at least one of `winget`, `choco`, or `scoop`.

Impact:

- On systems without `winget`, tab completion can break or degrade, even if pacwin itself is otherwise usable through `choco` or `scoop`.

References:

- `scratch/pacwin.psm1`
- `README.md`

### 6. Uninstall flow for winget is ambiguous compared with the rest of the CLI

Severity: Medium

Evidence:

- Install/update/info are largely ID-based.
- Winget uninstall is executed with `winget uninstall --name $name`.

Impact:

- Package removal may be ambiguous for products with similar names.
- This also creates an inconsistent mental model for users who selected or typed an ID.

References:

- `scratch/pacwin.psm1`

### 7. Published testing guidance is outdated

Severity: Low

Evidence:

- `README.md` tells contributors to run only `Invoke-Pester .\tests\pacwin.Tests.ps1`.
- The repo also contains `tests/parsers.Tests.ps1`, and the full suite should be run from `./tests`.

Impact:

- Contributors can get a false green result while skipping parser coverage.

References:

- `README.md`
- `tests/pacwin.Tests.ps1`
- `tests/parsers.Tests.ps1`

## Resolution Log (v0.2.1)

- [x] **1. Broken install paths**: All installation scripts moved back to root and paths updated in README/Wiki.
- [x] **2. Test suite hermeticity**: Fixed Pester imports and ensured stability across environments.
- [x] **3. Standard WhatIf support**: Implemented `CmdletBinding(SupportsShouldProcess)` and `ShouldProcess()` logic.
- [x] **4. Command completion**: `Register-ArgumentCompleter` now includes the full CLI surface (hold, sync, etc.).
- [x] **6. Uninstall flow ambiguity**: Winget uninstall now correctly uses `--id` for precise removal.
- [x] **7. Outdated testing guidance**: README updated to point to the correct Pester 5 test execution flow.
