# Parser Tests for pacwin

$ModuleFile = Join-Path $PSScriptRoot "..$([System.IO.Path]::DirectorySeparatorChar)pacwin.psm1"

Describe "pacwin Parsers" {
    BeforeAll {
        # Dot-sourcing the module file to access private functions for testing
        . $ModuleFile
    }

    Context "Scoop Parser (_pw_parse_scoop_lines)" {
        It "Should return an empty list when no lines are provided" {
            $results = _pw_parse_scoop_lines @()
            $results.Count | Should Be 0
        }

        It "Should ignore lines until 'Results from' is encountered" {
            $lines = @(
                "Scoop version 0.1.0",
                "Some other noise",
                "Results from local buckets...",
                "  7zip (23.01) [main]"
            )
            $results = _pw_parse_scoop_lines $lines
            $results.Count | Should Be 1
            $results[0].Name | Should Be "7zip"
        }

        It "Should parse modern scoop format: '  name (version) [bucket]'" {
            $lines = @(
                "Results from local buckets...",
                "  7zip (23.01) [main]",
                "  git (2.42.0.windows.2) [main]",
                "  vscode (1.82.2) [extras]"
            )
            $results = _pw_parse_scoop_lines $lines

            $results.Count | Should Be 3

            $results[0].Name | Should Be "7zip"
            $results[0].Version | Should Be "23.01"
            $results[0].Manager | Should Be "scoop"

            $results[1].Name | Should Be "git"
            $results[1].Version | Should Be "2.42.0.windows.2"

            $results[2].Name | Should Be "vscode"
            $results[2].Version | Should Be "1.82.2"
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

            $results.Count | Should Be 2

            $results[0].Name | Should Be "curl"
            $results[0].Version | Should Be "8.4.0"

            $results[1].Name | Should Be "wget"
            $results[1].Version | Should Be "1.21.4"
        }

        It "Should handle legacy format with missing versions" {
            $lines = @(
                "Results from local buckets...",
                "Name    Version",
                "----    -------",
                "some-app"
            )
            $results = _pw_parse_scoop_lines $lines

            $results.Count | Should Be 1
            $results[0].Name | Should Be "some-app"
            $results[0].Version | Should Be "?"
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

            $results.Count | Should Be 2
        }

        It "Should ignore header lines in legacy format" {
            $lines = @(
                "Results from local buckets...",
                "Name    Version    Source",
                "curl    8.4.0      main"
            )
            # The current implementation of _pw_parse_scoop_lines has:
            # if ($parts.Count -ge 1 -and $parts[0] -notmatch "^[Nn]ame$|^Source$")
            # So it should skip "Name"
            $results = _pw_parse_scoop_lines $lines
            $results.Count | Should Be 1
            $results[0].Name | Should Be "curl"
        }
    }
}
