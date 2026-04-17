# Usage Patterns

**Updated:** 2026-04-17 | **Read time:** 4 min | **Difficulty:** Intermediate

Here are 5 real-world scenarios where `pacwin` shines.

## Scenario 1: Setup a New Machine

When configuring a fresh Windows install, you often need tools from multiple ecosystems (e.g., Git from winget, Node from Scoop). By using `pacwin`, you don't need to juggle different syntaxes.

```powershell
PS> pacwin install git -Manager winget
PS> pacwin install nodejs-lts -Manager scoop
PS> pacwin install vscode -Manager winget
```

## Scenario 2: Find a Package Across Repositories

You know the tool "ripgrep", but aren't sure which manager has the most up-to-date version.

```powershell
PS> pacwin search ripgrep
  ...
  [1 ] ripgrep   BurntSushi.ripgrep  13.0.0  winget
  [2 ] ripgrep   ripgrep             14.1.0  chocolatey
  [3 ] ripgrep   ripgrep             14.1.0  scoop
```

*Observation:* Scoop and Chocolatey have newer versions than Winget. You choose Scoop.

```powershell
PS> pacwin install ripgrep -Manager scoop
```

## Scenario 3: Routine "Update All"

Instead of running 3 separate commands sequentially and waiting, just run:

```powershell
PS> pacwin -Syu
```

This triggers `winget upgrade --all`, `choco upgrade all -y`, and `scoop update *`, letting you walk away while your entire toolchain refreshes.

## Scenario 4: Clean Uninstall

You installed a tool via Chocolatey months ago and forgot. You can search installed packages to find the manager, then uninstall smoothly.

```powershell
PS> pacwin list "vlc"
  -- chocolatey -------------------------
  vlc 3.0.20
```

```powershell
PS> pacwin uninstall vlc -Manager choco
```

## Scenario 5: Forcing an Individual Update

A specific package is bugged, and you know an update was released today for `vlc`.

```powershell
PS> pacwin update vlc
```

`pacwin` will silently check outdated packages (`pacwin -Qu -Silent`) to find which manager owns `vlc` and requires the update, then executes the target upgrade automatically.

---

## Scenario 6: Simulate Operations with -WhatIf

If you are unsure of what a command will do (especially uninstalls or global updates), use the standard PowerShell `-WhatIf` flag.

```powershell
PS> pacwin install nodejs -WhatIf
  What if: Performing the operation "Installing nodejs" on target "winget".
```

## Scenario 7: Pinning Packages (Hold)

Prevent a package from being updated during `pacwin update` by "holding" it.

```powershell
PS> pacwin hold "vscode" -Manager winget
  -> Pinning 'vscode' with winget ...
```

To list all current pins:

```powershell
PS> pacwin hold
```

---
**Next:** [FAQ](FAQ.md)
