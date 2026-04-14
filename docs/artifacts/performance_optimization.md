# Performance Optimization: Array Concatenation using +=

## What
Replaced all instances of `+=` array concatenations within loops with `[System.Collections.Generic.List[type]]::new()` and `.Add()` method.
This specifically applies to `$export.packages` and `$failed` lists.

## Why
Using `+=` on standard PowerShell arrays (`@()`) inside loops is a major performance bottleneck because it creates a entirely new array and copies all elements over during every iteration. This results in O(N^2) time complexity. By utilizing a .NET generic list (`[System.Collections.Generic.List]`), adding an item has an amortized time complexity of O(1), making it exponentially faster when iterating over large datasets.

## Measured Improvement
Local benchmarking is not currently possible since the active development environment (Linux devbox) lacks a PowerShell (`pwsh`) installation to run `Invoke-Pester` or real-world timings.
However, from an algorithmic standpoint, the change significantly improves time complexity in a guaranteed manner, and will mitigate high memory pressure and excessive CPU usage from garbage collection.
