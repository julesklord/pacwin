# pacwin Tests (PowerShell Pester 5.x Optimized)

param($ModulePath)

BeforeAll {
    # If ModulePath was passed via -Data, use it. Otherwise, search.
    if ($null -ne $ModulePath -and (Test-Path $ModulePath)) {
        $ModuleFile = Get-Item $ModulePath
    }
    else {
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
    }

    if ($null -eq $ModuleFile) {
        throw "Unable to locate pacwin.psm1. Search started at: $PSScriptRoot"
    }
    Import-Module $ModuleFile.FullName -Force
}

Describe "pacwin core logic" {
    
    BeforeEach {
        # Global mocks to prevent side effects
        Mock -ModuleName pacwin _pw_is_admin { return $true }
        Mock -ModuleName pacwin _pw_detect_managers { return @{ winget = "winget.exe"; choco = "choco.exe" } }
        Mock -ModuleName pacwin _pw_color { param($text, $color, $NoNewline) }
        Mock -ModuleName pacwin _pw_header { param($title) }
    }

    It "Can run pacwin doctor without real environment checks" {
        Mock -ModuleName pacwin _pw_do_doctor { param($mgrs) }
        
        $null = pacwin doctor
        
        Assert-MockCalled _pw_do_doctor -ModuleName pacwin -Times 1 -Exactly
    }

    It "Supports standard PowerShell -WhatIf" {
        Mock -ModuleName pacwin _pw_search_all { return @([PSCustomObject]@{ Name="test"; ID="test"; Version="1.0"; Source="winget"; Manager="winget" }) }
        Mock -ModuleName pacwin _pw_pick_source { param($candidates) return $candidates[0] }
        Mock -ModuleName pacwin _pw_do_install { 
            [CmdletBinding(SupportsShouldProcess)]
            param($pkg) 
        }
        
        { pacwin install "testpkg" -WhatIf } | Should -Not -Throw
    }

    Context "Security & Sanitization" {
        It "Allows safe package IDs" {
            InModuleScope pacwin {
                _pw_sanitize "google.chrome" | Should -Be "google.chrome"
            }
        }

        It "Blocks dangerous input" {
            InModuleScope pacwin {
                _pw_sanitize "bad; comando" | Should -Be $null
            }
        }
    }

    Context "Command Dispatcher" {
        It "Recognizes new commands like 'hold' or 'sync'" {
            Mock -ModuleName pacwin _pw_do_pin { param($id, $mgr, $Unpin) }
            Mock -ModuleName pacwin _pw_do_sync { param($managers) }
            
            # Test 'hold' (pin)
            $null = pacwin hold "test" -Manager winget
            Assert-MockCalled _pw_do_pin -ModuleName pacwin -ParameterFilter { $id -eq "test" }
            
            # Test 'sync'
            $null = pacwin sync
            Assert-MockCalled _pw_do_sync -ModuleName pacwin -Times 1 -Exactly
        }
    }

    Context "String Truncation (_pw_truncate)" {
        It "Should return a padded string when input is null or empty" {
            InModuleScope pacwin {
                $result = _pw_truncate -str $null -max 5
                $result | Should -Be "     "
                $result.Length | Should -Be 5

                $resultEmpty = _pw_truncate -str "" -max 3
                $resultEmpty | Should -Be "   "
                $resultEmpty.Length | Should -Be 3
            }
        }

        It "Should return a padded string when input is shorter than max" {
            InModuleScope pacwin {
                $result = _pw_truncate -str "abc" -max 5
                $result | Should -Be "abc  "
                $result.Length | Should -Be 5
            }
        }

        It "Should return the exact string when input length equals max" {
            InModuleScope pacwin {
                $result = _pw_truncate -str "abcde" -max 5
                $result | Should -Be "abcde"
                $result.Length | Should -Be 5
            }
        }

        It "Should truncate and append a dot when input is longer than max" {
            InModuleScope pacwin {
                $result = _pw_truncate -str "abcdefg" -max 5
                $result | Should -Be "abcd."
                $result.Length | Should -Be 5
            }
        }
    }
}
