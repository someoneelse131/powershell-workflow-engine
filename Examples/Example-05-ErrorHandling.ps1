<#
.SYNOPSIS
    Example 05: Error Handling - Retries and Failure Recovery

.DESCRIPTION
    Real-world tasks can fail. The workflow engine provides automatic retries
    at both the step level and workflow level.

    This example shows how to:
    - Configure step retries
    - Handle expected failures
    - Use ContinueOnError
    - Configure workflow-level retries

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-05-ErrorHandling.ps1

    For interactive mode:
    .\Example-05-ErrorHandling.ps1 -Manual
#>

param(
    [switch]$Manual
)

Import-Module WorkflowEngine

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  EXAMPLE 05: Error Handling & Retries" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PART 1: Step-Level Retries
# ============================================================================
Write-Host "PART 1: Step-Level Retries" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Yellow
Write-Host ""

$workflow1 = New-Workflow

# Simulate a flaky operation that fails sometimes
$script:attemptCount = 0

$step = $workflow1.AddStep("Flaky API Call", {
    param($ctx)
    
    $script:attemptCount++
    Write-Host "  Attempt $($script:attemptCount): Calling external API..."
    
    # Simulate: Fail on attempts 1 and 2, succeed on attempt 3
    if ($script:attemptCount -lt 3) {
        throw "Connection timeout - server not responding"
    }
    
    Write-Host "  API call successful!"
    $ctx.Set("apiResult", "Data from API")
})

# Configure retries
$step.Retries = 5        # Try up to 5 times
$step.RetryDelay = 1     # Wait 1 second between retries (normally you'd use 30+)

if ($Manual) {
    $workflow1.ExecuteInteractive()
} else {
    $workflow1.Execute()
}
Write-Host ""

# ============================================================================
# PART 2: Different Ways Steps Can Fail
# ============================================================================
Write-Host "PART 2: Ways Steps Can Fail" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Yellow
Write-Host ""

$workflow2 = New-Workflow

# Method 1: Throwing an exception
$workflow2.AddStep("Method 1: Throw Exception", {
    param($ctx)
    Write-Host "  This step throws an exception..."
    # throw "Something went wrong!"  # Uncomment to see it fail
    Write-Host "  (Exception line is commented out, so it succeeds)"
})

# Method 2: Returning $false
$workflow2.AddStep("Method 2: Return False", {
    param($ctx)
    Write-Host "  This step returns `$false to indicate failure..."
    
    $success = $true  # Change to $false to see failure
    
    if (-not $success) {
        Write-Host "  Validation failed!"
        return $false  # <-- This marks the step as FAILED
    }
    
    Write-Host "  Validation passed!"
    # No return (or return $true) = success
})

# Method 3: Checking results and failing conditionally
$workflow2.AddStep("Method 3: Conditional Failure", {
    param($ctx)
    Write-Host "  Checking system requirements..."
    
    # Simulate checking something
    $diskSpace = 100  # GB available (change to 5 to see failure)
    $requiredSpace = 10  # GB required
    
    if ($diskSpace -lt $requiredSpace) {
        Write-Host "  ERROR: Not enough disk space ($diskSpace GB < $requiredSpace GB)"
        return $false
    }
    
    Write-Host "  Disk space OK: $diskSpace GB available"
})

if ($Manual) {
    $workflow2.ExecuteInteractive()
} else {
    $workflow2.Execute()
}
Write-Host ""

# ============================================================================
# PART 3: ContinueOnError - Keep Going After Failures
# ============================================================================
Write-Host "PART 3: ContinueOnError Mode" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Yellow
Write-Host ""

# With ContinueOnError = $true, workflow keeps going even if steps fail
$workflow3 = New-Workflow -ContinueOnError $true

$workflow3.AddStep("Step 1: Succeeds", {
    param($ctx)
    Write-Host "  Step 1 running..."
})

$failingStep = $workflow3.AddStep("Step 2: FAILS", {
    param($ctx)
    Write-Host "  Step 2 running... about to fail!"
    throw "Intentional failure!"
})
$failingStep.Retries = 1  # Only try once (faster for demo)

$workflow3.AddStep("Step 3: Still Runs!", {
    param($ctx)
    Write-Host "  Step 3 running despite Step 2 failing!"
    Write-Host "  (Because ContinueOnError = `$true)"
})

