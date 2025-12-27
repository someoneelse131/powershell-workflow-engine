<#
.SYNOPSIS
    Example 08: Configuration Options - All Parameters You Can Change

.DESCRIPTION
    This example shows ALL configurable parameters for workflows, steps,
    and parallel groups. Use this as a reference for customizing behavior.

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-08-ConfigurationOptions.ps1

    For interactive mode:
    .\Example-08-ConfigurationOptions.ps1 -Manual
#>

param(
    [switch]$Manual
)

. "$PSScriptRoot\..\WorkflowEngine.ps1"

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  EXAMPLE 08: All Configuration Options" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# SECTION 1: WORKFLOW-LEVEL OPTIONS
# ============================================================================

Write-Host "SECTION 1: WORKFLOW-LEVEL OPTIONS" -ForegroundColor Yellow
Write-Host ("-" * 50) -ForegroundColor Yellow
Write-Host ""

Write-Host @"
  +------------------+------+---------+----------------------------------------------+
  | Parameter        | Type | Default | Description                                  |
  +------------------+------+---------+----------------------------------------------+
  | WorkflowRetries  | int  | 1       | How many times to retry the ENTIRE workflow  |
  | WorkflowDelay    | int  | 60      | Seconds to wait between workflow retries     |
  | ContinueOnError  | bool | false   | Keep running after a step fails?             |
  +------------------+------+---------+----------------------------------------------+
"@
Write-Host ""

