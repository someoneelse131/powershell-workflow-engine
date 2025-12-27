<#
.SYNOPSIS
    Example 03: Conditional Steps - Run Steps Based on Conditions

.DESCRIPTION
    Sometimes you only want to run a step under certain conditions.
    Conditional steps check a condition before executing.

    This example shows how to:
    - Create conditional steps
    - Use context values in conditions
    - Build branching logic in workflows

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-03-ConditionalSteps.ps1

    For interactive mode:
    .\Example-03-ConditionalSteps.ps1 -Manual
#>

param(
    [switch]$Manual
)

. "$PSScriptRoot\..\WorkflowEngine.ps1"

Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  EXAMPLE 03: Conditional Steps" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

$workflow = New-Workflow

# ============================================================================
# CONDITIONAL STEPS
# ============================================================================
# Syntax:
#   $workflow.AddConditionalStep(
#       "Step Name",                              # Name
#       { param($ctx) <return $true or $false> }, # Condition
#       { param($ctx) <action to perform> }       # Action
#   )
#
# - If condition returns $true  -> Step RUNS
# - If condition returns $false -> Step is SKIPPED

# ----------------------------------------------------------------------------
# STEP 1: Set up our scenario
# ----------------------------------------------------------------------------
# TRY CHANGING THIS VALUE to see different steps execute!
$targetEnvironment = "production"  # Try: "development", "staging", "production"

# Store in workflow context before starting
$workflow.Context.Set("environment", $targetEnvironment)

$workflow.AddStep("Initialize Deployment", {
    param($ctx)
    
    $env = $ctx.Get("environment")
    Write-Host "  Target environment: $env"
    $ctx.Set("version", "2.1.0")
    $ctx.Set("hasTests", $true)
    $ctx.Set("errorCount", 0)
})

# ----------------------------------------------------------------------------
# STEP 2: Conditional - Only for Development
# ----------------------------------------------------------------------------
$workflow.AddConditionalStep(
    "Development Setup",
    # Condition: Only run if environment is "development"
    { 
        param($ctx) 
        $ctx.Get("environment") -eq "development" 
    },
    # Action: What to do
    { 
        param($ctx)
        Write-Host "  [DEV] Enabling debug mode..."
        Write-Host "  [DEV] Skipping SSL verification..."
        Write-Host "  [DEV] Using local database..."
        $ctx.Set("debugMode", $true)
    }
)

# ----------------------------------------------------------------------------
# STEP 3: Conditional - Only for Staging
# ----------------------------------------------------------------------------
$workflow.AddConditionalStep(
    "Staging Setup",
    { 
        param($ctx) 
        $ctx.Get("environment") -eq "staging" 
    },
    { 
        param($ctx)
        Write-Host "  [STAGING] Connecting to staging database..."
        Write-Host "  [STAGING] Loading test data..."
        Write-Host "  [STAGING] Enabling performance monitoring..."
    }
)

# ----------------------------------------------------------------------------
# STEP 4: Conditional - Only for Production (with WARNING)
# ----------------------------------------------------------------------------
$workflow.AddConditionalStep(
    "Production Warning",
    { 
        param($ctx) 
        $ctx.Get("environment") -eq "production" 
    },
    { 
        param($ctx)
        Write-Host ""
        Write-Host "  +===============================================+" -ForegroundColor Red
        Write-Host "  |  WARNING: PRODUCTION DEPLOYMENT               |" -ForegroundColor Red
        Write-Host "  |                                               |" -ForegroundColor Red
        Write-Host "  |  You are about to deploy to PRODUCTION!       |" -ForegroundColor Red
        Write-Host "  |  This will affect real users.                 |" -ForegroundColor Red
        Write-Host "  +===============================================+" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Waiting 3 seconds before proceeding..." -ForegroundColor Yellow
        Start-Sleep 3
    }
)

# ----------------------------------------------------------------------------
# STEP 5: Conditional - Run tests only if hasTests is true
# ----------------------------------------------------------------------------
$workflow.AddConditionalStep(
    "Run Test Suite",
    { 
        param($ctx) 
        $ctx.Get("hasTests") -eq $true 
    },
    { 
        param($ctx)
        Write-Host "  Running automated tests..."
        Write-Host "    [PASS] Unit tests passed (142 tests)"
        Write-Host "    [PASS] Integration tests passed (38 tests)"
        Write-Host "    [PASS] Smoke tests passed (12 tests)"
        $ctx.Set("testsPassed", $true)
    }
)

# ----------------------------------------------------------------------------
# STEP 6: Conditional - Complex condition with multiple checks
# ----------------------------------------------------------------------------
$workflow.AddConditionalStep(
    "Deploy Application",
    { 
        param($ctx)
        # Multiple conditions: tests must pass AND no errors
        $testsPassed = $ctx.Get("testsPassed")
        $errorCount = $ctx.Get("errorCount")
        
        return ($testsPassed -eq $true) -and ($errorCount -eq 0)
    },
    { 
        param($ctx)
        $env = $ctx.Get("environment")
        $version = $ctx.Get("version")
        
        Write-Host "  Deploying version $version to $env..."
        Start-Sleep 1
        Write-Host "  Deployment successful!"
    }
)

# ----------------------------------------------------------------------------
# STEP 7: This always runs (regular step)
# ----------------------------------------------------------------------------
$workflow.AddStep("Send Notification", {
    param($ctx)
    
    $env = $ctx.Get("environment")
    $version = $ctx.Get("version")
    
    Write-Host "  Sending notification..."
    Write-Host "  -> Team notified of deployment to $env (v$version)"
})

# Execute
if ($Manual) {
    $workflow.ExecuteInteractive()
} else {
    $workflow.Execute()
    $workflow.PrintSummary()
}

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Yellow
Write-Host "  TIP: Change the targetEnvironment variable at the top" -ForegroundColor Yellow
Write-Host "  to 'development' or 'staging' and run again to see" -ForegroundColor Yellow
Write-Host "  different steps execute!" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Yellow

<#
WHAT YOU LEARNED:
-----------------
1. AddConditionalStep(name, condition, action) - Creates a conditional step
2. Condition must return $true or $false
3. If condition returns $false, step is SKIPPED (not failed)
4. You can use ctx.Get() in conditions to make decisions based on earlier steps
5. Complex conditions can combine multiple checks with -and / -or

COMMON PATTERNS:
----------------
- Environment-specific steps (dev/staging/prod)
- Feature flags using ctx.Get
- Error handling (skip if previous step failed)
- User preferences or configuration
- Time-based conditions (only run during maintenance window)

NEXT: Example-04-ParallelExecution.ps1 - Learn how to run steps simultaneously
#>
