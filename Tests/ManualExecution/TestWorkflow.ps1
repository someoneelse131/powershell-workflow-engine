<#
.SYNOPSIS
    Test Workflow for Manual/Interactive Execution Testing
    
.DESCRIPTION
    This workflow contains a mix of sequential and parallel steps designed
    to test the interactive execution mode (ExecuteInteractive).
    
    Structure:
    - 2 Sequential setup steps
    - 1 Parallel group with 3 steps
    - 1 Sequential middle step
    - 1 Parallel group with 2 steps  
    - 2 Sequential cleanup steps
    - 1 Conditional step
    
    Total: 11 steps (4 sequential + 5 parallel + 1 conditional)

.NOTES
    This file defines the workflow. Use Test-ManualExecution.ps1 to run tests.
    IMPORTANT: Caller must load WorkflowEngine.ps1 before dot-sourcing this file.
#>

# Note: WorkflowEngine.ps1 must be loaded by the caller before this file

function New-TestWorkflow {
    <#
    .SYNOPSIS
        Creates a test workflow with mixed serial/parallel steps
    .PARAMETER ContinueOnError
        If true, workflow continues after step failures
    .PARAMETER IncludeFailingStep
        If true, step 8 (Integration Tests) will always fail
    .PARAMETER IncludeFailingParallelStep
        If true, adds an extra failing step to the first parallel group
    .PARAMETER IncludeFailingSequentialStep
        If true, step 2 (Load Configuration) will always fail
    #>
    param(
        [switch]$ContinueOnError,
        [switch]$IncludeFailingStep,
        [switch]$IncludeFailingParallelStep,
        [switch]$IncludeFailingSequentialStep
    )
    
    $workflow = New-Workflow -ContinueOnError:$ContinueOnError
    
    # =========================================================================
    # SEQUENTIAL SETUP STEPS (1-2)
    # =========================================================================
    
    $null = $workflow.AddStep("Step 1: Initialize Environment", {
        param($ctx)
        Write-Host "  [INIT] Setting up test environment..."
        Start-Sleep -Milliseconds 200
        $ctx.Set("initialized", $true)
        $ctx.Set("startTime", (Get-Date))
        $ctx.Set("stepLog", @("Step1"))
        Write-Host "  [INIT] Environment ready"
        return $true
    })
    
    if ($IncludeFailingSequentialStep) {
        $failSeqStep = $workflow.AddStep("Step 2: Load Configuration (Fails)", {
            param($ctx)
            Write-Host "  [CONFIG] Loading configuration..."
            Start-Sleep -Milliseconds 100
            throw "Simulated configuration load failure"
        })
        $failSeqStep.Retries = 1
        $failSeqStep.RetryDelay = 0
    } else {
        $null = $workflow.AddStep("Step 2: Load Configuration", {
            param($ctx)
            Write-Host "  [CONFIG] Loading configuration..."
            Start-Sleep -Milliseconds 150
            $ctx.Set("configLoaded", $true)
            $ctx.Set("version", "1.0.0")
            $log = $ctx.Get("stepLog")
            $log += "Step2"
            $ctx.Set("stepLog", $log)
            Write-Host "  [CONFIG] Configuration loaded (v$($ctx.Get('version')))"
            return $true
        })
    }
    
    # =========================================================================
    # FIRST PARALLEL GROUP (Steps 3-5)
    # =========================================================================
    
    $buildGroup = $workflow.AddParallelGroup("Parallel Group 1: Build Services")
    
    $buildGroup.AddStep((New-WorkflowStep -Name "Step 3: Build API" -Action {
        param($ctx)
        Write-Host "  [API] Building API service..."
        Start-Sleep -Milliseconds 500
        $ctx.Set("apiBuild", "success")
        Write-Host "  [API] Build complete"
        return $true
    }))
    
    $buildGroup.AddStep((New-WorkflowStep -Name "Step 4: Build Frontend" -Action {
        param($ctx)
        Write-Host "  [WEB] Building frontend..."
        Start-Sleep -Milliseconds 600
        $ctx.Set("webBuild", "success")
        Write-Host "  [WEB] Build complete"
        return $true
    }))
    
    $buildGroup.AddStep((New-WorkflowStep -Name "Step 5: Build Worker" -Action {
        param($ctx)
        Write-Host "  [WORKER] Building worker service..."
        Start-Sleep -Milliseconds 400
        $ctx.Set("workerBuild", "success")
        Write-Host "  [WORKER] Build complete"
        return $true
    }))
    
    # Optional: Add a failing parallel step
    if ($IncludeFailingParallelStep) {
        $failParallelStep = New-WorkflowStep -Name "Step 5b: Build Mobile (Fails)" -Action {
            param($ctx)
            Write-Host "  [MOBILE] Building mobile app..."
            Start-Sleep -Milliseconds 200
            throw "Simulated mobile build failure"
        }
        $failParallelStep.Retries = 1
        $failParallelStep.RetryDelay = 0
        $buildGroup.AddStep($failParallelStep)
    }
    
    # =========================================================================
    # SEQUENTIAL MIDDLE STEP (6)
    # =========================================================================
    
    $null = $workflow.AddStep("Step 6: Validate Builds", {
        param($ctx)
        Write-Host "  [VALIDATE] Checking build results..."
        Start-Sleep -Milliseconds 200
        
        $api = $ctx.Get("apiBuild")
        $web = $ctx.Get("webBuild")
        $worker = $ctx.Get("workerBuild")
        
        $allSuccess = ($api -eq "success") -and ($web -eq "success") -and ($worker -eq "success")
        $ctx.Set("buildsValidated", $allSuccess)
        
        if ($allSuccess) {
            Write-Host "  [VALIDATE] All builds validated successfully"
        } else {
            Write-Host "  [VALIDATE] Some builds may not have run yet"
        }
        
        return $true
    })
    
    # =========================================================================
    # SECOND PARALLEL GROUP (Steps 7-8)
    # =========================================================================
    
    $testGroup = $workflow.AddParallelGroup("Parallel Group 2: Run Tests")
    
    $testGroup.AddStep((New-WorkflowStep -Name "Step 7: Unit Tests" -Action {
        param($ctx)
        Write-Host "  [UNIT] Running unit tests..."
        Start-Sleep -Milliseconds 400
        $ctx.Set("unitTests", "passed")
        Write-Host "  [UNIT] 156 tests passed"
        return $true
    }))
    
    if ($IncludeFailingStep) {
        $failStep = New-WorkflowStep -Name "Step 8: Integration Tests (Fails)" -Action {
            param($ctx)
            Write-Host "  [INTEGRATION] Running integration tests..."
            Start-Sleep -Milliseconds 300
            throw "Simulated integration test failure"
        }
        $failStep.Retries = 1
        $failStep.RetryDelay = 0
        $testGroup.AddStep($failStep)
    } else {
        $testGroup.AddStep((New-WorkflowStep -Name "Step 8: Integration Tests" -Action {
            param($ctx)
            Write-Host "  [INTEGRATION] Running integration tests..."
            Start-Sleep -Milliseconds 500
            $ctx.Set("integrationTests", "passed")
            Write-Host "  [INTEGRATION] 42 tests passed"
            return $true
        }))
    }
    
    # =========================================================================
    # SEQUENTIAL CLEANUP STEPS (9-10)
    # =========================================================================
    
    $null = $workflow.AddStep("Step 9: Generate Reports", {
        param($ctx)
        Write-Host "  [REPORT] Generating test reports..."
        Start-Sleep -Milliseconds 200
        $ctx.Set("reportsGenerated", $true)
        Write-Host "  [REPORT] Reports saved to ./reports/"
        return $true
    })
    
    $null = $workflow.AddStep("Step 10: Notify Team", {
        param($ctx)
        Write-Host "  [NOTIFY] Sending notifications..."
        Start-Sleep -Milliseconds 100
        $ctx.Set("notificationsSent", $true)
        Write-Host "  [NOTIFY] Team notified via Slack"
        return $true
    })
    
    # =========================================================================
    # CONDITIONAL STEP (11)
    # =========================================================================
    
    $null = $workflow.AddConditionalStep("Step 11: Deploy (if all tests passed)",
        { 
            param($ctx) 
            $unit = $ctx.Get("unitTests")
            $integration = $ctx.Get("integrationTests")
            return ($unit -eq "passed") -and ($integration -eq "passed")
        },
        {
            param($ctx)
            Write-Host "  [DEPLOY] Deploying to staging..."
            Start-Sleep -Milliseconds 300
            $ctx.Set("deployed", $true)
            Write-Host "  [DEPLOY] Deployment complete!"
            return $true
        }
    )
    
    return $workflow
}