# Example: Create workflow with all options
$workflow1 = New-Workflow `
    -WorkflowRetries 3 `
    -WorkflowDelay 30 `
    -ContinueOnError $false

Write-Host "  Created workflow with:"
Write-Host "    WorkflowRetries:  $($workflow1.WorkflowRetries) (retry entire workflow up to 3 times)"
Write-Host "    WorkflowDelay:    $($workflow1.WorkflowDelay) seconds (wait between workflow retries)"
Write-Host "    ContinueOnError:  $($workflow1.ContinueOnError) (stop on first failure)"
Write-Host ""

# You can also modify these after creation:
$workflow1.WorkflowRetries = 5
$workflow1.WorkflowDelay = 120
$workflow1.ContinueOnError = $true

Write-Host "  Modified after creation:"
Write-Host "    WorkflowRetries:  $($workflow1.WorkflowRetries)"
Write-Host "    WorkflowDelay:    $($workflow1.WorkflowDelay) seconds"
Write-Host "    ContinueOnError:  $($workflow1.ContinueOnError)"
Write-Host ""

# ============================================================================
# SECTION 2: STEP-LEVEL OPTIONS
# ============================================================================

Write-Host "SECTION 2: STEP-LEVEL OPTIONS" -ForegroundColor Yellow
Write-Host ("-" * 50) -ForegroundColor Yellow
Write-Host ""

Write-Host @"
  +-------------+------+---------+----------------------------------------------+
  | Property    | Type | Default | Description                                  |
  +-------------+------+---------+----------------------------------------------+
  | Retries     | int  | 3       | How many times to retry THIS step            |
  | RetryDelay  | int  | 30      | Seconds to wait between step retries         |
  | Timeout     | int  | 0       | Max seconds to run (0 = no timeout/forever)  |
  +-------------+------+---------+----------------------------------------------+

  NOTE: Timeout = 0 means the step can run FOREVER until it completes or fails.
        Set a Timeout when calling external APIs, databases, or any operation
        that might hang indefinitely.
"@
Write-Host ""

$workflow2 = New-Workflow

# Example: Configure step retries
$step1 = $workflow2.AddStep("API Call with Many Retries", {
    param($ctx)
    Write-Host "    Calling flaky API..."
})

$step1.Retries = 10        # Try up to 10 times
$step1.RetryDelay = 5      # Wait 5 seconds between retries
$step1.Timeout = 30        # Kill the step if it takes more than 30 seconds

Write-Host "  Step: $($step1.Name)"
Write-Host "    Retries:    $($step1.Retries) (try up to 10 times)"
Write-Host "    RetryDelay: $($step1.RetryDelay) seconds (wait between retries)"
Write-Host "    Timeout:    $($step1.Timeout) seconds (max time per attempt)"
Write-Host ""

# Example: Step with minimal retries (for fast-failing validation)
$step2 = $workflow2.AddStep("Quick Validation", {
    param($ctx)
    Write-Host "    Validating input..."
})

$step2.Retries = 1         # Only try once
$step2.RetryDelay = 0      # No delay needed
$step2.Timeout = 5         # Should complete in 5 seconds or fail

Write-Host "  Step: $($step2.Name)"
Write-Host "    Retries:    $($step2.Retries) (fail immediately, no retries)"
Write-Host "    RetryDelay: $($step2.RetryDelay) seconds"
Write-Host "    Timeout:    $($step2.Timeout) seconds"
Write-Host ""

# Example: Long-running step with no timeout
$step3 = $workflow2.AddStep("Database Migration", {
    param($ctx)
    Write-Host "    Running migration..."
})

$step3.Retries = 1
$step3.Timeout = 0         # No timeout - let it run as long as needed

Write-Host "  Step: $($step3.Name)"
Write-Host "    Retries:    $($step3.Retries)"
Write-Host "    Timeout:    $($step3.Timeout) (0 = no timeout, runs forever)"
Write-Host ""

# ============================================================================
# SECTION 3: PARALLEL GROUP OPTIONS
# ============================================================================

Write-Host "SECTION 3: PARALLEL GROUP OPTIONS" -ForegroundColor Yellow
Write-Host ("-" * 50) -ForegroundColor Yellow
Write-Host ""

Write-Host @"
  +----------------+------+---------+----------------------------------------------+
  | Property       | Type | Default | Description                                  |
  +----------------+------+---------+----------------------------------------------+
  | MaxParallelism | int  | 5       | Max steps running at the same time           |
  +----------------+------+---------+----------------------------------------------+

  NOTE: Parallel steps currently do NOT support Timeout.
        Timeout only works for sequential steps.
"@
Write-Host ""

$workflow3 = New-Workflow

# Example: Unlimited parallelism (all at once)
$group1 = $workflow3.AddParallelGroup("Download All Files")
$group1.MaxParallelism = 100  # Effectively unlimited

Write-Host "  Group: $($group1.Name)"
Write-Host "    MaxParallelism: $($group1.MaxParallelism) (all steps run at once)"
Write-Host ""

# Example: Limited parallelism (resource constraints)
$group2 = $workflow3.AddParallelGroup("CPU-Intensive Tasks")
$group2.MaxParallelism = 2    # Only 2 at a time

Write-Host "  Group: $($group2.Name)"
Write-Host "    MaxParallelism: $($group2.MaxParallelism) (limit CPU usage)"
Write-Host ""

# ============================================================================
# SECTION 4: TIMEOUT DEMONSTRATION
# ============================================================================

Write-Host "SECTION 4: TIMEOUT DEMONSTRATION" -ForegroundColor Yellow
Write-Host ("-" * 50) -ForegroundColor Yellow
Write-Host ""
Write-Host "Running steps with timeout configured..." -ForegroundColor Cyan
Write-Host ""

$timeoutDemo = New-Workflow -ContinueOnError $true

# Step that completes within timeout
$fastStep = $timeoutDemo.AddStep("Fast Step (completes in time)", {
    param($ctx)
    Write-Host "    Working for 1 second..."
    Start-Sleep -Seconds 1
    Write-Host "    Done!"
})
$fastStep.Timeout = 5  # 5 second timeout, but only takes 1 second
$fastStep.Retries = 1

# Step that will timeout
$slowStep = $timeoutDemo.AddStep("Slow Step (will timeout)", {
    param($ctx)
    Write-Host "    Working for 10 seconds..."
    Start-Sleep -Seconds 10  # Takes 10 seconds
    Write-Host "    Done!"
})
$slowStep.Timeout = 3  # Only allow 3 seconds - will timeout!
$slowStep.Retries = 1

# Step without timeout (runs normally)
$normalStep = $timeoutDemo.AddStep("Normal Step (no timeout)", {
    param($ctx)
    Write-Host "    Working for 2 seconds..."
    Start-Sleep -Seconds 2
    Write-Host "    Done!"
})
$normalStep.Timeout = 0  # No timeout
$normalStep.Retries = 1

if ($Manual) {
    $timeoutDemo.ExecuteInteractive()
} else {
    $timeoutDemo.Execute()
    $timeoutDemo.PrintSummary()
}

# ============================================================================
# SECTION 5: CONTEXT PRE-LOADING
# ============================================================================

Write-Host "SECTION 5: CONTEXT PRE-LOADING" -ForegroundColor Yellow
Write-Host ("-" * 50) -ForegroundColor Yellow
Write-Host ""

Write-Host @"
  The workflow has a Context property you can use BEFORE execution.
  This is how you pass external variables into steps!

  METHODS:
  --------
  Before workflow runs:   `$workflow.Context.Set("key", `$value)
  Inside steps:           `$ctx.Get("key")
"@
Write-Host ""

$workflow4 = New-Workflow

# Pre-load configuration BEFORE adding steps
$workflow4.Context.Set("environment", "production")
$workflow4.Context.Set("version", "1.2.3")
$workflow4.Context.Set("debugMode", $false)
$workflow4.Context.Set("maxConnections", 100)

Write-Host "  Pre-loaded context values:"
Write-Host "    environment:    $($workflow4.Context.Get('environment'))"
Write-Host "    version:        $($workflow4.Context.Get('version'))"
Write-Host "    debugMode:      $($workflow4.Context.Get('debugMode'))"
Write-Host "    maxConnections: $($workflow4.Context.Get('maxConnections'))"
Write-Host ""

# ============================================================================
# SECTION 6: QUICK REFERENCE CARD
# ============================================================================

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host "  QUICK REFERENCE CARD" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host ""

Write-Host @"
  WORKFLOW OPTIONS (New-Workflow or modify after):
  -------------------------------------------------
  WorkflowRetries     Default: 1      Retry entire workflow N times
  WorkflowDelay       Default: 60     Seconds between workflow retries
  ContinueOnError     Default: false  Continue after step failure?

  STEP OPTIONS (after AddStep):
  -------------------------------------------------
  Retries             Default: 3      Retry this step N times
  RetryDelay          Default: 30     Seconds between step retries
  Timeout             Default: 0      Max seconds (0 = no timeout)

  PARALLEL GROUP OPTIONS (after AddParallelGroup):
  -------------------------------------------------
  MaxParallelism      Default: 5      Max concurrent steps

  CONTEXT (for passing external variables):
  -------------------------------------------------
  Before execution:   `$workflow.Context.Set("key", `$value)
  Inside steps:       `$ctx.Get("key")

  TYPICAL CONFIGURATIONS:
  -------------------------------------------------
  Fast validation:     Retries=1, RetryDelay=0, Timeout=5
  Network calls:       Retries=5, RetryDelay=30, Timeout=60
  Rate-limited API:    Retries=3, RetryDelay=60, Timeout=120
  Database queries:    Retries=2, RetryDelay=5, Timeout=300
  Long-running task:   Retries=1, Timeout=0 (no limit)
  Critical workflow:   WorkflowRetries=3, ContinueOnError=false
  Best-effort:         WorkflowRetries=1, ContinueOnError=true
  CPU-limited:         MaxParallelism=2
  I/O-heavy parallel:  MaxParallelism=10
"@

Write-Host ""
Write-Host @"

  WHAT HAPPENS WITH NO TIMEOUT (Timeout = 0)?
  -------------------------------------------
  - Step runs INDEFINITELY until it completes, fails, or is cancelled (Ctrl+C)
  - This is the DEFAULT behavior
  - Use for steps that MUST complete (database migrations, file operations)
  - Risky for network calls that might hang forever

  WHAT HAPPENS WHEN A STEP TIMES OUT?
  -----------------------------------
  - Step is forcefully stopped
  - Counts as a FAILURE
  - Step will RETRY if Retries > 1
  - Workflow continues or stops based on ContinueOnError

"@