$workflow3.AddStep("Step 4: Also Runs", {
    param($ctx)
    Write-Host "  Step 4 completing the workflow..."
})

if ($Manual) {
    $workflow3.ExecuteInteractive()
} else {
    $workflow3.Execute()
}
$workflow3.PrintSummary()

Write-Host ""

# ============================================================================
# PART 4: Workflow-Level Retries
# ============================================================================
Write-Host "PART 4: Workflow-Level Retries" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Yellow
Write-Host ""

$script:workflowAttempt = 0

# Workflow will retry up to 3 times with 2 second delay
$workflow4 = New-Workflow -WorkflowRetries 3 -WorkflowDelay 2

$workflow4.AddStep("Prepare", {
    param($ctx)
    Write-Host "  Preparing resources..."
})

$failStep = $workflow4.AddStep("Critical Operation", {
    param($ctx)
    
    $script:workflowAttempt++
    Write-Host "  Workflow attempt: $($script:workflowAttempt)"
    
    # Fail on first 2 workflow attempts, succeed on 3rd
    if ($script:workflowAttempt -lt 3) {
        throw "Critical failure - entire workflow must retry"
    }
    
    Write-Host "  Critical operation succeeded!"
})
$failStep.Retries = 1  # Step only tries once, but workflow retries

$workflow4.AddStep("Finalize", {
    param($ctx)
    Write-Host "  Finalizing..."
})

if ($Manual) {
    $workflow4.ExecuteInteractive()
} else {
    $workflow4.Execute()
}
Write-Host ""

# ============================================================================
# PART 5: Practical Error Handling Pattern
# ============================================================================
Write-Host "PART 5: Practical Error Handling Pattern" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Yellow
Write-Host ""

$workflow5 = New-Workflow

$workflow5.AddStep("Safe Database Operation", {
    param($ctx)
    
    Write-Host "  Performing database operation with error handling..."
    
    try {
        # Simulate database operation
        $result = @{
            RecordsUpdated = 42
            Success = $true
        }
        
        # Validate result
        if ($result.RecordsUpdated -eq 0) {
            Write-Host "  WARNING: No records were updated"
            return $false
        }
        
        $ctx.Set("dbResult", $result)
        Write-Host "  Updated $($result.RecordsUpdated) records"
        
    } catch {
        # Log the error
        Write-Host "  ERROR: Database operation failed - $_" -ForegroundColor Red
        
        # Store error for later analysis
        $ctx.Set("lastError", $_.ToString())
        
        # Return false OR rethrow to trigger retry
        return $false
    }
})

$workflow5.AddStep("Check Results", {
    param($ctx)
    
    $dbResult = $ctx.Get("dbResult")
    $lastError = $ctx.Get("lastError")
    
    if ($lastError) {
        Write-Host "  Previous step had an error: $lastError" -ForegroundColor Yellow
    } elseif ($dbResult) {
        Write-Host "  Database operation was successful"
        Write-Host "  Records updated: $($dbResult.RecordsUpdated)"
    }
})

if ($Manual) {
    $workflow5.ExecuteInteractive()
} else {
    $workflow5.Execute()
}

<#
WHAT YOU LEARNED:
-----------------

STEP-LEVEL RETRIES:
- step.Retries = N  -> Try step up to N times
- step.RetryDelay = S  -> Wait S seconds between retries
- Step fails when all retries exhausted

WAYS TO FAIL A STEP:
- throw an error message  -> Immediate failure, triggers retry
- return $false  -> Marks step as failed, triggers retry
- Any uncaught exception  -> Failure

WORKFLOW-LEVEL OPTIONS:
- WorkflowRetries -> Retry entire workflow N times
- WorkflowDelay -> Seconds between workflow retries
- ContinueOnError -> If $true, continue after step failures

BEST PRACTICES:
---------------
1. Use try/catch for external operations (APIs, files, databases)
2. Return $false for validation failures
3. Use throw for unexpected errors
4. Set reasonable retry counts (3-5 for network, 1-2 for validation)
5. Use longer delays for transient failures (30-60 seconds)
6. Log errors to context for debugging

NEXT: Example-06-RealWorld-Deployment.ps1 - A complete real-world example
#>
