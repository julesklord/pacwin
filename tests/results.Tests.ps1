BeforeAll {
    $ModuleFile = Join-Path $PSScriptRoot "../pacwin.psm1"
    Import-Module $ModuleFile -Force
}

Describe "_pw_handle_result" {
    BeforeEach {
        Mock -ModuleName pacwin _pw_color { param($text, $color, $NoNewline) }
    }

    Context "winget" {
        It "handles success (0)" {
            InModuleScope pacwin {
                _pw_handle_result "winget" 0 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[OK\]" -and $color -eq "Green" }
        }

        It "handles success with restart (-1978335186)" {
            InModuleScope pacwin {
                _pw_handle_result "winget" -1978335186 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Restart required" -and $color -eq "Green" }
        }

        It "handles known error (-1978335215)" {
            InModuleScope pacwin {
                _pw_handle_result "winget" -1978335215 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Network or Source Error" -and $color -eq "Yellow" }
        }

        It "handles unknown error (999)" {
            InModuleScope pacwin {
                _pw_handle_result "winget" 999 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Winget Error \(Code: 999\)" -and $color -eq "Yellow" }
        }
    }

    Context "choco" {
        It "handles success (0)" {
            InModuleScope pacwin {
                _pw_handle_result "choco" 0 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[OK\]" -and $color -eq "Green" }
        }

        It "handles success with restart (1641)" {
            InModuleScope pacwin {
                _pw_handle_result "choco" 1641 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Restart required" -and $color -eq "Green" }
        }

        It "handles success with restart (3010)" {
            InModuleScope pacwin {
                _pw_handle_result "choco" 3010 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Restart required" -and $color -eq "Green" }
        }

        It "handles known error (1603)" {
            InModuleScope pacwin {
                _pw_handle_result "choco" 1603 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Fatal error" -and $color -eq "Yellow" }
        }

        It "handles unknown error (999)" {
            InModuleScope pacwin {
                _pw_handle_result "choco" 999 @()
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Chocolatey Error \(Code: 999\)" -and $color -eq "Yellow" }
        }
    }

    Context "scoop" {
        It "handles success by output text (installed successfully)" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 0 @("Package installed successfully")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[OK\]" -and $color -eq "Green" }
        }

        It "handles success by output text (already installed)" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 0 @("Package is already installed")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[OK\]" -and $color -eq "Green" }
        }

        It "handles failure by output text (Couldn't find manifest)" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 1 @("Error: Couldn't find manifest for 'nonexistent'")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Scoop Error:.*Couldn't find manifest" -and $color -eq "Yellow" }
        }

        It "handles failure by output text (Access denied)" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 1 @("Error: Access denied")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Scoop Error:.*Access denied" -and $color -eq "Yellow" }
        }

        It "handles success by exit code 0" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 0 @("Random output")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[OK\]" -and $color -eq "Green" }
        }

        It "handles failure by exit code 1" {
            InModuleScope pacwin {
                _pw_handle_result "scoop" 1 @("Random error")
            }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "\[FAILURE\]" -and $color -eq "Red" }
            Assert-MockCalled _pw_color -ModuleName pacwin -ParameterFilter { $text -match "Generic failure" -and $color -eq "Yellow" }
        }
    }
}
