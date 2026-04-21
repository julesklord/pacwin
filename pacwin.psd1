@{
    # Generated GUID for PSGallery
    GUID              = 'f585244e-2c44-43ad-8c8c-60da9d0d2c71'
    ModuleVersion     = '0.2.4'
    RootModule        = 'pacwin.psm1'
    Author            = 'julesklord'
    CompanyName       = 'julesklord'
    Copyright         = '(c) 2026 julesklord. All rights reserved.'
    Description       = 'Universal package layer for Windows - winget + choco + scoop'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('pacwin')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    DscResourcesToExport = @()
    RequiredModules   = @()
    NestedModules     = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('package-manager','winget','chocolatey','scoop','pacman')
            ProjectUri   = 'https://github.com/julesklord/pacwin'
            LicenseUri   = 'https://github.com/julesklord/pacwin/blob/main/LICENSE'
            ReleaseNotes = 'v0.2.4: Fixed PSGallery publishing issues.'
        }
    }
}
