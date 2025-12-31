#requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive Test Suite for WorkflowEngine.ps1
.DESCRIPTION
    Tests all aspects of the workflow engine including:
    - Sequential execution (with/without errors)
    - Parallel execution (with/without errors)
    - Conditional steps
    - Dependencies
    - Retries (step-level and workflow-level)
    - Context sharing
    - ContinueOnError behavior
    - Edge cases and stress tests
.NOTES
    Run with: .\WorkflowEngine.Tests.ps1
    Or run specific test groups by uncommenting at the bottom
.PARAMETER LogPath
    Optional path to a log file. If not specified, logs to .\TestResults_<timestamp>.log
#>
param(
    [string]$LogPath
)

Import-Module WorkflowEngine

#region Logging Infrastructure

# Set up log file path
if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "TestResults.log"
}

# Initialize log file
$script:LogFile = $LogPath

function Write-Log {
    param(
        [Parameter()]
        [string]$Message = '',
        [ValidateSet('Info', 'Pass', 'Fail', 'Warn', 'Header', 'Section')]
        [string]$Level = 'Info',
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Determine color and prefix
    $color = 'White'
    $prefix = ''
    
    switch ($Level) {
        'Pass'    { $color = 'Green';  $prefix = '[PASS] ' }
        'Fail'    { $color = 'Red';    $prefix = '[FAIL] ' }
        'Warn'    { $color = 'Yellow'; $prefix = '[WARN] ' }
        'Header'  { $color = 'Cyan';   $prefix = '' }
        'Section' { $color = 'Yellow'; $prefix = '' }
        default   { $color = 'White';  $prefix = '' }
    }
    
    # Write to console
    if ($NoNewLine) {
        Write-Host "$prefix$Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix$Message" -ForegroundColor $color
    }
    
    # Write to log file
    $logMessage = "[$timestamp] $prefix$Message"
    if ($NoNewLine) {
        Add-Content -Path $script:LogFile -Value $logMessage -NoNewline
    } else {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Initialize-LogFile {
    $header = @"
================================================================================
                    WORKFLOW ENGINE TEST SUITE LOG
================================================================================
Test Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell Version: $($PSVersionTable.PSVersion)
Host: $($env:COMPUTERNAME)
================================================================================

"@
    Set-Content -Path $script:LogFile -Value $header
    Write-Host "Logging to: $script:LogFile" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Test Infrastructure

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

function Reset-TestResults {
    $script:TestResults = @{
        Passed = 0
        Failed = 0
        Tests = [System.Collections.ArrayList]::new()
    }
}

#endregion

#region Test Group 1: Sequential Execution Tests

function Test-SequentialExecution {
    Write-TestHeader "TEST GROUP 1: Sequential Execution"
    
    # Test 1.1: Basic sequential steps succeed
    Write-TestSectionHeader "Test 1.1: Basic Sequential Steps (Success)"
    
    $workflow = New-Workflow
    $executionOrder = [System.Collections.ArrayList]::new()
    
    $workflow.AddStep("Step 1", {
        param($context)
        $context.Set("Step1Executed", $true)
        return "Step1"
    })
    
    $workflow.AddStep("Step 2", {
        param($context)
        $context.Set("Step2Executed", $true)
        return "Step2"
    })
    
    $workflow.AddStep("Step 3", {
        param($context)
        $context.Set("Step3Executed", $true)
        return "Step3"
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Sequential workflow returns success"
    Test-Assert -Condition ($workflow.Context.Get("Step1Executed") -eq $true) -TestName "Step 1 was executed"
    Test-Assert -Condition ($workflow.Context.Get("Step2Executed") -eq $true) -TestName "Step 2 was executed"
    Test-Assert -Condition ($workflow.Context.Get("Step3Executed") -eq $true) -TestName "Step 3 was executed"
    
    # Test 1.2: Sequential steps with failure (ContinueOnError = false)
    Write-TestSectionHeader "Test 1.2: Sequential Steps with Failure (Stop on Error)"
    
    $workflow = New-Workflow -ContinueOnError $false
    
    $workflow.AddStep("Step A", {
        param($context)
        $context.Set("StepAExecuted", $true)
        return $true
    })
    
    $failStep = $workflow.AddStep("Step B (Fails)", {
        param($context)
        throw "Intentional failure"
    })
    $failStep.Retries = 1
    $failStep.RetryDelay = 0
    
    $workflow.AddStep("Step C", {
        param($context)
        $context.Set("StepCExecuted", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition (-not $success) -TestName "Workflow fails when step fails"
    Test-Assert -Condition ($workflow.Context.Get("StepAExecuted") -eq $true) -TestName "Step before failure was executed"
    Test-Assert -Condition ($workflow.Context.Get("StepCExecuted") -ne $true) -TestName "Step after failure was NOT executed"
    
    # Test 1.3: Sequential steps with failure (ContinueOnError = true)
    Write-TestSectionHeader "Test 1.3: Sequential Steps with Failure (Continue on Error)"
    
    $workflow = New-Workflow -ContinueOnError $true
    
    $workflow.AddStep("Step X", {
        param($context)
        $context.Set("StepXExecuted", $true)
        return $true
    })
    
    $failStep = $workflow.AddStep("Step Y (Fails)", {
        param($context)
        throw "Intentional failure"
    })
    $failStep.Retries = 1
    $failStep.RetryDelay = 0
    
    $workflow.AddStep("Step Z", {
        param($context)
        $context.Set("StepZExecuted", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Workflow succeeds with ContinueOnError=true"
    Test-Assert -Condition ($workflow.Context.Get("StepXExecuted") -eq $true) -TestName "Step before failure was executed"
    Test-Assert -Condition ($workflow.Context.Get("StepZExecuted") -eq $true) -TestName "Step after failure WAS executed (ContinueOnError)"
    
    # Test 1.4: Step returns false (treated as failure)
    Write-TestSectionHeader "Test 1.4: Step Returns False"
    
    $workflow = New-Workflow -ContinueOnError $false
    
    $workflow.AddStep("Step 1", {
        param($context)
        $context.Set("BeforeExecuted", $true)
        return $true
    })
    
    $falseStep = $workflow.AddStep("Step Returns False", {
        param($context)
        return $false
    })
    $falseStep.Retries = 1
    $falseStep.RetryDelay = 0
    
    $workflow.AddStep("Step 3", {
        param($context)
        $context.Set("AfterExecuted", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition (-not $success) -TestName "Workflow fails when step returns false"
    Test-Assert -Condition ($workflow.Context.Get("AfterExecuted") -ne $true) -TestName "Steps after false-return were not executed"
}

#endregion

#region Test Group 2: Parallel Execution Tests

function Test-ParallelExecution {
    Write-TestHeader "TEST GROUP 2: Parallel Execution"
    
    # Test 2.1: Basic parallel execution
    Write-TestSectionHeader "Test 2.1: Basic Parallel Steps (Success)"
    
    $workflow = New-Workflow
    
    $parallelGroup = $workflow.AddParallelGroup("Parallel Test")
    
    $step1 = New-WorkflowStep -Name "Parallel Step 1" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("P1", "completed")
        return "P1"
    }
    $parallelGroup.AddStep($step1)
    
    $step2 = New-WorkflowStep -Name "Parallel Step 2" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("P2", "completed")
        return "P2"
    }
    $parallelGroup.AddStep($step2)
    
    $step3 = New-WorkflowStep -Name "Parallel Step 3" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("P3", "completed")
        return "P3"
    }
    $parallelGroup.AddStep($step3)
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Parallel workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("P1") -eq "completed") -TestName "Parallel Step 1 completed"
    Test-Assert -Condition ($workflow.Context.Get("P2") -eq "completed") -TestName "Parallel Step 2 completed"
    Test-Assert -Condition ($workflow.Context.Get("P3") -eq "completed") -TestName "Parallel Step 3 completed"
    
    # Test 2.2: Parallel execution actually runs in parallel (timing test)
    Write-TestSectionHeader "Test 2.2: Parallel Timing Verification"
    
    $workflow = New-Workflow
    $parallelGroup = $workflow.AddParallelGroup("Timing Test")
    
    # 5 steps, each takes 2 seconds
    for ($i = 1; $i -le 5; $i++) {
        $step = New-WorkflowStep -Name "Timing Step $i" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Seconds 2
            `$context.Set("T$i", "done")
            return "T$i"
"@))
        $parallelGroup.AddStep($step)
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $workflow.Execute()
    $stopwatch.Stop()
    
    # If parallel, should take ~2-4 seconds. If sequential, would take ~10+ seconds
    $elapsed = $stopwatch.Elapsed.TotalSeconds
    
    Test-Assert -Condition $success -TestName "Parallel timing workflow succeeds"
    $elapsedRounded = [math]::Round($elapsed,2)
    Test-Assert -Condition ($elapsed -lt 8) -TestName "Parallel execution faster than sequential" -Message "Elapsed: ${elapsedRounded}s (expected < 8s)"
    
    # Test 2.3: Parallel with one failure (ContinueOnError = false)
    Write-TestSectionHeader "Test 2.3: Parallel with Failure (Stop on Error)"
    
    $workflow = New-Workflow -ContinueOnError $false
    $parallelGroup = $workflow.AddParallelGroup("Failure Test")
    
    $step1 = New-WorkflowStep -Name "Success Step" -Action {
        param($context)
        Start-Sleep -Milliseconds 500
        $context.Set("SuccessRan", $true)
        return "OK"
    }
    $parallelGroup.AddStep($step1)
    
    $stepFail = New-WorkflowStep -Name "Fail Step" -Action {
        param($context)
        throw "Parallel failure"
    }
    $stepFail.Retries = 1
    $stepFail.RetryDelay = 0
    $parallelGroup.AddStep($stepFail)
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition (-not $success) -TestName "Parallel workflow fails when step fails"
    
    # Test 2.4: Parallel with one failure (ContinueOnError = true)
    Write-TestSectionHeader "Test 2.4: Parallel with Failure (Continue on Error)"
    
    $workflow = New-Workflow -ContinueOnError $true
    $parallelGroup = $workflow.AddParallelGroup("Continue Test")
    
    $step1 = New-WorkflowStep -Name "Success Step A" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("SuccessA", $true)
        return "OK"
    }
    $parallelGroup.AddStep($step1)
    
    $stepFail = New-WorkflowStep -Name "Fail Step" -Action {
        param($context)
        throw "Parallel failure"
    }
    $stepFail.Retries = 1
    $stepFail.RetryDelay = 0
    $parallelGroup.AddStep($stepFail)
    
    $step2 = New-WorkflowStep -Name "Success Step B" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("SuccessB", $true)
        return "OK"
    }
    $parallelGroup.AddStep($step2)
    
    $workflow.AddStep("After Parallel", {
        param($context)
        $context.Set("AfterParallel", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Parallel workflow continues on error"
    Test-Assert -Condition ($workflow.Context.Get("SuccessA") -eq $true) -TestName "Success step A completed"
    Test-Assert -Condition ($workflow.Context.Get("SuccessB") -eq $true) -TestName "Success step B completed"
    Test-Assert -Condition ($workflow.Context.Get("AfterParallel") -eq $true) -TestName "Steps after parallel group executed"
}

#endregion

#region Test Group 3: Conditional Steps Tests

function Test-ConditionalSteps {
    Write-TestHeader "TEST GROUP 3: Conditional Steps"
    
    # Test 3.1: Condition met - step executes
    Write-TestSectionHeader "Test 3.1: Condition Met"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Setup", {
        param($context)
        $context.Set("Value", 100)
        return $true
    })
    
    $workflow.AddConditionalStep("Conditional (Should Run)",
        { param($ctx) $ctx.Get("Value") -gt 50 },
        {
            param($context)
            $context.Set("ConditionalRan", $true)
            return $true
        }
    )
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Workflow with met condition succeeds"
    Test-Assert -Condition ($workflow.Context.Get("ConditionalRan") -eq $true) -TestName "Conditional step executed when condition met"
    
    # Test 3.2: Condition not met - step skipped
    Write-TestSectionHeader "Test 3.2: Condition Not Met"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Setup", {
        param($context)
        $context.Set("Value", 25)
        return $true
    })
    
    $workflow.AddConditionalStep("Conditional (Should Skip)",
        { param($ctx) $ctx.Get("Value") -gt 50 },
        {
            param($context)
            $context.Set("ConditionalRan", $true)
            return $true
        }
    )
    
    $workflow.AddStep("After Conditional", {
        param($context)
        $context.Set("AfterRan", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Workflow with unmet condition succeeds"
    Test-Assert -Condition ($workflow.Context.Get("ConditionalRan") -ne $true) -TestName "Conditional step skipped when condition not met"
    Test-Assert -Condition ($workflow.Context.Get("AfterRan") -eq $true) -TestName "Steps after skipped conditional still execute"
    
    # Test 3.3: Multiple conditional steps
    Write-TestSectionHeader "Test 3.3: Multiple Conditional Steps"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Setup", {
        param($context)
        $context.Set("Score", 75)
        return $true
    })
    
    $workflow.AddConditionalStep("Low Score Handler",
        { param($ctx) $ctx.Get("Score") -lt 50 },
        {
            param($context)
            $context.Set("LowScoreHandled", $true)
            return $true
        }
    )
    
    $workflow.AddConditionalStep("Medium Score Handler",
        { param($ctx) $score = $ctx.Get("Score"); $score -ge 50 -and $score -lt 80 },
        {
            param($context)
            $context.Set("MediumScoreHandled", $true)
            return $true
        }
    )
    
    $workflow.AddConditionalStep("High Score Handler",
        { param($ctx) $ctx.Get("Score") -ge 80 },
        {
            param($context)
            $context.Set("HighScoreHandled", $true)
            return $true
        }
    )
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Multiple conditional workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("LowScoreHandled") -ne $true) -TestName "Low score handler skipped"
    Test-Assert -Condition ($workflow.Context.Get("MediumScoreHandled") -eq $true) -TestName "Medium score handler executed"
    Test-Assert -Condition ($workflow.Context.Get("HighScoreHandled") -ne $true) -TestName "High score handler skipped"
    
    # Test 3.4: Conditional in parallel group
    Write-TestSectionHeader "Test 3.4: Conditional Steps in Parallel Group"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Setup", {
        param($context)
        $context.Set("EnableFeatureA", $true)
        $context.Set("EnableFeatureB", $false)
        return $true
    })
    
    $parallelGroup = $workflow.AddParallelGroup("Conditional Parallel")
    
    $stepA = New-WorkflowStep -Name "Feature A" -Action {
        param($context)
        $context.Set("FeatureARan", $true)
        return "A"
    }
    # Use workflow's AddConditionalStep pattern to set type properly, or set via string
    $stepA.Type = 2  # 2 = Conditional in the StepType enum
    $stepA.Condition = { param($ctx) $ctx.Get("EnableFeatureA") -eq $true }
    $parallelGroup.AddStep($stepA)
    
    $stepB = New-WorkflowStep -Name "Feature B" -Action {
        param($context)
        $context.Set("FeatureBRan", $true)
        return "B"
    }
    $stepB.Type = 2  # 2 = Conditional in the StepType enum
    $stepB.Condition = { param($ctx) $ctx.Get("EnableFeatureB") -eq $true }
    $parallelGroup.AddStep($stepB)
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Conditional parallel workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("FeatureARan") -eq $true) -TestName "Feature A executed (condition met)"
    Test-Assert -Condition ($workflow.Context.Get("FeatureBRan") -ne $true) -TestName "Feature B skipped (condition not met)"
}

#endregion

#region Test Group 4: Dependencies Tests

function Test-Dependencies {
    Write-TestHeader "TEST GROUP 4: Dependencies"
    
    # Test 4.1: Basic dependency chain
    Write-TestSectionHeader "Test 4.1: Basic Dependency Chain"
    
    $workflow = New-Workflow
    
    $step1 = $workflow.AddStep("Base Step", {
        param($context)
        $context.Set("BaseValue", 10)
        return $true
    })
    
    $step2 = $workflow.AddDependentStep("Dependent Step", {
        param($context)
        $base = $context.Get("BaseValue")
        $context.Set("DependentValue", $base * 2)
        return $true
    }, @($step1.Id))
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Dependency chain succeeds"
    Test-Assert -Condition ($workflow.Context.Get("DependentValue") -eq 20) -TestName "Dependent step used base step's output"
    
    # Test 4.2: Multiple dependencies
    Write-TestSectionHeader "Test 4.2: Multiple Dependencies"
    
    $workflow = New-Workflow
    
    $stepA = $workflow.AddStep("Step A", {
        param($context)
        $context.Set("A", 5)
        return $true
    })
    
    $stepB = $workflow.AddStep("Step B", {
        param($context)
        $context.Set("B", 3)
        return $true
    })
    
    $stepC = $workflow.AddDependentStep("Step C (depends on A and B)", {
        param($context)
        $a = $context.Get("A")
        $b = $context.Get("B")
        $context.Set("C", $a + $b)
        return $true
    }, @($stepA.Id, $stepB.Id))
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Multiple dependencies workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("C") -eq 8) -TestName "Step C computed correctly from A and B"
    
    # Test 4.3: Dependencies in parallel groups
    Write-TestSectionHeader "Test 4.3: Dependencies in Parallel Groups"
    
    $workflow = New-Workflow
    
    # First parallel group - extract
    $extractGroup = $workflow.AddParallelGroup("Extract")
    
    $extractDB1 = New-WorkflowStep -Name "Extract DB1" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("DB1_Data", 100)
        return 100
    }
    $extractGroup.AddStep($extractDB1)
    
    $extractDB2 = New-WorkflowStep -Name "Extract DB2" -Action {
        param($context)
        Start-Sleep -Milliseconds 100
        $context.Set("DB2_Data", 200)
        return 200
    }
    $extractGroup.AddStep($extractDB2)
    
    # Second parallel group - transform (with dependencies)
    $transformGroup = $workflow.AddParallelGroup("Transform")
    
    $transformDB1 = New-WorkflowStep -Name "Transform DB1" -Action {
        param($context)
        $data = $context.Get("DB1_Data")
        $context.Set("DB1_Transformed", $data * 2)
        return $data * 2
    }
    $transformDB1.DependsOn = @($extractDB1.Id)
    $transformGroup.AddStep($transformDB1)
    
    $transformDB2 = New-WorkflowStep -Name "Transform DB2" -Action {
        param($context)
        $data = $context.Get("DB2_Data")
        $context.Set("DB2_Transformed", $data * 2)
        return $data * 2
    }
    $transformDB2.DependsOn = @($extractDB2.Id)
    $transformGroup.AddStep($transformDB2)
    
    # Final merge step
    $workflow.AddStep("Merge", {
        param($context)
        $t1 = $context.Get("DB1_Transformed")
        $t2 = $context.Get("DB2_Transformed")
        $context.Set("MergedTotal", $t1 + $t2)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Parallel dependencies workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("DB1_Transformed") -eq 200) -TestName "DB1 transformed correctly"
    Test-Assert -Condition ($workflow.Context.Get("DB2_Transformed") -eq 400) -TestName "DB2 transformed correctly"
    Test-Assert -Condition ($workflow.Context.Get("MergedTotal") -eq 600) -TestName "Merge computed correctly"
    
    # Test 4.4: Dependency on skipped step
    Write-TestSectionHeader "Test 4.4: Dependency on Skipped Step"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Setup", {
        param($context)
        $context.Set("SkipNext", $true)
        return $true
    })
    
    $conditionalStep = $workflow.AddConditionalStep("Maybe Run",
        { param($ctx) $ctx.Get("SkipNext") -ne $true },
        {
            param($context)
            $context.Set("MaybeRan", $true)
            return $true
        }
    )
    
    $dependentStep = $workflow.AddDependentStep("After Maybe", {
        param($context)
        $context.Set("AfterMaybeRan", $true)
        return $true
    }, @($conditionalStep.Id))
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Workflow with skipped dependency succeeds"
    Test-Assert -Condition ($workflow.Context.Get("MaybeRan") -ne $true) -TestName "Conditional step was skipped"
    Test-Assert -Condition ($workflow.Context.Get("AfterMaybeRan") -eq $true) -TestName "Dependent step ran after skipped step"
}

#endregion

#region Test Group 5: Retry Tests

function Test-Retries {
    Write-TestHeader "TEST GROUP 5: Retries"
    
    # Test 5.1: Step-level retries succeed on retry
    Write-TestSectionHeader "Test 5.1: Step Retries - Success on Second Attempt"
    
    $workflow = New-Workflow
    
    $flakyStep = $workflow.AddStep("Flaky Step", {
        param($context)
        $attempts = $context.Get("Attempts")
        if ($null -eq $attempts) { $attempts = 0 }
        $attempts++
        $context.Set("Attempts", $attempts)
        
        if ($attempts -lt 2) {
            throw "Temporary failure"
        }
        
        $context.Set("FinallySucceeded", $true)
        return $true
    })
    $flakyStep.Retries = 3
    $flakyStep.RetryDelay = 0
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Flaky step eventually succeeds"
    Test-Assert -Condition ($workflow.Context.Get("Attempts") -eq 2) -TestName "Step took 2 attempts"
    Test-Assert -Condition ($workflow.Context.Get("FinallySucceeded") -eq $true) -TestName "Step reported success"
    
    # Test 5.2: Step-level retries all fail
    Write-TestSectionHeader "Test 5.2: Step Retries - All Attempts Fail"
    
    $workflow = New-Workflow -ContinueOnError $false
    
    $alwaysFailStep = $workflow.AddStep("Always Fails", {
        param($context)
        $attempts = $context.Get("FailAttempts")
        if ($null -eq $attempts) { $attempts = 0 }
        $attempts++
        $context.Set("FailAttempts", $attempts)
        throw "Always fails"
    })
    $alwaysFailStep.Retries = 3
    $alwaysFailStep.RetryDelay = 0
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition (-not $success) -TestName "Workflow fails after all retries exhausted"
    Test-Assert -Condition ($workflow.Context.Get("FailAttempts") -eq 3) -TestName "Step attempted 3 times"
    
    # Test 5.3: Workflow-level retries
    Write-TestSectionHeader "Test 5.3: Workflow-Level Retries"
    
    # Use a script-scope variable to track workflow attempts
    $script:WorkflowAttempts = 0
    
    $workflow = New-Workflow -WorkflowRetries 3 -WorkflowDelay 0 -ContinueOnError $false
    
    $failOnFirstWorkflowRun = $workflow.AddStep("Fail First Workflow Run", {
        param($context)
        $script:WorkflowAttempts++
        
        if ($script:WorkflowAttempts -lt 2) {
            throw "Workflow-level failure"
        }
        
        $context.Set("WorkflowSuccess", $true)
        return $true
    })
    $failOnFirstWorkflowRun.Retries = 1
    $failOnFirstWorkflowRun.RetryDelay = 0
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Workflow eventually succeeds after retry"
    Test-Assert -Condition ($script:WorkflowAttempts -eq 2) -TestName "Workflow ran twice"
    Test-Assert -Condition ($workflow.Context.Get("WorkflowSuccess") -eq $true) -TestName "Workflow reported success"
    
    # Test 5.4: Parallel step retries
    Write-TestSectionHeader "Test 5.4: Parallel Step Retries"
    
    $script:ParallelRetryCount = 0
    
    $workflow = New-Workflow
    $parallelGroup = $workflow.AddParallelGroup("Retry Test")
    
    $flakyParallel = New-WorkflowStep -Name "Flaky Parallel" -Action ([scriptblock]::Create(@"
        param(`$context)
        `$script:ParallelRetryCount++
        if (`$script:ParallelRetryCount -lt 2) {
            throw "Parallel retry test"
        }
        `$context.Set("ParallelSucceeded", `$true)
        return `$true
"@))
    $flakyParallel.Retries = 3
    $flakyParallel.RetryDelay = 0
    $parallelGroup.AddStep($flakyParallel)
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Parallel step with retries succeeds"
}

#endregion

#region Test Group 6: Context Tests

function Test-Context {
    Write-TestHeader "TEST GROUP 6: Context Sharing"
    
    # Test 6.1: Context values persist across sequential steps
    Write-TestSectionHeader "Test 6.1: Sequential Context Persistence"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Set Values", {
        param($context)
        $context.Set("StringVal", "hello")
        $context.Set("IntVal", 42)
        $context.Set("ArrayVal", @(1, 2, 3))
        $context.Set("HashVal", @{ key = "value" })
        return $true
    })
    
    $workflow.AddStep("Read Values", {
        param($context)
        $s = $context.Get("StringVal")
        $i = $context.Get("IntVal")
        $a = $context.Get("ArrayVal")
        $h = $context.Get("HashVal")
        
        $context.Set("StringMatch", $s -eq "hello")
        $context.Set("IntMatch", $i -eq 42)
        $context.Set("ArrayMatch", $a.Count -eq 3)
        $context.Set("HashMatch", $h.key -eq "value")
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Context persistence workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("StringMatch") -eq $true) -TestName "String value persisted"
    Test-Assert -Condition ($workflow.Context.Get("IntMatch") -eq $true) -TestName "Integer value persisted"
    Test-Assert -Condition ($workflow.Context.Get("ArrayMatch") -eq $true) -TestName "Array value persisted"
    Test-Assert -Condition ($workflow.Context.Get("HashMatch") -eq $true) -TestName "Hashtable value persisted"
    
    # Test 6.2: Context updates from parallel steps merge
    Write-TestSectionHeader "Test 6.2: Parallel Context Merging"
    
    $workflow = New-Workflow
    
    $parallelGroup = $workflow.AddParallelGroup("Context Merge Test")
    
    for ($i = 1; $i -le 5; $i++) {
        $step = New-WorkflowStep -Name "Set Value $i" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Milliseconds 100
            `$context.Set("Value$i", $($i * 10))
            return `$true
"@))
        $parallelGroup.AddStep($step)
    }
    
    $workflow.AddStep("Verify Merge", {
        param($context)
        $sum = 0
        for ($j = 1; $j -le 5; $j++) {
            $val = $context.Get("Value$j")
            if ($null -ne $val) { $sum += $val }
        }
        $context.Set("Sum", $sum)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Parallel context merge workflow succeeds"
    # Sum should be 10+20+30+40+50 = 150
    Test-Assert -Condition ($workflow.Context.Get("Sum") -eq 150) -TestName "All parallel values merged correctly"
    
    # Test 6.3: GetValue/SetValue aliases work
    Write-TestSectionHeader "Test 6.3: GetValue/SetValue Aliases"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Test Aliases", {
        param($context)
        $context.SetValue("AliasTest", "works")
        $val = $context.GetValue("AliasTest")
        $context.Set("AliasVerified", $val -eq "works")
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Alias methods work correctly"
    Test-Assert -Condition ($workflow.Context.Get("AliasVerified") -eq $true) -TestName "SetValue/GetValue produced correct result"
    
    # Test 6.4: Context resets between workflow retries
    Write-TestSectionHeader "Test 6.4: Context Reset on Workflow Retry"
    
    $script:RetryContextAttempt = 0
    
    $workflow = New-Workflow -WorkflowRetries 2 -WorkflowDelay 0
    
    $workflow.AddStep("Set and Check", {
        param($context)
        $script:RetryContextAttempt++
        
        $existing = $context.Get("PreviousValue")
        $context.Set("HadPreviousValue", ($null -ne $existing))
        $context.Set("PreviousValue", "set")
        
        if ($script:RetryContextAttempt -lt 2) {
            throw "Force retry"
        }
        
        return $true
    }).Retries = 1
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Context reset workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("HadPreviousValue") -eq $false) -TestName "Context was reset between workflow retries"
}

#endregion

#region Test Group 7: Mixed Workflow Tests

function Test-MixedWorkflows {
    Write-TestHeader "TEST GROUP 7: Mixed Workflows (Sequential + Parallel)"
    
    # Test 7.1: Sequential -> Parallel -> Sequential
    Write-TestSectionHeader "Test 7.1: Sequential-Parallel-Sequential Pattern"
    
    $workflow = New-Workflow
    
    # Sequential setup
    $workflow.AddStep("Initialize", {
        param($context)
        $context.Set("Initialized", $true)
        $context.Set("Counter", 0)
        return $true
    })
    
    # Parallel processing
    $parallelGroup = $workflow.AddParallelGroup("Process")
    
    for ($i = 1; $i -le 3; $i++) {
        $step = New-WorkflowStep -Name "Process $i" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Milliseconds 100
            `$context.Set("Processed$i", `$true)
            return `$true
"@))
        $parallelGroup.AddStep($step)
    }
    
    # Sequential finalize
    $workflow.AddStep("Finalize", {
        param($context)
        $count = 0
        for ($j = 1; $j -le 3; $j++) {
            if ($context.Get("Processed$j") -eq $true) { $count++ }
        }
        $context.Set("ProcessedCount", $count)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Mixed workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("Initialized") -eq $true) -TestName "Sequential setup ran"
    Test-Assert -Condition ($workflow.Context.Get("ProcessedCount") -eq 3) -TestName "All parallel steps ran"
    
    # Test 7.2: Multiple parallel groups
    Write-TestSectionHeader "Test 7.2: Multiple Parallel Groups"
    
    $workflow = New-Workflow
    
    $group1 = $workflow.AddParallelGroup("Group 1")
    $step1a = New-WorkflowStep -Name "1A" -Action { param($c) $c.Set("G1A", $true); return $true }
    $step1b = New-WorkflowStep -Name "1B" -Action { param($c) $c.Set("G1B", $true); return $true }
    $group1.AddStep($step1a)
    $group1.AddStep($step1b)
    
    $workflow.AddStep("Between Groups", {
        param($context)
        $context.Set("BetweenRan", $true)
        return $true
    })
    
    $group2 = $workflow.AddParallelGroup("Group 2")
    $step2a = New-WorkflowStep -Name "2A" -Action { param($c) $c.Set("G2A", $true); return $true }
    $step2b = New-WorkflowStep -Name "2B" -Action { param($c) $c.Set("G2B", $true); return $true }
    $group2.AddStep($step2a)
    $group2.AddStep($step2b)
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Multiple parallel groups workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("G1A") -eq $true) -TestName "Group 1A ran"
    Test-Assert -Condition ($workflow.Context.Get("G1B") -eq $true) -TestName "Group 1B ran"
    Test-Assert -Condition ($workflow.Context.Get("BetweenRan") -eq $true) -TestName "Sequential between groups ran"
    Test-Assert -Condition ($workflow.Context.Get("G2A") -eq $true) -TestName "Group 2A ran"
    Test-Assert -Condition ($workflow.Context.Get("G2B") -eq $true) -TestName "Group 2B ran"
    
    # Test 7.3: Complex ETL-like workflow
    Write-TestSectionHeader "Test 7.3: Complex ETL Pattern"
    
    $workflow = New-Workflow
    
    # Extract phase (parallel)
    $extractGroup = $workflow.AddParallelGroup("Extract")
    $sources = @("SQL", "API", "File")
    $extractSteps = @{}
    
    foreach ($src in $sources) {
        $step = New-WorkflowStep -Name "Extract $src" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Milliseconds 50
            `$context.Set("${src}_Raw", 100)
            return 100
"@))
        $extractGroup.AddStep($step)
        $extractSteps[$src] = $step
    }
    
    # Transform phase (sequential)
    $workflow.AddStep("Transform All", {
        param($context)
        $total = 0
        @("SQL", "API", "File") | ForEach-Object {
            $val = $context.Get("${_}_Raw")
            if ($val) { $total += $val }
        }
        $context.Set("TransformedTotal", $total * 2)
        return $true
    })
    
    # Load phase (parallel)
    $loadGroup = $workflow.AddParallelGroup("Load")
    $targets = @("DW", "Cache", "Archive")
    
    foreach ($tgt in $targets) {
        $step = New-WorkflowStep -Name "Load $tgt" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Milliseconds 50
            `$total = `$context.Get("TransformedTotal")
            `$context.Set("${tgt}_Loaded", `$total)
            return `$true
"@))
        $loadGroup.AddStep($step)
    }
    
    # Verify
    $workflow.AddStep("Verify", {
        param($context)
        $loaded = 0
        @("DW", "Cache", "Archive") | ForEach-Object {
            $val = $context.Get("${_}_Loaded")
            if ($val) { $loaded++ }
        }
        $context.Set("TargetsLoaded", $loaded)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Complex ETL workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("TransformedTotal") -eq 600) -TestName "Transform calculated correctly (3*100*2=600)"
    Test-Assert -Condition ($workflow.Context.Get("TargetsLoaded") -eq 3) -TestName "All targets received data"
}

#endregion

#region Test Group 8: Edge Cases

function Test-EdgeCases {
    Write-TestHeader "TEST GROUP 8: Edge Cases"
    
    # Test 8.1: Empty workflow
    Write-TestSectionHeader "Test 8.1: Empty Workflow"
    
    $workflow = New-Workflow
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Empty workflow succeeds"
    
    # Test 8.2: Single step workflow
    Write-TestSectionHeader "Test 8.2: Single Step Workflow"
    
    $workflow = New-Workflow
    $workflow.AddStep("Only Step", {
        param($context)
        $context.Set("SingleRan", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Single step workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("SingleRan") -eq $true) -TestName "Single step executed"
    
    # Test 8.3: Empty parallel group
    Write-TestSectionHeader "Test 8.3: Empty Parallel Group"
    
    $workflow = New-Workflow
    $workflow.AddStep("Before", { param($c) $c.Set("Before", $true); return $true })
    $emptyGroup = $workflow.AddParallelGroup("Empty Group")
    $workflow.AddStep("After", { param($c) $c.Set("After", $true); return $true })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Empty parallel group workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("Before") -eq $true) -TestName "Step before empty group ran"
    Test-Assert -Condition ($workflow.Context.Get("After") -eq $true) -TestName "Step after empty group ran"
    
    # Test 8.4: All parallel steps skip (conditions not met)
    Write-TestSectionHeader "Test 8.4: All Parallel Steps Skipped"
    
    $workflow = New-Workflow
    $workflow.AddStep("Setup", { param($c) $c.Set("SkipAll", $true); return $true })
    
    $parallelGroup = $workflow.AddParallelGroup("All Skip")
    
    for ($i = 1; $i -le 3; $i++) {
        $step = New-WorkflowStep -Name "Skip Step $i" -Action {
            param($context)
            $context.Set("ShouldNotRun$i", $true)
            return $true
        }
        $step.Type = 2  # 2 = Conditional in the StepType enum
        $step.Condition = { param($ctx) $ctx.Get("SkipAll") -ne $true }
        $parallelGroup.AddStep($step)
    }
    
    $workflow.AddStep("After Skips", { param($c) $c.Set("AfterSkips", $true); return $true })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "All skipped parallel group workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("ShouldNotRun1") -ne $true) -TestName "Skip step 1 did not run"
    Test-Assert -Condition ($workflow.Context.Get("AfterSkips") -eq $true) -TestName "Step after all-skipped group ran"
    
    # Test 8.5: Long-running step
    Write-TestSectionHeader "Test 8.5: Long-Running Step"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Long Running", {
        param($context)
        Start-Sleep -Seconds 3
        $context.Set("LongRunComplete", $true)
        return $true
    })
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $workflow.Execute()
    $stopwatch.Stop()
    
    Test-Assert -Condition $success -TestName "Long-running step workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("LongRunComplete") -eq $true) -TestName "Long-running step completed"
    Test-Assert -Condition ($stopwatch.Elapsed.TotalSeconds -ge 2.5) -TestName "Step actually took expected time"
    
    # Test 8.6: Null return from step
    Write-TestSectionHeader "Test 8.6: Step Returns Null"
    
    $workflow = New-Workflow
    
    $workflow.AddStep("Return Null", {
        param($context)
        $context.Set("NullStepRan", $true)
        return $null
    })
    
    $workflow.AddStep("After Null", {
        param($context)
        $context.Set("AfterNull", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Null return workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("NullStepRan") -eq $true) -TestName "Null-returning step ran"
    Test-Assert -Condition ($workflow.Context.Get("AfterNull") -eq $true) -TestName "Step after null ran"
    
    # Test 8.7: Condition that throws
    Write-TestSectionHeader "Test 8.7: Condition Throws Exception"
    
    $workflow = New-Workflow
    
    $workflow.AddConditionalStep("Throwing Condition",
        { throw "Condition error" },
        {
            param($context)
            $context.Set("ThrowingConditionRan", $true)
            return $true
        }
    )
    
    $workflow.AddStep("After Throwing Condition", {
        param($context)
        $context.Set("AfterThrowingCondition", $true)
        return $true
    })
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Throwing condition workflow succeeds"
    Test-Assert -Condition ($workflow.Context.Get("ThrowingConditionRan") -ne $true) -TestName "Step with throwing condition was skipped"
    Test-Assert -Condition ($workflow.Context.Get("AfterThrowingCondition") -eq $true) -TestName "Steps after throwing condition ran"
}

#endregion

#region Test Group 9: PrintSummary Tests

function Test-PrintSummary {
    Write-TestHeader "TEST GROUP 9: PrintSummary"
    
    # Test 9.1: Summary after successful workflow
    Write-TestSectionHeader "Test 9.1: Summary After Success"
    
    $workflow = New-Workflow
    $workflow.AddStep("Step 1", { param($c) return $true })
    $workflow.AddStep("Step 2", { param($c) return $true })
    
    $success = $workflow.Execute()
    
    # PrintSummary should not throw
    try {
        $workflow.PrintSummary()
        Test-Assert -Condition $true -TestName "PrintSummary after success doesn't throw"
    } catch {
        Test-Assert -Condition $false -TestName "PrintSummary after success doesn't throw" -Message $_.ToString()
    }
    
    # Test 9.2: Summary after failed workflow
    Write-TestSectionHeader "Test 9.2: Summary After Failure"
    
    $workflow = New-Workflow -ContinueOnError $false
    $workflow.AddStep("Failing Step", { throw "Test failure" }).Retries = 1
    
    $success = $workflow.Execute()
    
    try {
        $workflow.PrintSummary()
        Test-Assert -Condition $true -TestName "PrintSummary after failure doesn't throw"
    } catch {
        Test-Assert -Condition $false -TestName "PrintSummary after failure doesn't throw" -Message $_.ToString()
    }
    
    # Test 9.3: Summary with mixed statuses
    Write-TestSectionHeader "Test 9.3: Summary With Mixed Statuses"
    
    $workflow = New-Workflow -ContinueOnError $true
    $workflow.AddStep("Succeeded", { return $true })
    $workflow.AddConditionalStep("Skipped", { $false }, { return $true })
    $failStep = $workflow.AddStep("Failed", { throw "fail" })
    $failStep.Retries = 1
    $failStep.RetryDelay = 0
    
    $success = $workflow.Execute()
    
    try {
        $workflow.PrintSummary()
        Test-Assert -Condition $true -TestName "PrintSummary with mixed statuses doesn't throw"
    } catch {
        Test-Assert -Condition $false -TestName "PrintSummary with mixed statuses doesn't throw" -Message $_.ToString()
    }
}

#endregion

#region Test Group 10: Stress Tests

function Test-Stress {
    Write-TestHeader "TEST GROUP 10: Stress Tests"
    
    # Test 10.1: Many sequential steps
    Write-TestSectionHeader "Test 10.1: Many Sequential Steps (50)"
    
    $workflow = New-Workflow
    
    for ($i = 1; $i -le 50; $i++) {
        $workflow.AddStep("Step $i", [scriptblock]::Create(@"
            param(`$context)
            `$count = `$context.Get("Counter")
            if (`$null -eq `$count) { `$count = 0 }
            `$context.Set("Counter", `$count + 1)
            return `$true
"@))
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $workflow.Execute()
    $stopwatch.Stop()
    
    Test-Assert -Condition $success -TestName "50 sequential steps succeed"
    Test-Assert -Condition ($workflow.Context.Get("Counter") -eq 50) -TestName "All 50 steps executed"
    $elapsed1 = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    Write-Log "  Elapsed: ${elapsed1}s"
    
    # Test 10.2: Many parallel steps
    Write-TestSectionHeader "Test 10.2: Many Parallel Steps (20)"
    
    $workflow = New-Workflow
    $parallelGroup = $workflow.AddParallelGroup("Large Parallel")
    
    for ($i = 1; $i -le 20; $i++) {
        $step = New-WorkflowStep -Name "Parallel $i" -Action ([scriptblock]::Create(@"
            param(`$context)
            Start-Sleep -Milliseconds 500
            `$context.Set("P$i", `$true)
            return `$true
"@))
        $parallelGroup.AddStep($step)
    }
    
    $workflow.AddStep("Count Results", {
        param($context)
        $count = 0
        for ($j = 1; $j -le 20; $j++) {
            if ($context.Get("P$j") -eq $true) { $count++ }
        }
        $context.Set("ParallelCount", $count)
        return $true
    })
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $success = $workflow.Execute()
    $stopwatch.Stop()
    
    Test-Assert -Condition $success -TestName "20 parallel steps succeed"
    Test-Assert -Condition ($workflow.Context.Get("ParallelCount") -eq 20) -TestName "All 20 parallel steps executed"
    $elapsed2 = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    Test-Assert -Condition ($stopwatch.Elapsed.TotalSeconds -lt 25) -TestName "Parallel execution was reasonably fast" -Message "Took ${elapsed2}s"
    Write-Log "  Elapsed: ${elapsed2}s"
    
    # Test 10.3: Deep dependency chain
    Write-TestSectionHeader "Test 10.3: Deep Dependency Chain (10 levels)"
    
    $workflow = New-Workflow
    
    $prevStep = $workflow.AddStep("Base", {
        param($context)
        $context.Set("ChainValue", 1)
        return $true
    })
    
    for ($i = 1; $i -le 9; $i++) {
        $prevStep = $workflow.AddDependentStep("Chain $i", [scriptblock]::Create(@"
            param(`$context)
            `$val = `$context.Get("ChainValue")
            `$context.Set("ChainValue", `$val + 1)
            return `$true
"@), @($prevStep.Id))
    }
    
    $success = $workflow.Execute()
    
    Test-Assert -Condition $success -TestName "Deep dependency chain succeeds"
    Test-Assert -Condition ($workflow.Context.Get("ChainValue") -eq 10) -TestName "All chain steps executed in order"
}

#endregion

#region Run All Tests

function Run-AllTests {
    Write-Log ''
    Write-Log '========================================================================' -Level Header
    Write-Log '          WORKFLOW ENGINE COMPREHENSIVE TEST SUITE                      ' -Level Header
    Write-Log '========================================================================' -Level Header
    Write-Log ''
    
    Reset-TestResults
    $overallStart = Get-Date
    
    Test-SequentialExecution
    Test-ParallelExecution
    Test-ConditionalSteps
    Test-Dependencies
    Test-Retries
    Test-Context
    Test-MixedWorkflows
    Test-EdgeCases
    Test-PrintSummary
    Test-Stress
    
    $overallEnd = Get-Date
    $totalTime = ($overallEnd - $overallStart).TotalSeconds
    
    Write-TestSummary
    
    $timeStr = [math]::Round($totalTime, 2)
    Write-Log "  Total Test Time: $timeStr seconds" -Level Header
    Write-Log ''
    
    # Write final status to log
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
}

#endregion

#region Entry Point

# Initialize the log file
Initialize-LogFile

$null = Run-AllTests
$allPassed = ($script:TestResults.Failed -eq 0)

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
