$ModuleFile = Join-Path $PSScriptRoot "..\pacwin.psm1"
Import-Module $ModuleFile -Force

Describe "pacwin Parsers" {
    InModuleScope "pacwin" {
        Context "Scoop Parser (_pw_parse_scoop_lines)" {
            It "Should return an empty list when no lines are provided" {
                $results = _pw_parse_scoop_lines @()
                $results.Count | Should -Be 0
            }

            It "Should ignore lines until 'Results from' is encountered" {
                $lines = @(
                    "Scoop version 0.1.0",
                    "Some other noise",
                    "Results from local buckets...",
                    "  7zip (23.01) [main]"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 1
                $results[0].Name | Should -Be "7zip"
            }

            It "Should parse modern scoop format: '  name (version) [bucket]'" {
                $lines = @(
                    "Results from local buckets...",
                    "  7zip (23.01) [main]",
                    "  git (2.42.0.windows.2) [main]",
                    "  vscode (1.82.2) [extras]"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 3
            }

            It "Should parse legacy scoop format with columns" {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version    Source",
                    "----    -------    ------",
                    "curl    8.4.0      main",
                    "wget    1.21.4     main"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 2
            }

            It "Should handle legacy format with missing versions" {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version",
                    "----    -------",
                    "some-app"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 1
            }

            It "Should ignore empty lines and separators" {
                $lines = @(
                    "Results from local buckets...",
                    "",
                    "----------------------------",
                    "  7zip (23.01) [main]",
                    "    ",
                    "  git (2.42.0.windows.2) [main]"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 2
            }

            It "Should ignore header lines in legacy format" {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version    Source",
                    "curl    8.4.0      main"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 1
            }
        }
    }
}
