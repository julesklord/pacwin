@{
    ModuleVersion     = '0.1.0'
    RootModule        = 'pacwin.psm1'
    Author            = 'jules'
    Description       = 'Universal package layer for Windows — winget + chocolatey + scoop'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('pacwin')
    PrivateData       = @{
        PSData = @{
            Tags = @('package-manager','winget','chocolatey','scoop','wrapper')
        }
    }
}
