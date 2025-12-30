#requires -Version 5.1

<#
.SYNOPSIS
    Automated Tests for Manual/Interactive Execution Mode

.DESCRIPTION
    This test script validates the ExecuteInteractive() functionality
    of the WorkflowEngine. Since interactive mode requires user input,
    we test the underlying methods that parse selections and execute
    filtered step sets.
    
    Tests include:
    - Step list building
    - Selection parsing (ranges, individual, from/to)
    - Partial parallel group execution
    - Sequential step execution
    - Mixed selection execution
    - Exit handling

.PARAMETER LogPath
    Optional path to a log file

.NOTES
    Run with: .\Test-ManualExecution.ps1
#>

param(
    [string]$LogPath
)

# Load the workflow engine and test workflow
. "$PSScriptRoot\..\..\WorkflowEngine.ps1"
. "$PSScriptRoot\TestWorkflow.ps1"

#region Logging Infrastructure

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "ManualExecutionTests.log"
}

$script:LogFile = $LogPath

function Write-Log {
    param(
        [string]$Message = '',
        [ValidateSet('Info', 'Pass', 'Fail', 'Warn', 'Header', 'Section')]
        [string]$Level = 'Info',
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    $color = switch ($Level) {
        'Pass'    { 'Green' }
        'Fail'    { 'Red' }
        'Warn'    { 'Yellow' }
        'Header'  { 'Cyan' }
        'Section' { 'Yellow' }
        default   { 'White' }
    }
    
    $prefix = switch ($Level) {
        'Pass' { '[PASS] ' }
        'Fail' { '[FAIL] ' }
        'Warn' { '[WARN] ' }
        default { '' }
    }
    
    if ($NoNewLine) {
        Write-Host "$prefix$Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix$Message" -ForegroundColor $color
    }
    
    $logMessage = "[$timestamp] $prefix$Message"
    Add-Content -Path $script:LogFile -Value $logMessage
}

function Initialize-LogFile {
    $header = @"
================================================================================
             MANUAL EXECUTION TEST SUITE LOG
================================================================================
Test Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell Version: $($PSVersionTable.PSVersion)
================================================================================

"@
    Set-Content -Path $script:LogFile -Value $header
    Write-Host "Logging to: $script:LogFile" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Test Infrastructure

# Helper function to get hidden methods - works around PowerShell type loading issues
function Get-WorkflowMethod {
    param(
        [object]$Workflow,
        [string]$MethodName
    )
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $method = $Workflow.GetType().GetMethod($MethodName, $flags)
    
    if ($null -eq $method) {
        # Try getting all methods and finding by name
        $allMethods = $Workflow.GetType().GetMethods($flags)
        $method = $allMethods | Where-Object { $_.Name -eq $MethodName } | Select-Object -First 1
    }
    
    return $method
}

# Helper to invoke BuildStepList
function Invoke-BuildStepList {
    param([object]$Workflow)
    
    $method = Get-WorkflowMethod -Workflow $Workflow -MethodName 'BuildStepList'
    if ($null -eq $method) {
        Write-Log "ERROR: Could not find BuildStepList method" -Level Fail
        return @()
    }
    return $method.Invoke($Workflow, @())
}

# Helper to invoke ParseStepSelection
function Invoke-ParseStepSelection {
    param(
        [object]$Workflow,
        [string]$Input,
        [array]$StepList
    )
    
    $method = Get-WorkflowMethod -Workflow $Workflow -MethodName 'ParseStepSelection'
    if ($null -eq $method) {
        Write-Log "ERROR: Could not find ParseStepSelection method" -Level Fail
        return @{ Action = "Error" }
    }
    return $method.Invoke($Workflow, @($Input, $StepList))
}

# Helper to invoke ExecuteSelectedSteps
function Invoke-ExecuteSelectedSteps {
    param(
        [object]$Workflow,
        [hashtable]$Selection
    )
    
    $method = Get-WorkflowMethod -Workflow $Workflow -MethodName 'ExecuteSelectedSteps'
    if ($null -eq $method) {
        Write-Log "ERROR: Could not find ExecuteSelectedSteps method" -Level Fail
        return
    }
    $method.Invoke($Workflow, @($Selection))
}

$script:TestResults = @{
    Passed = 0
    Failed = 0
    Tests = [System.Collections.ArrayList]::new()
}

function Test-Assert {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$TestName,
        [string]$Message = ""
    )
    
    $result = @{
        Name = $TestName
        Passed = $Condition
        Message = $Message
        Timestamp = Get-Date
    }
    
    $script:TestResults.Tests.Add($result) | Out-Null
    
    if ($Condition) {
        $script:TestResults.Passed++
        Write-Log "  $TestName" -Level Pass
    } else {
        $script:TestResults.Failed++
        Write-Log "  $TestName" -Level Fail
        if ($Message) {
            Write-Log "         $Message" -Level Fail
        }
    }
    
    return $Condition
}

function Write-TestHeader {
    param([string]$Title)
    Write-Log ""
    Write-Log ("=" * 70) -Level Header
    Write-Log "  $Title" -Level Header
    Write-Log ("=" * 70) -Level Header
    Write-Log ""
}

function Write-TestSectionHeader {
    param([string]$Title)
    Write-Log ""
    Write-Log ("-" * 50) -Level Section
    Write-Log "  $Title" -Level Section
    Write-Log ("-" * 50) -Level Section
    Write-Log ""
}

function Write-TestSummary {
    Write-Log ""
    Write-Log ("=" * 70) -Level Header
    Write-Log "  TEST SUMMARY" -Level Header
    Write-Log ("=" * 70) -Level Header
    Write-Log ""
    
    $total = $script:TestResults.Passed + $script:TestResults.Failed
    $passRate = if ($total -gt 0) { [math]::Round(($script:TestResults.Passed / $total) * 100, 1) } else { 0 }
    
    Write-Log "  Total Tests:  $total"
    Write-Log "  Passed:       $($script:TestResults.Passed)" -Level Pass
    if ($script:TestResults.Failed -gt 0) {
        Write-Log "  Failed:       $($script:TestResults.Failed)" -Level Fail
    } else {
        Write-Log "  Failed:       $($script:TestResults.Failed)" -Level Pass
    }
    Write-Log "  Pass Rate:    $passRate%"
    Write-Log ""
    
    if ($script:TestResults.Failed -gt 0) {
        Write-Log "  Failed Tests:" -Level Fail
        $script:TestResults.Tests | Where-Object { -not $_.Passed } | ForEach-Object {
            Write-Log "    - $($_.Name)" -Level Fail
            if ($_.Message) {
                Write-Log "      $($_.Message)" -Level Fail
            }
        }
        Write-Log ""
    }
    
    Write-Log ("=" * 70) -Level Header
    Write-Log ""
}

#endregion

#region Test Group 1: BuildStepList Tests

function Test-BuildStepList {
    Write-TestHeader "TEST GROUP 1: BuildStepList Method"
    
    Write-TestSectionHeader "Test 1.1: Step List Contains All Steps"
    
    $workflow = New-TestWorkflow
    $stepList = Invoke-BuildStepList -Workflow $workflow
    
    Test-Assert -Condition ($stepList.Count -eq 11) -TestName "Step list contains 11 steps" -Message "Found $($stepList.Count) steps"
    
    Write-TestSectionHeader "Test 1.2: Parallel Steps Marked Correctly"
    
    $parallelSteps = $stepList | Where-Object { $_.IsParallel -eq $true }
    $sequentialSteps = $stepList | Where-Object { $_.IsParallel -eq $false }
    
    Test-Assert -Condition ($parallelSteps.Count -eq 5) -TestName "5 steps marked as parallel" -Message "Found $($parallelSteps.Count)"
    Test-Assert -Condition ($sequentialSteps.Count -eq 6) -TestName "6 steps marked as sequential" -Message "Found $($sequentialSteps.Count)"
    
    Write-TestSectionHeader "Test 1.3: Parallel Group References Set"
    
    $stepsWithGroups = $stepList | Where-Object { $null -ne $_.ParallelGroup }
    
    Test-Assert -Condition ($stepsWithGroups.Count -eq 5) -TestName "5 steps have ParallelGroup reference"
    
    Write-TestSectionHeader "Test 1.4: Step Names Preserved"
    
    $expectedNames = @(
        "Step 1: Initialize Environment",
        "Step 2: Load Configuration",
        "Step 3: Build API",
        "Step 4: Build Frontend",
        "Step 5: Build Worker",
        "Step 6: Validate Builds",
        "Step 7: Unit Tests",
        "Step 8: Integration Tests",
        "Step 9: Generate Reports",
        "Step 10: Notify Team",
        "Step 11: Deploy (if all tests passed)"
    )
    
    $allNamesMatch = $true
    for ($i = 0; $i -lt $expectedNames.Count; $i++) {
        if ($stepList[$i].Name -ne $expectedNames[$i]) {
            $allNamesMatch = $false
            break
        }
    }
    
    Test-Assert -Condition $allNamesMatch -TestName "All step names preserved in correct order"
}

#endregion

#region Test Group 2: ParseStepSelection Tests

function Test-ParseStepSelection {
    Write-TestHeader "TEST GROUP 2: ParseStepSelection Method"
    
    $workflow = New-TestWorkflow
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $parseMethod = $workflow.GetType().GetMethod('ParseStepSelection', $flags)
    
    Write-TestSectionHeader "Test 2.1: Exit Commands"
    
    foreach ($exitCmd in @("exit", "quit", "q", "EXIT", "QUIT", "Q")) {
        $result = $parseMethod.Invoke($workflow, @($exitCmd, $stepList))
        Test-Assert -Condition ($result.Action -eq "Exit") -TestName "Command '$exitCmd' triggers exit"
    }
    
    Write-TestSectionHeader "Test 2.2: All Command"
    
    $result = $parseMethod.Invoke($workflow, @("all", $stepList))
    Test-Assert -Condition ($result.Action -eq "Execute") -TestName "'all' command returns Execute action"
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 11) -TestName "'all' selects all 11 steps"
    
    Write-TestSectionHeader "Test 2.3: Individual Numbers"
    
    $result = $parseMethod.Invoke($workflow, @("1", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 1) -TestName "Single number selects 1 step"
    Test-Assert -Condition ($result.SelectedIndices[0] -eq 1) -TestName "Correct step selected"
    
    $result = $parseMethod.Invoke($workflow, @("1,3,5", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 3) -TestName "Comma-separated selects 3 steps"
    Test-Assert -Condition (($result.SelectedIndices -contains 1) -and ($result.SelectedIndices -contains 3) -and ($result.SelectedIndices -contains 5)) -TestName "Correct steps (1,3,5) selected"
    
    Write-TestSectionHeader "Test 2.4: Range Selection"
    
    $result = $parseMethod.Invoke($workflow, @("2-6", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 5) -TestName "Range 2-6 selects 5 steps"
    Test-Assert -Condition (($result.SelectedIndices[0] -eq 2) -and ($result.SelectedIndices[-1] -eq 6)) -TestName "Range includes steps 2 through 6"
    
    Write-TestSectionHeader "Test 2.5: From X Command"
    
    $result = $parseMethod.Invoke($workflow, @("from 8", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 4) -TestName "'from 8' selects 4 steps (8-11)"
    Test-Assert -Condition ($result.SelectedIndices[0] -eq 8) -TestName "'from 8' starts at step 8"
    Test-Assert -Condition ($result.SelectedIndices[-1] -eq 11) -TestName "'from 8' ends at step 11"
    
    Write-TestSectionHeader "Test 2.6: To X Command"
    
    $result = $parseMethod.Invoke($workflow, @("to 3", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 3) -TestName "'to 3' selects 3 steps (1-3)"
    Test-Assert -Condition ($result.SelectedIndices[0] -eq 1) -TestName "'to 3' starts at step 1"
    Test-Assert -Condition ($result.SelectedIndices[-1] -eq 3) -TestName "'to 3' ends at step 3"
    
    Write-TestSectionHeader "Test 2.7: Mixed Selection"
    
    $result = $parseMethod.Invoke($workflow, @("1,3-5,9", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 5) -TestName "Mixed selection (1,3-5,9) selects 5 steps"
    $expected = @(1, 3, 4, 5, 9)
    $allMatch = $true
    foreach ($e in $expected) {
        if ($result.SelectedIndices -notcontains $e) { $allMatch = $false; break }
    }
    Test-Assert -Condition $allMatch -TestName "Mixed selection contains correct steps"
    
    Write-TestSectionHeader "Test 2.8: Invalid/Out of Range"
    
    $result = $parseMethod.Invoke($workflow, @("0,15,20", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 0) -TestName "Out of range indices are filtered out"
    
    $result = $parseMethod.Invoke($workflow, @("1,2,15", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 2) -TestName "Only valid indices (1,2) remain, invalid (15) filtered"
    
    Write-TestSectionHeader "Test 2.9: Duplicate Handling"
    
    $result = $parseMethod.Invoke($workflow, @("1,1,1,2-3,2", $stepList))
    Test-Assert -Condition ($result.SelectedIndices.Count -eq 3) -TestName "Duplicates removed (1,1,1,2-3,2 -> 1,2,3)"
}

#endregion

#region Test Group 3: ExecuteSelectedSteps Tests

function Test-ExecuteSelectedSteps {
    Write-TestHeader "TEST GROUP 3: ExecuteSelectedSteps Method"
    
    Write-TestSectionHeader "Test 3.1: Execute Single Sequential Step"
    
    $workflow = New-TestWorkflow
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(1)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Single step executed and set context"
    Test-Assert -Condition ($workflow.Context.Get("configLoaded") -ne $true) -TestName "Unselected step did not execute"
    
    Write-TestSectionHeader "Test 3.2: Execute Multiple Sequential Steps"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(1, 2)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "First sequential step executed"
    Test-Assert -Condition ($workflow.Context.Get("configLoaded") -eq $true) -TestName "Second sequential step executed"
    
    Write-TestSectionHeader "Test 3.3: Execute Partial Parallel Group"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Select only 2 of 3 steps from the first parallel group (steps 3,4,5)
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(3, 4)  # Build API and Build Frontend, not Build Worker
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Selected parallel step 3 (API) executed"
    Test-Assert -Condition ($workflow.Context.Get("webBuild") -eq "success") -TestName "Selected parallel step 4 (Web) executed"
    Test-Assert -Condition ($workflow.Context.Get("workerBuild") -ne "success") -TestName "Unselected parallel step 5 (Worker) did NOT execute"
    
    Write-TestSectionHeader "Test 3.4: Execute Full Parallel Group"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(3, 4, 5)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Parallel step 3 executed"
    Test-Assert -Condition ($workflow.Context.Get("webBuild") -eq "success") -TestName "Parallel step 4 executed"
    Test-Assert -Condition ($workflow.Context.Get("workerBuild") -eq "success") -TestName "Parallel step 5 executed"
    
    Write-TestSectionHeader "Test 3.5: Execute Mixed Sequential and Parallel"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Setup steps + some parallel steps
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(1, 2, 3, 5)  # Init, Config, API (parallel), Worker (parallel, skipping Frontend)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Sequential step 1 executed in mixed selection"
    Test-Assert -Condition ($workflow.Context.Get("configLoaded") -eq $true) -TestName "Sequential step 2 executed in mixed selection"
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Parallel step 3 executed in mixed selection"
    Test-Assert -Condition ($workflow.Context.Get("webBuild") -ne "success") -TestName "Unselected parallel step 4 skipped in mixed selection"
    Test-Assert -Condition ($workflow.Context.Get("workerBuild") -eq "success") -TestName "Parallel step 5 executed in mixed selection"
    
    Write-TestSectionHeader "Test 3.6: Execute From Middle (Skip Early Steps)"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Start from step 7 (Unit Tests)
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 8, 9)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("initialized") -ne $true) -TestName "Early steps not executed"
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Step 7 (Unit Tests) executed"
    Test-Assert -Condition ($workflow.Context.Get("integrationTests") -eq "passed") -TestName "Step 8 (Integration Tests) executed"
    Test-Assert -Condition ($workflow.Context.Get("reportsGenerated") -eq $true) -TestName "Step 9 (Reports) executed"
    
    Write-TestSectionHeader "Test 3.7: Empty Selection"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @()
        StepList = $stepList
    }
    
    try {
        $executeMethod.Invoke($workflow, @($selection))
        Test-Assert -Condition $true -TestName "Empty selection doesn't throw"
    } catch {
        Test-Assert -Condition $false -TestName "Empty selection doesn't throw" -Message $_.Exception.InnerException.Message
    }
    
    Test-Assert -Condition ($workflow.Context.Get("initialized") -ne $true) -TestName "No steps executed with empty selection"
}

#endregion

#region Test Group 4: Conditional Step in Selection Tests

function Test-ConditionalStepSelection {
    Write-TestHeader "TEST GROUP 4: Conditional Steps in Selection"
    
    Write-TestSectionHeader "Test 4.1: Conditional Step Runs When Condition Met"
    
    $workflow = New-TestWorkflow
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    
    # Run test steps first to set up conditions, then conditional deploy step
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 8, 11)  # Unit Tests, Integration Tests, Deploy (conditional)
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Unit tests passed"
    Test-Assert -Condition ($workflow.Context.Get("integrationTests") -eq "passed") -TestName "Integration tests passed"
    Test-Assert -Condition ($workflow.Context.Get("deployed") -eq $true) -TestName "Conditional deploy step executed (conditions met)"
    
    Write-TestSectionHeader "Test 4.2: Conditional Step Skipped When Condition Not Met"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Only run unit tests (not integration), then try deploy
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 11)  # Unit Tests only, then Deploy
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Unit tests passed"
    Test-Assert -Condition ($workflow.Context.Get("integrationTests") -ne "passed") -TestName "Integration tests NOT passed (not selected)"
    Test-Assert -Condition ($workflow.Context.Get("deployed") -ne $true) -TestName "Conditional deploy step SKIPPED (conditions not met)"
}

#endregion

#region Test Group 5: Error Handling in Selection

function Test-SelectionErrorHandling {
    Write-TestHeader "TEST GROUP 5: Error Handling in Selection"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.1: Sequential Step Failure (ContinueOnError=false)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingSequentialStep
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(1, 2, 3)  # Init, Config (fails), Build API
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition $errorThrown -TestName "Exception thrown when sequential step fails"
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Step before failure executed"
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -ne "success") -TestName "Step after failure NOT executed"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.2: Sequential Step Failure (ContinueOnError=true)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingSequentialStep -ContinueOnError
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(1, 2, 3, 4, 5)  # Init, Config (fails), then parallel builds
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition (-not $errorThrown) -TestName "No exception with ContinueOnError=true"
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Step before failure executed"
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Steps after failure executed (ContinueOnError)"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.3: Parallel Step Failure (ContinueOnError=false)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingParallelStep
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Note: With failing parallel step, indices shift: 3=API, 4=Frontend, 5=Worker, 6=Mobile(fails)
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(3, 4, 5, 6)  # All parallel builds including failing one
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition $errorThrown -TestName "Exception thrown when parallel step fails"
    # Note: Other parallel steps may or may not complete before the error is raised
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.4: Parallel Step Failure (ContinueOnError=true)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingParallelStep -ContinueOnError
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(3, 4, 5, 6, 7)  # All parallel builds + validate step after
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition (-not $errorThrown) -TestName "No exception with ContinueOnError=true (parallel)"
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Non-failing parallel step 1 completed"
    Test-Assert -Condition ($workflow.Context.Get("webBuild") -eq "success") -TestName "Non-failing parallel step 2 completed"
    Test-Assert -Condition ($workflow.Context.Get("workerBuild") -eq "success") -TestName "Non-failing parallel step 3 completed"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.5: Parallel Failure in Test Group (Original Test)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingStep
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 8, 9)  # Unit Tests, Integration Tests (fails), Reports
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition $errorThrown -TestName "Exception thrown when parallel test step fails"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.6: Parallel Failure With ContinueOnError (Original Test)"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingStep -ContinueOnError
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 8, 9)  # Unit Tests, Integration Tests (fails), Reports
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition (-not $errorThrown) -TestName "No exception thrown (ContinueOnError=true)"
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Non-failing parallel step completed"
    Test-Assert -Condition ($workflow.Context.Get("reportsGenerated") -eq $true) -TestName "Sequential step after parallel failure executed"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.7: Skip Failing Step via Selection"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingStep
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Intentionally skip step 8 (the failing one)
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 9)  # Unit Tests, skip Integration Tests (fails), Reports
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition (-not $errorThrown) -TestName "No exception when failing step is skipped via selection"
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Selected step executed"
    Test-Assert -Condition ($workflow.Context.Get("reportsGenerated") -eq $true) -TestName "Step after skipped failure executed"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.8: Multiple Failures in Same Parallel Group"
    # -------------------------------------------------------------------------
    
    # Create a workflow with both parallel failures
    $workflow = New-TestWorkflow -IncludeFailingStep -IncludeFailingParallelStep -ContinueOnError
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Run all steps
    $selection = @{
        Action = "Execute"
        SelectedIndices = 1..$stepList.Count
        StepList = $stepList
    }
    
    $errorThrown = $false
    try {
        $executeMethod.Invoke($workflow, @($selection))
    } catch {
        $errorThrown = $true
    }
    
    Test-Assert -Condition (-not $errorThrown) -TestName "No exception with multiple failures (ContinueOnError=true)"
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Initial steps completed"
    Test-Assert -Condition ($workflow.Context.Get("notificationsSent") -eq $true) -TestName "Final steps completed despite failures"
    
    # -------------------------------------------------------------------------
    Write-TestSectionHeader "Test 5.9: Step Status Tracking After Failure"
    # -------------------------------------------------------------------------
    
    $workflow = New-TestWorkflow -IncludeFailingStep -ContinueOnError
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(7, 8, 9)  # Unit Tests, Integration Tests (fails), Reports
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    # Check step statuses
    $unitTestStep = $stepList[6].OriginalStep  # Index 6 = step 7
    $integrationTestStep = $stepList[7].OriginalStep  # Index 7 = step 8 (failing)
    $reportsStep = $stepList[8].OriginalStep  # Index 8 = step 9
    
    Test-Assert -Condition ($unitTestStep.Status -eq [StepStatus]::Completed) -TestName "Successful step has Completed status"
    Test-Assert -Condition ($integrationTestStep.Status -eq [StepStatus]::Failed) -TestName "Failed step has Failed status"
    Test-Assert -Condition ($reportsStep.Status -eq [StepStatus]::Completed) -TestName "Step after failure has Completed status"
    Test-Assert -Condition ($integrationTestStep.ErrorMessage -ne $null) -TestName "Failed step has error message set"
}

