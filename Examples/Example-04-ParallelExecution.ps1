<#
.SYNOPSIS
    Example 04: Parallel Execution - Run Multiple Steps Simultaneously

.DESCRIPTION
    When steps don't depend on each other, you can run them in parallel
    to save time. This example shows how to create parallel groups.

    This example shows how to:
    - Create parallel groups
    - Add steps to parallel groups
    - Control maximum parallelism
    - Understand context behavior in parallel steps

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-04-ParallelExecution.ps1

    For interactive mode:
    .\Example-04-ParallelExecution.ps1 -Manual
#>

param(
    [switch]$Manual
)

. "$PSScriptRoot\..\WorkflowEngine.ps1"

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  EXAMPLE 04: Parallel Execution" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$workflow = New-Workflow

# ============================================================================
# PARALLEL GROUPS
# ============================================================================
# Syntax:
#   $parallel = $workflow.AddParallelGroup("Group Name")
#   $parallel.AddStep([WorkflowStep]::new("Step Name", { param($ctx) ... }))
#
# All steps in a parallel group run AT THE SAME TIME
# This saves time when steps are independent of each other

# ----------------------------------------------------------------------------
# STEP 1: Sequential setup (runs first, alone)
# ----------------------------------------------------------------------------
$workflow.AddStep("Prepare Build Environment", {
    param($ctx)
    
    Write-Host "  Setting up build environment..."
    $ctx.Set("buildId", "BUILD-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    $ctx.Set("startTime", (Get-Date))
    
    Write-Host "  Build ID: $($ctx.Get('buildId'))"
})

# ----------------------------------------------------------------------------
# STEP 2: Parallel group - These all run at the same time!
# ----------------------------------------------------------------------------
Write-Host ""
Write-Host "Creating parallel build group..." -ForegroundColor Yellow
Write-Host "Each build takes 2 seconds, but they run simultaneously!" -ForegroundColor Yellow
Write-Host ""

$buildGroup = $workflow.AddParallelGroup("Build All Services")

# Note: For parallel steps, we use [WorkflowStep]::new() syntax
$buildGroup.AddStep([WorkflowStep]::new("Build API Service", {
    param($ctx)
    Write-Host "  [API] Starting build..."
    Start-Sleep 2  # Simulates 2 seconds of work
    Write-Host "  [API] Build complete!"
    $ctx.Set("apiBuildStatus", "success")
}))

$buildGroup.AddStep([WorkflowStep]::new("Build Web Frontend", {
    param($ctx)
    Write-Host "  [WEB] Starting build..."
    Start-Sleep 2  # Also 2 seconds
    Write-Host "  [WEB] Build complete!"
    $ctx.Set("webBuildStatus", "success")
}))

$buildGroup.AddStep([WorkflowStep]::new("Build Mobile App", {
    param($ctx)
    Write-Host "  [MOBILE] Starting build..."
    Start-Sleep 2  # Also 2 seconds
    Write-Host "  [MOBILE] Build complete!"
    $ctx.Set("mobileBuildStatus", "success")
}))

$buildGroup.AddStep([WorkflowStep]::new("Build Worker Service", {
    param($ctx)
    Write-Host "  [WORKER] Starting build..."
    Start-Sleep 2  # Also 2 seconds
    Write-Host "  [WORKER] Build complete!"
    $ctx.Set("workerBuildStatus", "success")
}))

# 4 builds x 2 seconds each = 8 seconds if sequential
# But in parallel: ~2 seconds total!

# ----------------------------------------------------------------------------
# STEP 3: Another parallel group - Downloads
# ----------------------------------------------------------------------------
$downloadGroup = $workflow.AddParallelGroup("Download Dependencies")

$downloadGroup.AddStep([WorkflowStep]::new("Download NPM Packages", {
    param($ctx)
    Write-Host "  [NPM] Downloading packages..."
    Start-Sleep 1
    Write-Host "  [NPM] Downloaded 1,247 packages"
}))

$downloadGroup.AddStep([WorkflowStep]::new("Download NuGet Packages", {
    param($ctx)
    Write-Host "  [NUGET] Downloading packages..."
    Start-Sleep 1
    Write-Host "  [NUGET] Downloaded 89 packages"
}))

$downloadGroup.AddStep([WorkflowStep]::new("Download Docker Images", {
    param($ctx)
    Write-Host "  [DOCKER] Pulling images..."
    Start-Sleep 1
    Write-Host "  [DOCKER] Pulled 5 images"
}))

# ----------------------------------------------------------------------------
# STEP 4: Sequential step after parallel groups
# ----------------------------------------------------------------------------
$workflow.AddStep("Run Integration Tests", {
    param($ctx)
    
    Write-Host "  Running integration tests..."
    Write-Host "  (This step waits for ALL parallel builds to complete first)"
    Start-Sleep 1
    Write-Host "  All tests passed!"
    
    # Calculate total time
    $startTime = $ctx.Get("startTime")
    if ($startTime) {
        $duration = (Get-Date) - $startTime
        Write-Host "  Total pipeline time: $($duration.TotalSeconds.ToString('F1')) seconds"
    }
})

# ----------------------------------------------------------------------------
# EXECUTE AND SHOW TIMING
# ----------------------------------------------------------------------------
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ($Manual) {
    # Interactive mode - user selects which steps to run
    $workflow.ExecuteInteractive()
} else {
    # Automatic mode - run all steps
    $workflow.Execute()
}

$stopwatch.Stop()

if (-not $Manual) {
    $workflow.PrintSummary()

    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Green
    Write-Host "  TIMING ANALYSIS" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
}
Write-Host ""
Write-Host "  If all steps ran sequentially:"
Write-Host "    4 builds x 2s + 3 downloads x 1s + 1s tests = 12 seconds"
Write-Host ""
Write-Host "  With parallel execution:"
Write-Host "    Actual time: $($stopwatch.Elapsed.TotalSeconds.ToString('F1')) seconds"
Write-Host ""
Write-Host "  Time saved: ~$(12 - $stopwatch.Elapsed.TotalSeconds) seconds!" -ForegroundColor Green
Write-Host ""

<#
WHAT YOU LEARNED:
-----------------
1. $workflow.AddParallelGroup("Name") - Creates a parallel group
2. $group.AddStep([WorkflowStep]::new("Name", { ... })) - Adds step to group
3. All steps in a group run simultaneously
4. The workflow waits for ALL parallel steps to complete before continuing
5. Parallel execution can dramatically reduce total workflow time

IMPORTANT NOTES:
----------------
- Parallel steps run in separate "runspaces" (like mini processes)
- Context changes are merged AFTER all parallel steps complete
- Parallel steps CANNOT see each other's context changes during execution
- External functions may not be available in parallel steps
- Keep logic inside the scriptblock for parallel steps

CONTROLLING PARALLELISM:
------------------------
$group.MaxParallelism = 2  # Only 2 steps run at once
# Useful when you have resource limits (CPU, network, etc.)

WHEN TO USE PARALLEL:
---------------------
- Independent builds or compilations
- Multiple file downloads
- API calls to different services
- Data processing of independent datasets
- Any tasks that don't depend on each other

WHEN NOT TO USE PARALLEL:
-------------------------
- Steps that depend on each other's results
- Steps that access the same resource (file, database row)
- Steps where order matters

NEXT: Example-05-ErrorHandling.ps1 - Learn about retries and error handling
#>
