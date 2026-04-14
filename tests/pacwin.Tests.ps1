$ModuleFile = Join-Path $PSScriptRoot "..\pacwin.psm1"
Import-Module $ModuleFile -Force

Describe "pacwin core logic" {
    InModuleScope "pacwin" {
        It "Can load the module and run pacwin doctor" {
            pacwin doctor
            $true | Should -Be $true
        }

        Context "Security & Sanitization" {
            It "Allows safe package IDs" {
                _pw_sanitize "google.chrome" | Should -Be "google.chrome"
            }
        }
    }
}
