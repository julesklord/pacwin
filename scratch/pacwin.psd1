@{
    ModuleVersion     = '0.2.0'
    RootModule        = 'pacwin.psm1'
    Author            = 'julesklord'
    Description       = 'Universal package layer for Windows — winget + chocolatey + scoop'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('pacwin')
    PrivateData       = @{
        PSData = @{
            Tags = @('package-manager','winget','chocolatey','scoop','wrapper')
        }
    }
}
