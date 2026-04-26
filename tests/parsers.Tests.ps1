# Parser Tests for pacwin (Pester 5.x Optimized)

Describe "pacwin Parsers" {
    BeforeAll {
        Remove-Module pacwin -ErrorAction SilentlyContinue
        $current = $PSScriptRoot
        $ModuleFile = $null
        for ($i = 0; $i -lt 5; $i++) {
            $candidate = Join-Path $current "pacwin.psm1"
            if (Test-Path $candidate) {
                $ModuleFile = Get-Item $candidate
                break
            }
            $current = Split-Path $current -Parent
            if (-not $current) { break }
        }

        if ($null -eq $ModuleFile) {
            throw "Unable to locate pacwin.psm1. Search started at: $PSScriptRoot"
        }
        Import-Module $ModuleFile.FullName -Force
    }

    Context "Column Extractor (_pw_extract_column)" {
        It "Should extract a column within bounds" {
            InModuleScope pacwin {
                $line = "PackageName    ID-123    1.2.3"
                _pw_extract_column $line 0 11 | Should -Be "PackageName"
                _pw_extract_column $line 15 6 | Should -Be "ID-123"
            }
        }

        It "Should handle out of bounds gracefully" {
            InModuleScope pacwin {
                $line = "Short"
                _pw_extract_column $line 10 5 "N/A" | Should -Be "N/A"
            }
        }

        It "Should handle trailing columns with small length" {
            InModuleScope pacwin {
                $line = "Part1  Part2"
                _pw_extract_column $line 7 100 | Should -Be "Part2"
            }
        }

        It "Should return fallback for empty or whitespace columns" {
            InModuleScope pacwin {
                $line = "Name          Version"
                _pw_extract_column $line 5 5 "Empty" | Should -Be "Empty"
            }
        }
    }

    Context "Winget Parser (_pw_parse_winget_lines)" {
        It "Should parse standard winget table output" {
            InModuleScope pacwin {
                $lines = @(
                    "Name               Id               Version     Source",
                    "------------------------------------------------------",
                    "Google Chrome      Google.Chrome    120.0.0.0   winget",
                    "Mozilla Firefox    Mozilla.Firefox  121.0       winget"
                )
                $res = _pw_parse_winget_lines $lines
                $res.Count | Should -Be 2
                $res[0].Name | Should -Be "Google Chrome"
                $res[0].ID | Should -Be "Google.Chrome"
                $res[0].Version | Should -Be "120.0.0.0"
            }
        }

        It "Should handle missing version column" {
            InModuleScope pacwin {
                $lines = @(
                    "Name      Id",
                    "------------",
                    "App1      App1.Id"
                )
                $res = _pw_parse_winget_lines $lines
                $res.Count | Should -Be 1
                $res[0].Version | Should -Be "?"
            }
        }

        It "Should use heuristic fallback if no separator is found" {
            InModuleScope pacwin {
                $lines = @(
                    "Name  Id  Version",
                    "App1  Id1  1.0.0"
                )
                $res = _pw_parse_winget_lines $lines
                # The heuristic skip logic might skip "Name Id Version" if it matches noise regex
                # But it should find App1
                $res.Count | Should -BeGreaterThan 0
                $res | Where-Object { $_.Name -eq "App1" } | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Scoop Parser (_pw_parse_scoop_lines)" {
        It "Should return an empty list when no lines are provided" {
            InModuleScope pacwin {
                $results = _pw_parse_scoop_lines @()
                $results.Count | Should -Be 0
            }
        }

        It "Should parse modern scoop format: '  name (version) [bucket]'" {
            InModuleScope pacwin {
                $lines = @(
                    "Results from local buckets...",
                    "  7zip (23.01) [main]",
                    "  git (2.42.0.windows.2) [main]"
                )
                $results = _pw_parse_scoop_lines $lines
                $results.Count | Should -Be 2
                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01"
            }
        }
    }

    Context "Chocolatey Parser (_pw_parse_choco_lines)" {
        It "Should parse simple name|version format" {
            InModuleScope pacwin {
                $lines = @(
                    "7zip|23.01.0",
                    "git|2.42.0"
                )
                $results = _pw_parse_choco_lines $lines
                $results.Count | Should -Be 2
                $results[0].Name | Should -Be "7zip"
                $results[0].Version | Should -Be "23.01.0"
            }
        }
    }
}
