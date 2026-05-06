BeforeAll {
    $ModuleFile = Join-Path $PSScriptRoot "../pacwin.psm1"
    Import-Module $ModuleFile -Force
}

Describe "pacwin Parsers" {
    Context "Scoop Parser (_pw_parse_scoop_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_scoop_lines @()
                $results.Count | Should -Be 0
            }
        }

        It "Should ignore lines until 'Results from' is encountered" {
            InModuleScope pacwin {
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
        }

        It "Should parse modern scoop format: '  name (version) [bucket]'" {
            InModuleScope pacwin {
                $lines = @(
                    "Results from local buckets...",
                    "  7zip (23.01) [main]",
                    "  git (2.42.0.windows.2) [main]",
                    "  vscode (1.82.2) [extras]"
                )
                $results = _pw_parse_scoop_lines $lines

                $results.Count | Should -Be 3

                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01"
                $results[0].Manager | Should -Be "scoop"

                $results[1].Name | Should -Be "git"
                $results[1].Version | Should -Be "2.42.0.windows.2"

                $results[2].Name | Should -Be "vscode"
                $results[2].Version | Should -Be "1.82.2"
            }
        }

        It "Should parse legacy scoop format with columns" {
            InModuleScope pacwin {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version    Source",
                    "----    -------    ------",
                    "curl    8.4.0      main",
                    "wget    1.21.4     main"
                )
                $results = _pw_parse_scoop_lines $lines

                $results.Count | Should -Be 2

                $results[0].Name | Should -Be "curl"
                $results[0].Version | Should -Be "8.4.0"

                $results[1].Name | Should -Be "wget"
                $results[1].Version | Should -Be "1.21.4"
            }
        }

        It "Should handle legacy format with missing versions" {
            InModuleScope pacwin {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version",
                    "----    -------",
                    "some-app"
                )
                $results = _pw_parse_scoop_lines $lines

                $results.Count | Should -Be 1
                $results[0].Name | Should -Be "some-app"
                $results[0].Version | Should -Be "?"
            }
        }

        It "Should ignore empty lines and separators" {
            InModuleScope pacwin {
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
        }

        It "Should ignore header lines in legacy format" {
            InModuleScope pacwin {
                $lines = @(
                    "Results from local buckets...",
                    "Name    Version    Source",
                    "curl    8.4.0      main"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 1
                $results[0].Name | Should -Be "curl"
            }
        }
    }

    Context "Chocolatey Parser (_pw_parse_choco_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_choco_lines @()
                $results.Count | Should -Be 0
            }
        }

        It "Should parse simple name|version format" {
            InModuleScope pacwin {
                $lines = @(
                    "7zip|23.01.0",
                    "git|2.42.0",
                    "vscode|1.82.2"
                )
                $results = _pw_parse_choco_lines $lines

                $results.Count | Should -Be 3

                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01.0"
                $results[0].Manager | Should -Be "choco"

                $results[1].Name | Should -Be "git"
                $results[1].Version | Should -Be "2.42.0"

                $results[2].Name | Should -Be "vscode"
                $results[2].Version | Should -Be "1.82.2"
            }
        }

        It "Should ignore lines with missing versions or empty strings" {
            InModuleScope pacwin {
                $lines = @(
                    "7zip|23.01.0",
                    "",
                    "git",
                    "vscode|"
                )
                $results = _pw_parse_choco_lines $lines

                $results.Count | Should -Be 2

                $results[0].Name | Should -Be "7zip"

                $results[1].Name | Should -Be "vscode"
                $results[1].Version | Should -Be ""
            }
        }

        It "Should handle extra columns correctly" {
            InModuleScope pacwin {
                $lines = @(
                    "7zip|23.01.0|extra_info",
                    "git|2.42.0|main|something"
                )
                $results = _pw_parse_choco_lines $lines

                $results.Count | Should -Be 2

                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01.0"

                $results[1].Name | Should -Be "git"
                $results[1].Version | Should -Be "2.42.0"
            }
        }

        It "Should trim whitespace around parts" {
            InModuleScope pacwin {
                $lines = @(
                    "  7zip  |  23.01.0  ",
                    "git| 2.42.0 "
                )
                $results = _pw_parse_choco_lines $lines

                $results.Count | Should -Be 2

                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01.0"

                $results[1].Name | Should -Be "git"
                $results[1].Version | Should -Be "2.42.0"
            }
        }
    }
}
