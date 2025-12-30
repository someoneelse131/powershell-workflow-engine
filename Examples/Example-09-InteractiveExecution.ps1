<#
.SYNOPSIS
    Example 09: Interactive Execution - Step-by-Step Control

.DESCRIPTION
    This example demonstrates the interactive execution mode, which allows you
    to selectively run specific steps of a workflow. This is useful for:
    - Debugging: Run only the failing step
    - Development: Test individual steps during development
    - Recovery: Skip steps that already completed and resume from a specific point
    - Exploration: Understand what each step does before running everything

    This example shows how to:
    - Run workflows interactively with ExecuteInteractive()
    - Use various selection commands (ranges, from/to, individual steps)
    - Mix sequential and parallel steps in selections
    - Understand how conditional steps work in interactive mode

.NOTES
    Run this script from PowerShell:
    .\Example-09-InteractiveExecution.ps1

    The script will present an interactive menu where you can choose which steps to run.
#>

Import-Module WorkflowEngine

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  EXAMPLE 09: Interactive Execution Mode" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "This example demonstrates the interactive workflow execution feature."
Write-Host "You'll be able to select which steps to run using various commands."
Write-Host ""
Write-Host "AVAILABLE COMMANDS:" -ForegroundColor Yellow
Write-Host "  all         - Run all steps"
Write-Host "  1,3,5       - Run specific steps (comma-separated)"
Write-Host "  2-6         - Run a range of steps"
Write-Host "  from 5      - Run from step 5 to the end"
Write-Host "  to 4        - Run from step 1 to step 4"
Write-Host "  1,3-5,9     - Mix individual steps and ranges"
Write-Host "  exit/quit/q - Exit interactive mode"
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Cyan
try {
    [void][System.Console]::ReadKey($true)
} catch {
    Read-Host
}

# ============================================================================
# CREATE THE WORKFLOW
# ============================================================================

$workflow = New-Workflow

# ============================================================================
# PHASE 1: SETUP (Sequential Steps 1-2)
# ============================================================================

$workflow.AddStep("Step 1: Initialize Environment", {
    param($ctx)
    
    Write-Host "  Setting up the environment..."
    $ctx.Set("initialized", $true)
    $ctx.Set("startTime", (Get-Date))
    
    Start-Sleep -Milliseconds 300
    Write-Host "  Environment initialized!"
})

$workflow.AddStep("Step 2: Load Configuration", {
    param($ctx)
    
    Write-Host "  Loading configuration from settings.json..."
    
    $config = @{
        DatabaseServer = "sql.example.com"
        CacheEnabled = $true
        LogLevel = "Info"
    }
    $ctx.Set("config", $config)
    
    Start-Sleep -Milliseconds 200
    Write-Host "  Configuration loaded!"
    Write-Host "    Database: $($config.DatabaseServer)"
    Write-Host "    Cache: $($config.CacheEnabled)"
})

# ============================================================================
# PHASE 2: BUILD (Parallel Steps 3-5)
# ============================================================================
# These steps run in parallel when all selected together,
# or individually if only some are selected

$buildGroup = $workflow.AddParallelGroup("Parallel Build Group")

$buildGroup.AddStep((New-WorkflowStep -Name "Step 3: Build Backend API" -Action {
    param($ctx)
    Write-Host "  [API] Compiling backend services..."
    Start-Sleep -Milliseconds 800
    $ctx.Set("apiBuilt", $true)
    Write-Host "  [API] Backend build complete!"
}))

$buildGroup.AddStep((New-WorkflowStep -Name "Step 4: Build Frontend App" -Action {
    param($ctx)
    Write-Host "  [WEB] Bundling frontend assets..."
    Start-Sleep -Milliseconds 600
    $ctx.Set("frontendBuilt", $true)
    Write-Host "  [WEB] Frontend build complete!"
}))

$buildGroup.AddStep((New-WorkflowStep -Name "Step 5: Build Worker Service" -Action {
    param($ctx)
    Write-Host "  [WORKER] Compiling background jobs..."
    Start-Sleep -Milliseconds 500
    $ctx.Set("workerBuilt", $true)
    Write-Host "  [WORKER] Worker build complete!"
}))

# ============================================================================
# PHASE 3: VALIDATE (Sequential Step 6)
# ============================================================================

$workflow.AddStep("Step 6: Validate Build Artifacts", {
    param($ctx)
    
    Write-Host "  Validating build outputs..."
    
    $api = $ctx.Get("apiBuilt")
    $frontend = $ctx.Get("frontendBuilt")
    $worker = $ctx.Get("workerBuilt")
    
    Write-Host "    API Built: $(if ($api) { 'Yes' } else { 'No (skipped)' })"
    Write-Host "    Frontend Built: $(if ($frontend) { 'Yes' } else { 'No (skipped)' })"
    Write-Host "    Worker Built: $(if ($worker) { 'Yes' } else { 'No (skipped)' })"
    
    $ctx.Set("validated", $true)
    Write-Host "  Validation complete!"
})

# ============================================================================
# PHASE 4: TEST (Parallel Steps 7-8)
# ============================================================================

