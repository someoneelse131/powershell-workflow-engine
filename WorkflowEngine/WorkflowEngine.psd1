@{
    # Script module file associated with this manifest
    RootModule = 'WorkflowEngine.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'Your Name'
    
    # Company or vendor of this module
    CompanyName = 'Unknown'
    
    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'A powerful workflow engine for PowerShell with support for sequential, parallel, and conditional execution. Features include retry logic, timeouts, context sharing between steps, and interactive execution mode.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module
    FunctionsToExport = @(
        'New-Workflow',
        'New-WorkflowStep'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discoverability in online galleries
            Tags = @('Workflow', 'Automation', 'Parallel', 'Pipeline', 'Orchestration', 'Tasks')
            
            # A URL to the license for this module
            # LicenseUri = ''
            
            # A URL to the main website for this project
            # ProjectUri = ''
            
            # A URL to an icon representing this module
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
## 1.0.0
- Initial release
- Sequential workflow execution
- Parallel execution with runspace pools
- Conditional steps
- Retry logic with configurable attempts and delays
- Step timeouts
- Context sharing between steps
- Interactive execution mode
- Workflow summary and reporting
'@
            
            # Prerelease string of this module
            # Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }
}
