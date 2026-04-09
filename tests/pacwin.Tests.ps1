# pacwin Tests (English, Pester 3.4.0 Robust version)

# PRE-DEFINE DUMMY FUNCTIONS to keep Pester 3.4.0 happy during Mock initialization
function _pw_color {}
function _pw_header {}
function _pw_detect_managers {}
function _pw_search_all {}
function _pw_pick_source {}
function _pw_do_install {}

$ModuleFile = Join-Path $PSScriptRoot "..\pacwin.psm1"
if (Test-Path $ModuleFile) { . $ModuleFile }

Describe "pacwin core logic" {
    
    Context "Security & Sanitization" {
        It "Allows safe package IDs" {
            _pw_sanitize "google.chrome" | Should Be "google.chrome"
            _pw_sanitize "7-zip" | Should Be "7-zip"
        }

        It "Blocks unsafe characters" {
            Mock _pw_color {}
            $res = _pw_sanitize "vlc; rm -rf /"
            $res | Should Be $null
        }
    }

    Context "Error Interpretation" {
        Mock _pw_color {}

        It "Reports success on ExitCode 0" {
            _pw_handle_result "winget" 0 @("Success")
            Assert-MockCalled _pw_color -Times 1 -ParameterFilter { $color -eq "Green" }
        }

        It "Detects Scoop failures by text parsing" {
            $output = @("Error: Couldn't find manifest")
            _pw_handle_result "scoop" 0 $output
            Assert-MockCalled _pw_color -Times 1 -ParameterFilter { $color -eq "Red" }
        }
    }

    Context "Command Dispatching" {
        Mock _pw_header {}
        Mock _pw_detect_managers { return [ordered]@{ "winget" = "C:\bin\winget.exe" } }
        Mock _pw_search_all { return @([PSCustomObject]@{ Name="VLC"; ID="VLC"; Source="winget"; Manager="winget"; Version="3" }) }
        Mock _pw_pick_source { param($r) return $r[0] }
        Mock _pw_do_install {}
        Mock _pw_color {}

        It "Dispatches search command correctly" {
            pacwin search "vlc"
            Assert-MockCalled _pw_search_all
        }
    }
}
