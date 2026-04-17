# pacwin Tests (PowerShell Pester 5.x Optimized)

BeforeAll {
    # Resolve path to the module relative to the test file
    $ModuleFile = Resolve-Path (Join-Path $PSScriptRoot "..\pacwin.psm1") -ErrorAction SilentlyContinue
    if ($null -eq $ModuleFile) {
        # Fallback for some CI environments where .. might resolve differently
        $ModuleFile = Resolve-Path (Join-Path (Get-Item $PSScriptRoot).Parent.FullName "pacwin.psm1") -ErrorAction SilentlyContinue
    }
    
    if ($null -eq $ModuleFile) {
        throw "Unable to locate pacwin.psm1. PSScriptRoot: $PSScriptRoot"
    }
    Import-Module $ModuleFile.Path -Force
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
}