#endregion

#region Test Group 6: Full Workflow Selection Tests

function Test-FullWorkflowSelection {
    Write-TestHeader "TEST GROUP 6: Full Workflow Selection"
    
    Write-TestSectionHeader "Test 6.1: Execute All Steps"
    
    $workflow = New-TestWorkflow
    
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    
    $selection = @{
        Action = "Execute"
        SelectedIndices = 1..11
        StepList = $stepList
    }
    
    $executeMethod.Invoke($workflow, @($selection))
    
    # Verify all steps executed
    Test-Assert -Condition ($workflow.Context.Get("initialized") -eq $true) -TestName "Step 1 (Initialize) executed"
    Test-Assert -Condition ($workflow.Context.Get("configLoaded") -eq $true) -TestName "Step 2 (Config) executed"
    Test-Assert -Condition ($workflow.Context.Get("apiBuild") -eq "success") -TestName "Step 3 (API Build) executed"
    Test-Assert -Condition ($workflow.Context.Get("webBuild") -eq "success") -TestName "Step 4 (Web Build) executed"
    Test-Assert -Condition ($workflow.Context.Get("workerBuild") -eq "success") -TestName "Step 5 (Worker Build) executed"
    Test-Assert -Condition ($workflow.Context.Get("buildsValidated") -eq $true) -TestName "Step 6 (Validate) executed"
    Test-Assert -Condition ($workflow.Context.Get("unitTests") -eq "passed") -TestName "Step 7 (Unit Tests) executed"
    Test-Assert -Condition ($workflow.Context.Get("integrationTests") -eq "passed") -TestName "Step 8 (Integration Tests) executed"
    Test-Assert -Condition ($workflow.Context.Get("reportsGenerated") -eq $true) -TestName "Step 9 (Reports) executed"
    Test-Assert -Condition ($workflow.Context.Get("notificationsSent") -eq $true) -TestName "Step 10 (Notify) executed"
    Test-Assert -Condition ($workflow.Context.Get("deployed") -eq $true) -TestName "Step 11 (Deploy) executed (conditional met)"
    
    Write-TestSectionHeader "Test 6.2: Parallel Execution is Actually Parallel"
    
    $workflow = New-TestWorkflow
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Public
    $buildMethod = $workflow.GetType().GetMethod('BuildStepList', $flags)
    $executeMethod = $workflow.GetType().GetMethod('ExecuteSelectedSteps', $flags)
    $stepList = $buildMethod.Invoke($workflow, @())
    
    # Just run the first parallel group (steps 3,4,5 - each takes 400-600ms)
    $selection = @{
        Action = "Execute"
        SelectedIndices = @(3, 4, 5)
        StepList = $stepList
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $executeMethod.Invoke($workflow, @($selection))
    $stopwatch.Stop()
    
    # If sequential: 500+600+400 = 1500ms
    # If parallel: ~600ms (max of the three)
    $elapsed = $stopwatch.Elapsed.TotalMilliseconds
    
    Test-Assert -Condition ($elapsed -lt 1200) -TestName "Parallel steps run in parallel (< 1200ms)" -Message "Elapsed: $($elapsed.ToString('F0'))ms"
}

#endregion

#region Run All Tests

function Run-AllTests {
    Write-Log ''
    Write-Log '========================================================================' -Level Header
    Write-Log '       MANUAL/INTERACTIVE EXECUTION TEST SUITE                          ' -Level Header
    Write-Log '========================================================================' -Level Header
    Write-Log ''
    
    $script:TestResults = @{
        Passed = 0
        Failed = 0
        Tests = [System.Collections.ArrayList]::new()
    }
    
    $overallStart = Get-Date
    
    Test-BuildStepList
    Test-ParseStepSelection
    Test-ExecuteSelectedSteps
    Test-ConditionalStepSelection
    Test-SelectionErrorHandling
    Test-FullWorkflowSelection
    
    $overallEnd = Get-Date
    $totalTime = ($overallEnd - $overallStart).TotalSeconds
    
    Write-TestSummary
    
    $timeStr = [math]::Round($totalTime, 2)
    Write-Log "  Total Test Time: $timeStr seconds" -Level Header
    Write-Log ''
    
    Add-Content -Path $script:LogFile -Value @"

================================================================================
                              TEST RUN COMPLETE
================================================================================
Test Ended: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Time: $timeStr seconds
Total Tests: $($script:TestResults.Passed + $script:TestResults.Failed)
Passed: $($script:TestResults.Passed)
Failed: $($script:TestResults.Failed)
Result: $(if ($script:TestResults.Failed -eq 0) { 'SUCCESS' } else { 'FAILED' })
================================================================================
"@
    
    return ($script:TestResults.Failed -eq 0)
}

#endregion

#region Entry Point

Initialize-LogFile

$allPassed = Run-AllTests

if ($allPassed) {
    Write-Log 'All tests passed!' -Level Pass
    Write-Host ""
    Write-Host "Log file: $script:LogFile" -ForegroundColor Cyan
    exit 0
} else {
    Write-Log 'Some tests failed!' -Level Fail
    Write-Host ""
    Write-Host "Log file: $script:LogFile" -ForegroundColor Cyan
    exit 1
}

#endregion
