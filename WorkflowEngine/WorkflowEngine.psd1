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
    Author = 'Florian Chiaruzzi'
    
    # Company or vendor of this module
    CompanyName = 'Florian Chiaruzzi'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 Florian Chiaruzzi. MIT License.'
    
    # Description of the functionality provided by this module
    Description = 'A powerful workflow engine for PowerShell with support for sequential, parallel, and conditional execution. Features include automatic retries, timeouts, context sharing, dependency management, and interactive execution mode for debugging and selective step execution.'
    
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
            Tags = @('Workflow', 'Automation', 'Parallel', 'Pipeline', 'Orchestration', 'Tasks', 'CI-CD', 'DevOps', 'Debugging', 'ETL', 'DataProcessing', 'BatchProcessing', 'Deployment', 'BuildAutomation')
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/someoneelse131/powershell-workflow-engine/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/someoneelse131/powershell-workflow-engine'
            
            # A URL to an icon representing this module
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'

## 1.0.1 - Project Link fix

## 1.0.0 - Initial Release
### Core Features
- Sequential workflow execution with automatic ordering
- Parallel execution using efficient runspace pools (4x faster than jobs)
- Conditional steps with runtime condition evaluation
- Step dependency management for complex workflows

### Error Handling & Reliability
- Configurable retry logic at both step and workflow levels
- Step timeouts to prevent runaway operations
- ContinueOnError mode for fault-tolerant workflows
- Comprehensive error reporting and logging

### Developer Experience
- Interactive execution mode - select and run specific steps interactively
- Context sharing between steps for data passing
- Detailed execution summaries with timing information
- Extensive examples covering all features (9 examples + real-world scenarios)

### Performance
- Runspace pool-based parallel execution
- Configurable parallelism limits
- Efficient context synchronization

See full documentation and examples at: https://github.com/someoneelse131/powershell-workflow-engine
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