$testGroup = $workflow.AddParallelGroup("Parallel Test Group")

$testGroup.AddStep((New-WorkflowStep -Name "Step 7: Run Unit Tests" -Action {
    param($ctx)
    Write-Host "  [UNIT] Running 156 unit tests..."
    Start-Sleep -Milliseconds 700
    $ctx.Set("unitTestsPassed", $true)
    Write-Host "  [UNIT] All unit tests passed!"
}))

$testGroup.AddStep((New-WorkflowStep -Name "Step 8: Run Integration Tests" -Action {
    param($ctx)
    Write-Host "  [INTEGRATION] Running 42 integration tests..."
    Start-Sleep -Milliseconds 900
    $ctx.Set("integrationTestsPassed", $true)
    Write-Host "  [INTEGRATION] All integration tests passed!"
}))

# ============================================================================
# PHASE 5: FINALIZE (Sequential Steps 9-10)
# ============================================================================

$workflow.AddStep("Step 9: Generate Reports", {
    param($ctx)
    
    Write-Host "  Generating test and coverage reports..."
    Start-Sleep -Milliseconds 300
    
    $ctx.Set("reportsGenerated", $true)
    Write-Host "  Reports saved to ./reports/"
})

$workflow.AddStep("Step 10: Send Notifications", {
    param($ctx)
    
    Write-Host "  Sending build notifications..."
    
    $startTime = $ctx.Get("startTime")
    if ($startTime) {
        $duration = (Get-Date) - $startTime
        Write-Host "    Total duration: $($duration.ToString('mm\:ss'))"
    }
    
    Write-Host "  Notifications sent to #builds channel!"
})

# ============================================================================
# CONDITIONAL STEP (Step 11)
# ============================================================================
# This step only runs if BOTH unit and integration tests passed

$workflow.AddConditionalStep(
    "Step 11: Deploy to Staging (if all tests passed)",
    { 
        param($ctx) 
        $unit = $ctx.Get("unitTestsPassed")
        $integration = $ctx.Get("integrationTestsPassed")
        return ($unit -eq $true) -and ($integration -eq $true)
    },
    {
        param($ctx)
        
        Write-Host "  Deploying to staging environment..."
        Start-Sleep -Milliseconds 500
        
        $ctx.Set("deployed", $true)
        Write-Host "  Successfully deployed to staging!"
        Write-Host "  URL: https://staging.example.com"
    }
)

# ============================================================================
# RUN IN INTERACTIVE MODE
# ============================================================================

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host "  STARTING INTERACTIVE MODE" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host ""
Write-Host "TIP: Try these selection patterns:" -ForegroundColor Yellow
Write-Host "  '1,2'     - Run just the setup steps" -ForegroundColor Gray
Write-Host "  '3-5'     - Run just the parallel build steps" -ForegroundColor Gray
Write-Host "  'from 6'  - Skip builds, run from validation onward" -ForegroundColor Gray
Write-Host "  '7,8,11'  - Run tests and deploy (deploy needs tests to pass!)" -ForegroundColor Gray
Write-Host "  'all'     - Run the complete workflow" -ForegroundColor Gray
Write-Host ""

# Execute in interactive mode
$workflow.ExecuteInteractive()

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  INTERACTIVE SESSION COMPLETE" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan

<#
WHAT YOU LEARNED:
-----------------
1. ExecuteInteractive() presents a menu to select steps
2. You can run individual steps, ranges, or combinations
3. Parallel steps still run in parallel when multiple are selected
4. Conditional steps still check their conditions
5. You can run the workflow multiple times with different selections

COMMON USE CASES:
-----------------
- Debugging: "3" - Run only the step that's failing
- Resume: "from 6" - Skip steps that already completed
- Partial: "1-5" - Run only the build phase
- Quick test: "7,8" - Run only the tests
- Full run: "all" - Run everything

INTERACTIVE MODE BEHAVIOR:
--------------------------
- The menu shows all steps with their status (Pending/Completed/Failed)
- After execution, PrintSummary() shows what happened
- You can run again with different selections
- Type 'exit', 'quit', or 'q' to leave interactive mode

PROGRAMMATIC ALTERNATIVE:
-------------------------
If you want to pre-select steps without user input, you can:

1. Use the -Manual parameter pattern (like other examples):
   
   param([switch]$Manual)
   
   if ($Manual) {
       $workflow.ExecuteInteractive()
   } else {
       $workflow.Execute()
   }

2. Or call the internal methods directly (advanced):
   
   $flags = [System.Reflection.BindingFlags]::Instance -bor 
            [System.Reflection.BindingFlags]::NonPublic -bor 
            [System.Reflection.BindingFlags]::Public
   
   $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
   $stepList = $buildMethod.Invoke($workflow, @())
   
   $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
   $selection = @{
       Action = "Execute"
       SelectedIndices = @(1, 2, 3)  # Run steps 1, 2, and 3
       StepList = $stepList
   }
   $executeMethod.Invoke($workflow, @($selection))

NEXT STEPS:
-----------
- Try Example-06-RealWorld-Deployment.ps1 with -Manual for a realistic scenario
- Explore combining interactive mode with error recovery patterns
#>
