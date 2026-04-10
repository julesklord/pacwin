# Troubleshooting

**Updated:** 2026-04-10 | **Read time:** 3 min | **Difficulty:** Advanced

This guide focuses on resolving symptoms you might encounter while using `pacwin`.

## Symptom: "Timeout during Scoop search"

**Issue:** `pacwin search` takes a very long time and Scoop returns few or no results.
**Cause:** Scoop's local bucket registry might be stale or corrupted, causing its search process to hang or delay the parallel runspace.
**Fix:** Force an update of Scoop's internal manifests by running:

```powershell
PS> scoop update
```

## Symptom: "Access Denied" or Exit Code 1 during Choco operations

**Issue:** Installing or updating via Chocolatey fails with permission or write errors.
**Cause:** `choco` typically requires Administrative privileges to write to `C:\ProgramData\chocolatey` or modify system-wide registry keys.
**Fix:** Run your PowerShell session as Administrator. `pacwin` proxies your current context's privileges to the underlying managers.

## Symptom: Duplicate IDs in Search Results

**Issue:** Searching for "vlc" returns multiple entries from `winget` that look identical (e.g., different Monikers or architectures).
**Cause:** Winget's source repositories natively return multiple matches for UWP vs Desktop apps, or separate MS Store links.
**Fix:** Use `pacwin info <id> -Manager winget` to view the specific installation details before choosing which one to install from the prompt.

## Symptom: Unicode / Corrupted Characters in Terminal

**Issue:** Bizarre characters (`â—Æê`) appear in the output, or PowerShell 5.1 throws a `ParserError`.
**Cause:** The script encoding was compromised or the console code page doesn't support UTF-8 effectively.
**Fix:**

1. Ensure your console is using a UTF-8 codepage by running `chcp 65001`.
2. As of `pacwin v0.1.0+`, we aggressively strip non-ASCII characters from winget progress bars to prevent parser breaking. Ensure you are running `pacwin status` to verify version stability and that you haven't downgraded unintentionally.

## FAQ

**How does `pacwin` choose a manager if I don't use `-Manager` during install?**  
`pacwin` always searches all active managers first, aggregates the results, and prompts you to select a target via a numerical index `[1..N]`. It does not execute guesses without `-Manager`.

**Can I mix tools? (e.g., update a winget package via choco)**  
No. Package managers do not share local state. If you installed Git via `winget`, you must update it via `winget`. `pacwin update <id>` attempts to detect the correct manager automatically using outdated registries so you don't have to remember.

**Is there offline support?**  
No. Both searching and updating require an active internet connection to download upstream manifest definitions and installer binaries.

---
**Back to:** [Home](01-HOME.md)
