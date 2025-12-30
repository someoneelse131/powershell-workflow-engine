<#
.SYNOPSIS
    Demo script to run the test workflow in interactive mode

.DESCRIPTION
    This script creates the test workflow and runs it in interactive mode,
    allowing you to manually select which steps to execute.
    
.EXAMPLE
    .\Run-InteractiveDemo.ps1
    
.NOTES
    This is for manual testing - use Test-ManualExecution.ps1 for automated tests.
#>

# Load dependencies
. "$PSScriptRoot\..\..\WorkflowEngine.ps1"
. "$PSScriptRoot\TestWorkflow.ps1"

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  INTERACTIVE EXECUTION DEMO" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo creates a workflow with 11 steps:" -ForegroundColor Yellow
Write-Host "  - 2 sequential setup steps" -ForegroundColor Gray
Write-Host "  - 3 parallel build steps" -ForegroundColor Gray
Write-Host "  - 1 sequential validation step" -ForegroundColor Gray
Write-Host "  - 2 parallel test steps" -ForegroundColor Gray
Write-Host "  - 2 sequential cleanup steps" -ForegroundColor Gray
Write-Host "  - 1 conditional deploy step" -ForegroundColor Gray
Write-Host ""
Write-Host "In the interactive menu, you can:" -ForegroundColor Yellow
Write-Host "  - Select individual steps: 1,3,5" -ForegroundColor Gray
Write-Host "  - Select ranges: 2-6" -ForegroundColor Gray
Write-Host "  - Start from a step: from 5" -ForegroundColor Gray
Write-Host "  - Go up to a step: to 4" -ForegroundColor Gray
Write-Host "  - Run all: all" -ForegroundColor Gray
Write-Host "  - Exit: exit, quit, or q" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Cyan
[void][System.Console]::ReadKey($true)

# Create and run the workflow
$workflow = New-TestWorkflow
$workflow.ExecuteInteractive()

Write-Host ""
Write-Host "Demo completed!" -ForegroundColor Green
Write-Host ""
