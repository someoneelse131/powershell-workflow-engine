<#
.SYNOPSIS
    Example 02: Context Sharing - Passing Data Between Steps

.DESCRIPTION
    Steps run independently, but often you need to pass data from one step
    to another. The "context" ($ctx) is a shared data store for this purpose.

    This example shows how to:
    - Store data in the context
    - Retrieve data from the context
    - Pass complex objects between steps

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-02-ContextSharing.ps1

    For interactive mode:
    .\Example-02-ContextSharing.ps1 -Manual
#>

param(
    [switch]$Manual
)

Import-Module WorkflowEngine

Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  EXAMPLE 02: Context Sharing Between Steps" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

$workflow = New-Workflow

# ============================================================================
# THE CONTEXT ($ctx)
# ============================================================================
# Think of $ctx as a shared clipboard that all steps can read and write to.
#
# Key methods:
#   $ctx.Set("key", $value)   - Store a value
#   $ctx.Get("key")           - Retrieve a value
#
# You can store ANY PowerShell object: strings, numbers, arrays, hashtables, etc.

# ----------------------------------------------------------------------------
# STEP 1: Store simple values
# ----------------------------------------------------------------------------
$workflow.AddStep("Configure Settings", {
    param($ctx)
    
    Write-Host "  Setting up configuration..."
    
    # Store simple values
    $ctx.Set("environment", "staging")
    $ctx.Set("maxRetries", 5)
    $ctx.Set("debugMode", $true)
    $ctx.Set("startTime", (Get-Date))
    
    Write-Host "  Stored: environment = staging"
    Write-Host "  Stored: maxRetries = 5"
    Write-Host "  Stored: debugMode = true"
    Write-Host "  Stored: startTime = $(Get-Date)"
})

# ----------------------------------------------------------------------------
# STEP 2: Store complex objects (arrays, hashtables)
# ----------------------------------------------------------------------------
$workflow.AddStep("Load User Data", {
    param($ctx)
    
    Write-Host "  Loading user data..."
    
    # Store an array of hashtables (like objects)
    $users = @(
        @{ Id = 1; Name = "Alice"; Role = "Admin"; Active = $true }
        @{ Id = 2; Name = "Bob"; Role = "Developer"; Active = $true }
        @{ Id = 3; Name = "Charlie"; Role = "Tester"; Active = $false }
    )
    
    $ctx.Set("users", $users)
    $ctx.Set("userCount", $users.Count)
    
    Write-Host "  Loaded $($users.Count) users into context"
})

# ----------------------------------------------------------------------------
# STEP 3: Read and use the stored data
# ----------------------------------------------------------------------------
$workflow.AddStep("Process Users", {
    param($ctx)
    
    Write-Host "  Processing users..."
    
    # Retrieve values from context
    $environment = $ctx.Get("environment")
    $debugMode = $ctx.Get("debugMode")
    $users = $ctx.Get("users")
    
    Write-Host ""
    Write-Host "  Environment: $environment"
    Write-Host "  Debug Mode: $debugMode"
    Write-Host ""
    Write-Host "  Users to process:"
    
    $activeCount = 0
    foreach ($user in $users) {
        $status = if ($user.Active) { "[ACTIVE]" } else { "[INACTIVE]" }
        Write-Host "    - $($user.Name) ($($user.Role)) $status"
        
        if ($user.Active) {
            $activeCount++
        }
    }
    
    # Store results for the next step
    $ctx.Set("activeUserCount", $activeCount)
    $ctx.Set("processedAt", (Get-Date))
    
    Write-Host ""
    Write-Host "  Found $activeCount active users"
})

# ----------------------------------------------------------------------------
# STEP 4: Generate a report using accumulated data
# ----------------------------------------------------------------------------
$workflow.AddStep("Generate Report", {
    param($ctx)
    
    Write-Host "  Generating final report..."
    Write-Host ""
    
    # Retrieve all the data we have collected
    $environment = $ctx.Get("environment")
    $startTime = $ctx.Get("startTime")
    $processedAt = $ctx.Get("processedAt")
    $totalUsers = $ctx.Get("userCount")
    $activeUsers = $ctx.Get("activeUserCount")
    
    # Calculate duration
    $duration = $processedAt - $startTime
    
    # Display report
    Write-Host "  +========================================+" -ForegroundColor Green
    Write-Host "  |         WORKFLOW REPORT                |" -ForegroundColor Green
    Write-Host "  +========================================+" -ForegroundColor Green
    Write-Host "  |  Environment:    $environment                 |" -ForegroundColor Green
    Write-Host "  |  Total Users:    $totalUsers                       |" -ForegroundColor Green
    Write-Host "  |  Active Users:   $activeUsers                       |" -ForegroundColor Green
    Write-Host "  |  Inactive Users: $($totalUsers - $activeUsers)                       |" -ForegroundColor Green
    Write-Host "  |  Duration:       $($duration.TotalSeconds.ToString('F2'))s                   |" -ForegroundColor Green
    Write-Host "  +========================================+" -ForegroundColor Green
})

# Execute the workflow
if ($Manual) {
    $workflow.ExecuteInteractive()
} else {
    $workflow.Execute()
    $workflow.PrintSummary()
}

<#
WHAT YOU LEARNED:
-----------------
1. Use $ctx.Set('key', $value) to store any value
2. Use $ctx.Get('key') to retrieve a value (returns $null if not found)
3. You can store: strings, numbers, booleans, arrays, hashtables, dates, etc.
4. Data persists across all steps in the workflow
5. Each step can both read AND write to the context

COMMON PATTERNS:
----------------
- Store configuration in early steps, use it in later steps
- Accumulate results as you go
- Store timestamps for duration calculations
- Pass file paths, connection strings, or credentials

NEXT: Example-03-ConditionalSteps.ps1 - Learn how to skip steps based on conditions
#>
