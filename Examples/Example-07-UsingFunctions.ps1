<#
.SYNOPSIS
    Example 07: Using Functions - Organize Your Workflow Code

.DESCRIPTION
    As workflows grow, you will want to organize code into reusable functions.
    This example shows different patterns for using functions with workflows.
    
    This example demonstrates:
    - Defining helper functions
    - Functions that return success/failure
    - Functions that work with context
    - Organizing code in separate files

.NOTES
    Run this script from PowerShell:
    .\Example-07-UsingFunctions.ps1
#>

. "$PSScriptRoot\..\WorkflowEngine.ps1"

Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  EXAMPLE 07: Using Functions in Workflows" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PATTERN 1: Simple Helper Functions
# ============================================================================
# Define functions BEFORE creating the workflow
# These are available in all sequential steps

function Write-StepHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "  +-------------------------------------" -ForegroundColor DarkGray
    Write-Host "  | $Title" -ForegroundColor White
    Write-Host "  +-------------------------------------" -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Cyan
}

# ============================================================================
# PATTERN 2: Functions That Return Success/Failure
# ============================================================================
# Return $true for success, $false for failure
# These can be used directly as the step result

function Test-ServerConnection {
    param(
        [string]$ServerName,
        [int]$Port = 80
    )
    
    Write-Info "Testing connection to ${ServerName}:${Port}..."
    
    # Simulate connection test
    Start-Sleep -Milliseconds 500
    
    # In real code: Test-NetConnection $ServerName -Port $Port
    $connected = $true  # Simulate success
    
    if ($connected) {
        Write-Success "Connected to ${ServerName}:${Port}"
        return $true
    } else {
        Write-Failure "Cannot connect to ${ServerName}:${Port}"
        return $false
    }
}

function Invoke-DatabaseBackup {
    param(
        [string]$DatabaseName,
        [string]$BackupPath
    )
    
    Write-Info "Backing up database '$DatabaseName'..."
    
    try {
        # Simulate backup operation
        Start-Sleep 1
        
        $backupFile = Join-Path $BackupPath "$DatabaseName-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        
        Write-Success "Backup created: $backupFile"
        return @{
            Success = $true
            BackupFile = $backupFile
            Size = "2.4 GB"
        }
    }
    catch {
        Write-Failure "Backup failed: $_"
        return @{
            Success = $false
            Error = $_.ToString()
        }
    }
}

function Send-TeamNotification {
    param(
        [string]$Channel,
        [string]$Message,
        [string]$Priority = "normal"
    )
    
    $icon = switch ($Priority) {
        "high" { "[!!!]" }
        "normal" { "[i]" }
        "low" { "[.]" }
    }
    
    Write-Info "Sending to #$Channel..."
    Start-Sleep -Milliseconds 300
    Write-Success "Sent: $icon $Message"
    
    return $true
}

# ============================================================================
# PATTERN 3: Functions That Work With Context
# ============================================================================
# Pass $ctx as a parameter to read/write shared data

function Initialize-DeploymentContext {
    param($ctx, [string]$Environment, [string]$Version)
    
    Write-StepHeader "Initializing Deployment"
    
    $ctx.Set("environment", $Environment)
    $ctx.Set("version", $Version)
    $ctx.Set("startTime", (Get-Date))
    $ctx.Set("deploymentId", "DEP-" + [Guid]::NewGuid().ToString().Substring(0, 8).ToUpper())
    
    Write-Info "Environment: $Environment"
    Write-Info "Version: $Version"
    Write-Info "Deployment ID: $($ctx.Get('deploymentId'))"
    
    return $true
}

