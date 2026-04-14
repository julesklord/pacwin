# Command Reference

**Updated:** 2026-04-10 | **Read time:** 5 min | **Difficulty:** Intermediate

`pacwin` commands can be used with explicit verbs or `pacman` shorthand flags.

| Task | Verb | Pacman Flag |
| :--- | :--- | :--- |
| **Search** | `pacwin search <query>` | `pacwin -Ss <query>` |
| **Install** | `pacwin install <id>` | `pacwin -S <id>` |
| **Uninstall**| `pacwin uninstall <id>` | `pacwin -R <id>` |
| **Update All**| `pacwin update` | `pacwin -Syu` |
| **Update One**| `pacwin update <id>` | N/A |
| **List Installed**| `pacwin list` | `pacwin -Q` |
| Outdated | `pacwin outdated` | `pacwin -Qu` |
| **Info** | `pacwin info <id>` | `pacwin -Si <id>` |

> [!IMPORTANT]
> **Administrative Privileges**: Most operations that modify the system (install, uninstall, update, pin, import) require **Administrator privileges**, especially when using **Chocolatey** or system-level **Winget** sources.

## `pacwin search`

Finds packages matching a query across all detected managers. It utilizes an optimized Hybrid engine (Threaded in PS 5.1, Parallel objects in PS 7) to drastically reduce latency and CPU spike.

**Syntax:** `pacwin search <query> [-Manager <string>]`

```powershell
PS> pacwin search nodejs
  > Searching for 'nodejs'...
  #    Name           ID             Version      Source
  ----------------------------------------------------------
  [1 ] Node.js        OpenJS.NodeJS  20.12.2      winget
  [2 ] nodejs         nodejs         21.7.2       chocolatey
  [3 ] nodejs         nodejs         20.12.0      scoop
```

## `pacwin install`

Installs a package. If multiple matches are found, it interacts with the user to select the preferred source.

**Syntax:** `pacwin install <id> [-Manager <string>]`

```powershell
PS> pacwin install nodejs
  Looking for candidates for 'nodejs'...
  ...
  Select a package by number [1-3] (empty to cancel): 3

  -> Installing: nodejs [scoop v20.12.0]
  ----------------------------------------------------
  Installing 'nodejs' (20.12.0) [64bit]
  ...
```

## `pacwin update`

Updates all packages synchronously, or checks intelligent registries to update a specific package by ID.

**Syntax:** `pacwin update [id] [-Manager <string>]`

```powershell
PS> pacwin update
  -- winget -----------------------------
  No updates available.
  -- chocolatey -------------------------
  Chocolatey upgraded 0/0 packages.
  -- scoop ------------------------------
  Updating scoop...
```

**Individual Update:**

```powershell
PS> pacwin update vlc
  Looking for update candidates for 'vlc'...
  Searching in outdated packages...
  -> Updating 'vlc' with winget ...
```

## `pacwin uninstall`

Removes an installed package. **Requires `-Manager`** if the exact package source is ambiguous to `pacwin` during runtime or if no index is provided.

**Syntax:** `pacwin uninstall <id> -Manager <winget|choco|scoop>`

```powershell
PS> pacwin uninstall vlc -Manager winget
  -> Uninstalling 'vlc' with winget ...
  ----------------------------------------------------
  Found VLC media player [VideoLAN.VLC]
  Starting package uninstall...
  Successfully uninstalled
```

> [!IMPORTANT]
> Always verify the exact package ID before uninstalling, especially with `winget`, as it loosely matches substrings natively.

---
**Next:** [Usage Patterns](04-USAGE_PATTERNS.md)
