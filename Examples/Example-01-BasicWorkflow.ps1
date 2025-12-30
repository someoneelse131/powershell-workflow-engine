<#
.SYNOPSIS
    Example 01: Basic Workflow - Your First Workflow

.DESCRIPTION
    This is the simplest possible workflow example.
    It shows how to:
    - Load the workflow engine module
    - Create a workflow
    - Add sequential steps
    - Execute the workflow
    - View the summary

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-01-BasicWorkflow.ps1

    For interactive mode:
    .\Example-01-BasicWorkflow.ps1 -Manual
#>

param(
    [switch]$Manual
)

# ============================================================================
# STEP 1: Load the Workflow Engine Module
# ============================================================================
# Import-Module loads the module and makes all functions available

Import-Module WorkflowEngine

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  EXAMPLE 01: Basic Sequential Workflow" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# STEP 2: Create a New Workflow
# ============================================================================
# New-Workflow creates an empty workflow container
# We'll add steps to it next

$workflow = New-Workflow

# ============================================================================
# STEP 3: Add Steps to the Workflow
# ============================================================================
# Each step has:
#   - A name (for display purposes)
#   - A scriptblock (the code to run)
#
# IMPORTANT: Always include "param($ctx)" even if you don't use it!
# The $ctx (context) is how steps share data (we'll cover this in Example 02)

$workflow.AddStep("Step 1: Initialize", {
    param($ctx)  # <-- Always include this!
    
    Write-Host "  Initializing the system..."
    Write-Host "  Setting up configuration..."
    
    # Simulate some work
    Start-Sleep -Milliseconds 500
    
    Write-Host "  Initialization complete!"
})

$workflow.AddStep("Step 2: Process", {
    param($ctx)
    
    Write-Host "  Processing data..."
    
    # Simulate processing
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "    Processing batch $i of 3..."
        Start-Sleep -Milliseconds 300
    }
    
    Write-Host "  Processing complete!"
})

$workflow.AddStep("Step 3: Finalize", {
    param($ctx)
    
    Write-Host "  Finalizing..."
    Write-Host "  Cleaning up temporary files..."
    Write-Host "  Generating report..."
    
    Start-Sleep -Milliseconds 500
    
    Write-Host "  All done!"
})

# ============================================================================
# STEP 4: Execute the Workflow
# ============================================================================
# Execute() runs all steps in order
# It returns $true if successful, $false if any step failed
#
# With -Manual parameter, ExecuteInteractive() provides an interactive menu

Write-Host "Starting workflow execution..." -ForegroundColor Yellow
Write-Host ""

if ($Manual) {
    # Interactive mode - user selects which steps to run
    $workflow.ExecuteInteractive()
} else {
    # Automatic mode - run all steps
    $success = $workflow.Execute()

    # ============================================================================
    # STEP 5: Print the Summary
    # ============================================================================
    # PrintSummary() shows a nice overview of what happened

    $workflow.PrintSummary()

    # ============================================================================
    # STEP 6: Check the Result
    # ============================================================================

    if ($success) {
        Write-Host "Workflow completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Workflow failed!" -ForegroundColor Red
    }
}

<#
WHAT YOU LEARNED:
-----------------
1. Load the engine with: Import-Module "path\to\WorkflowEngine"
2. Create a workflow with: New-Workflow
3. Add steps with: $workflow.AddStep("Name", { param($ctx) ... })
4. Run with: $workflow.Execute()
5. View results with: $workflow.PrintSummary()

NEXT: Example-02-ContextSharing.ps1 - Learn how to pass data between steps
#>