function Get-DeploymentSummary {
    param($ctx)
    
    Write-StepHeader "Deployment Summary"
    
    $env = $ctx.Get("environment")
    $version = $ctx.Get("version")
    $deploymentId = $ctx.Get("deploymentId")
    $startTime = $ctx.Get("startTime")
    $backupResult = $ctx.Get("backupResult")
    
    $duration = (Get-Date) - $startTime
    
    Write-Host ""
    Write-Host "  +============================================+" -ForegroundColor Green
    Write-Host "  |         DEPLOYMENT COMPLETE                |" -ForegroundColor Green
    Write-Host "  +============================================+" -ForegroundColor Green
    Write-Host "  |  ID:          $deploymentId                  |" -ForegroundColor Green
    Write-Host "  |  Environment: $($env.PadRight(27))|" -ForegroundColor Green
    Write-Host "  |  Version:     $($version.PadRight(27))|" -ForegroundColor Green
    Write-Host "  |  Duration:    $($duration.ToString('mm\:ss').PadRight(27))|" -ForegroundColor Green
    if ($backupResult) {
        Write-Host "  |  Backup:      $($backupResult.Size.PadRight(27))|" -ForegroundColor Green
    }
    Write-Host "  +============================================+" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# PATTERN 4: Validation Functions
# ============================================================================

function Test-Prerequisites {
    param([string[]]$Requirements)
    
    Write-StepHeader "Checking Prerequisites"
    
    $allMet = $true
    
    foreach ($req in $Requirements) {
        # Simulate checking requirements
        $met = $true  # In reality, check if tool/service exists
        
        if ($met) {
            Write-Success "$req - Available"
        } else {
            Write-Failure "$req - Missing!"
            $allMet = $false
        }
    }
    
    return $allMet
}

# ============================================================================
# NOW USE THE FUNCTIONS IN A WORKFLOW
# ============================================================================

Write-Host ""
Write-Host "Creating workflow with functions..." -ForegroundColor Yellow
Write-Host ""

$workflow = New-Workflow

# Step 1: Initialize (using function with context)
$workflow.AddStep("Initialize", {
    param($ctx)
    Initialize-DeploymentContext -ctx $ctx -Environment "staging" -Version "3.2.1"
})

# Step 2: Check prerequisites (using validation function)
$workflow.AddStep("Check Prerequisites", {
    param($ctx)
    Test-Prerequisites -Requirements @("Git", "Docker", "kubectl", "Helm")
})

# Step 3: Test connections (using simple function)
$workflow.AddStep("Test Connections", {
    param($ctx)
    
    Write-StepHeader "Testing Connections"
    
    $dbOk = Test-ServerConnection -ServerName "database.example.com" -Port 5432
    $apiOk = Test-ServerConnection -ServerName "api.example.com" -Port 443
    $cacheOk = Test-ServerConnection -ServerName "redis.example.com" -Port 6379
    
    if (-not ($dbOk -and $apiOk -and $cacheOk)) {
        return $false
    }
})

# Step 4: Backup (using function that returns complex result)
$workflow.AddStep("Backup Database", {
    param($ctx)
    
    Write-StepHeader "Database Backup"
    
    $result = Invoke-DatabaseBackup -DatabaseName "MyAppDB" -BackupPath "C:\Backups"
    
    if ($result.Success) {
        $ctx.Set("backupResult", $result)
        return $true
    } else {
        return $false
    }
})

# Step 5: Deploy (simulated)
$workflow.AddStep("Deploy Application", {
    param($ctx)
    
    Write-StepHeader "Deploying"
    
    $version = $ctx.Get("version")
    Write-Info "Deploying version $version..."
    
    Start-Sleep 1
    
    Write-Success "Application deployed!"
})

# Step 6: Notify (using notification function)
$workflow.AddStep("Send Notifications", {
    param($ctx)
    
    Write-StepHeader "Notifications"
    
    $env = $ctx.Get("environment")
    $version = $ctx.Get("version")
    
    Send-TeamNotification -Channel "deployments" -Message "Deployed v$version to $env" -Priority "normal"
    Send-TeamNotification -Channel "engineering" -Message "v$version is live!" -Priority "low"
})

# Step 7: Summary (using context-aware function)
$workflow.AddStep("Generate Summary", {
    param($ctx)
    Get-DeploymentSummary -ctx $ctx
})

# Execute
$workflow.Execute()
$workflow.PrintSummary()

<#
PATTERNS DEMONSTRATED:
----------------------

1. HELPER FUNCTIONS
   - Simple output formatting
   - Reusable across all steps
   
   function Write-Success { param($Message) ... }

2. FUNCTIONS RETURNING SUCCESS/FAILURE
   - Return $true or $false
   - Can return as step result
   
   function Test-Something { 
       return $true  # or $false 
   }

3. FUNCTIONS WITH CONTEXT
   - Accept $ctx parameter
   - Read/write shared data
   
   function Do-Something {
       param($ctx)
       $ctx.Set('key', 'value')
   }

4. FUNCTIONS RETURNING COMPLEX RESULTS
   - Return hashtable with multiple values
   - Store results in context
   
   function Get-Result {
       return @{ Success = $true; Data = '...' }
   }

BEST PRACTICES:
---------------
- Define functions BEFORE the workflow
- Use descriptive function names (verb-noun)
- Return $true/$false for success/failure
- Pass $ctx when function needs shared data
- Keep functions focused (single responsibility)

FOR LARGER PROJECTS:
--------------------
Put functions in a separate file:

  MyFunctions.ps1:
  function Do-Something { ... }

  MyWorkflow.ps1:
  . .\MyFunctions.ps1
  . ..\WorkflowEngine.ps1
  $workflow = New-Workflow
  ...

NOTE FOR PARALLEL STEPS:
------------------------
Functions defined outside are NOT available in parallel steps!
For parallel steps, put all logic directly in the scriptblock.
#>
