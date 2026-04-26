# Parser Tests for pacwin

Describe "pacwin Parsers" {
    BeforeAll {
        # Ensure no previous version of the module is lingering
        Remove-Module pacwin -ErrorAction SilentlyContinue

        $parent = Split-Path $PSScriptRoot -Parent
        if (-not $parent) {
            $parent = $PSScriptRoot
        }

        $candidates = @(
            (Join-Path $parent "pacwin.psm1"),
            (Join-Path $parent "scratch/pacwin.psm1")
        )

        $ModuleFile = $null
        foreach ($candidate in $candidates) {
            if (Test-Path $candidate) {
                $ModuleFile = (Resolve-Path $candidate).Path
                break
            }
        }

        if (-not $ModuleFile) {
            throw "Unable to locate pacwin.psm1 from tests."
        }

        Import-Module $ModuleFile -Force
    }

    Context "Scoop Parser (_pw_parse_scoop_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_scoop_lines @()
                @($results).Count | Should -Be 0
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
                @($results).Count | Should -Be 1
                @($results)[0].Name | Should -Be "7zip"
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

                @($results).Count | Should -Be 3

                @($results)[0].Name | Should -Be "7zip"
                @($results)[0].Version | Should -Be "23.01"
                @($results)[0].Manager | Should -Be "scoop"

                @($results)[1].Name | Should -Be "git"
                @($results)[1].Version | Should -Be "2.42.0.windows.2"

                @($results)[2].Name | Should -Be "vscode"
                @($results)[2].Version | Should -Be "1.82.2"
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

                @($results).Count | Should -Be 2

                @($results)[0].Name | Should -Be "curl"
                @($results)[0].Version | Should -Be "8.4.0"

                @($results)[1].Name | Should -Be "wget"
                @($results)[1].Version | Should -Be "1.21.4"
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

                @($results).Count | Should -Be 1
                @($results)[0].Name | Should -Be "some-app"
                @($results)[0].Version | Should -Be "?"
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

                @($results).Count | Should -Be 2
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
                @($results).Count | Should -Be 1
                @($results)[0].Name | Should -Be "curl"
            }
        }
    }

    Context "Chocolatey Parser (_pw_parse_choco_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_choco_lines @()
                @($results).Count | Should -Be 0
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

                @($results).Count | Should -Be 3

                @($results)[0].Name | Should -Be "7zip"
                @($results)[0].Version | Should -Be "23.01.0"
                @($results)[0].Manager | Should -Be "choco"

                @($results)[1].Name | Should -Be "git"
                @($results)[1].Version | Should -Be "2.42.0"

                @($results)[2].Name | Should -Be "vscode"
                @($results)[2].Version | Should -Be "1.82.2"
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

                @($results).Count | Should -Be 2

                @($results)[0].Name | Should -Be "7zip"

                @($results)[1].Name | Should -Be "vscode"
                @($results)[1].Version | Should -Be ""
            }
        }

        It "Should handle extra columns correctly" {
            InModuleScope pacwin {
                $lines = @(
                    "7zip|23.01.0|extra_info",
                    "git|2.42.0|main|something"
                )
                $results = _pw_parse_choco_lines $lines

                @($results).Count | Should -Be 2

                @($results)[0].Name | Should -Be "7zip"
                @($results)[0].Version | Should -Be "23.01.0"

                @($results)[1].Name | Should -Be "git"
                @($results)[1].Version | Should -Be "2.42.0"
            }
        }

        It "Should trim whitespace around parts" {
            InModuleScope pacwin {
                $lines = @(
                    "  7zip  |  23.01.0  ",
                    "git| 2.42.0 "
                )
                $results = _pw_parse_choco_lines $lines

                @($results).Count | Should -Be 2

                @($results)[0].Name | Should -Be "7zip"
                @($results)[0].Version | Should -Be "23.01.0"

                @($results)[1].Name | Should -Be "git"
                @($results)[1].Version | Should -Be "2.42.0"
            }
        }
    }

    Context "Winget Parser (_pw_parse_winget_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_winget_lines @()
                @($results).Count | Should -Be 0
            }
        }

        It "Should parse segmented separator format (Standard)" {
            InModuleScope pacwin {
                $lines = @(
                    "Name                           Id                               Version          Source",
                    "------------------------------------------------------------------------------------------",
                    "Google Chrome                  Google.Chrome                    120.0.6099.130   winget",
                    "Visual Studio Code             Microsoft.VisualStudioCode       1.85.1           winget"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 2

                @($results)[0].Name | Should -Be "Google Chrome"
                @($results)[0].ID | Should -Be "Google.Chrome"
                @($results)[0].Version | Should -Be "120.0.6099.130"
                @($results)[0].Source | Should -Be "winget"

                @($results)[1].Name | Should -Be "Visual Studio Code"
                @($results)[1].ID | Should -Be "Microsoft.VisualStudioCode"
                @($results)[1].Version | Should -Be "1.85.1"
            }
        }

        It "Should parse single long separator format" {
            InModuleScope pacwin {
                $lines = @(
                    "Name      Id      Version",
                    "-------------------------",
                    "App1      ID1     1.0",
                    "App2      ID2     2.0"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 2
                @($results)[0].Name | Should -Be "App1"
                @($results)[0].ID | Should -Be "ID1"
                @($results)[0].Version | Should -Be "1.0"
            }
        }

        It "Should handle no separator (Fallback heuristic)" {
            InModuleScope pacwin {
                $lines = @(
                    "App1    ID1    1.0",
                    "App2    ID2    2.0"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 2
                @($results)[0].Name | Should -Be "App1"
                @($results)[0].ID | Should -Be "ID1"
                @($results)[0].Version | Should -Be "1.0"
            }
        }

        It "Should ignore noise lines (Progress bars, headers, etc.)" {
            InModuleScope pacwin {
                $lines = @(
                    "Name                           Id                               Version          Source",
                    "------------------------------------------------------------------------------------------",
                    "  0% [                              ]",
                    "Google Chrome                  Google.Chrome                    120.0.6099.130   winget",
                    " 50% [###########                  ]",
                    "Visual Studio Code             Microsoft.VisualStudioCode       1.85.1           winget",
                    "100% [#############################]"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 2
                @($results)[0].Name | Should -Be "Google Chrome"
                @($results)[1].Name | Should -Be "Visual Studio Code"
            }
        }

        It "Should handle missing versions in fallback heuristic" {
            InModuleScope pacwin {
                $lines = @(
                    "AppWithoutVersion    IDOnly"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 1
                @($results)[0].Name | Should -Be "AppWithoutVersion"
                @($results)[0].ID | Should -Be "AppWithoutVersion"
                @($results)[0].Version | Should -Be "IDOnly"
            }
        }

        It "Should handle truncated lines gracefully" {
            InModuleScope pacwin {
                $lines = @(
                    "Name      Id      Version",
                    "----------  ------  -------",
                    "Short"
                )
                $results = _pw_parse_winget_lines $lines
                @($results).Count | Should -Be 0
            }
        }
    }
}
