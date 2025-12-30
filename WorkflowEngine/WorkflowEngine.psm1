#requires -Version 5.1

<#
.SYNOPSIS
    Enhanced Workflow Engine with Runspaces - PowerShell 5.1+ Compatible
.DESCRIPTION
    Provides sequential, parallel, and conditional workflow execution using runspace pools
    for efficient parallel processing.
#>

#region Enums

enum StepType {
    Sequential
    Parallel
    Conditional
}

enum StepStatus {
    Pending
    Running
    Completed
    Failed
    Skipped
}

#endregion

#region Classes

class WorkflowContext {
    [hashtable]$Variables
    
    WorkflowContext() {
        $this.Variables = @{}
    }
    
    [void] SetValue([string]$key, [object]$value) {
        $this.Variables[$key] = $value
    }
    
    [void] Set([string]$key, [object]$value) {
        $this.Variables[$key] = $value
    }
    
    [object] GetValue([string]$key) {
        if ($this.Variables.ContainsKey($key)) {
            return $this.Variables[$key]
        }
        return $null
    }
    
    [object] Get([string]$key) {
        if ($this.Variables.ContainsKey($key)) {
            return $this.Variables[$key]
        }
        return $null
    }
    
    [hashtable] GetSnapshot() {
        return $this.Variables.Clone()
    }
    
    [void] MergeUpdates([hashtable]$updates) {
        if ($null -ne $updates) {
            foreach ($key in $updates.Keys) {
                $this.SetValue($key, $updates[$key])
            }
        }
    }
}

class WorkflowStep {
    [string]$Name
    [string]$Id
    [StepType]$Type
    [scriptblock]$Action
    [scriptblock]$Condition
    [string[]]$DependsOn
    [int]$Retries
    [int]$RetryDelay
    [int]$Timeout
    [StepStatus]$Status
    [object]$Result
    [string]$ErrorMessage
    [datetime]$StartTime
    [datetime]$EndTime
    
    WorkflowStep([string]$name, [scriptblock]$action) {
        $this.Name = $name
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Type = [StepType]::Sequential
        $this.Action = $action
        $this.Condition = { $true }
        $this.DependsOn = @()
        $this.Retries = 3
        $this.RetryDelay = 30
        $this.Timeout = 0
        $this.Status = [StepStatus]::Pending
        $this.StartTime = [datetime]::MinValue
        $this.EndTime = [datetime]::MinValue
    }
    
    [bool] ShouldExecute([object]$context) {
        try {
            $contextResult = & $this.Condition $context
            return $contextResult
        } catch {
            return $false
        }
    }
    
    [bool] AreDependenciesMet([hashtable]$completedSteps) {
        if ($this.DependsOn.Count -eq 0) {
            return $true
        }
        
        foreach ($depId in $this.DependsOn) {
            if (-not $completedSteps.ContainsKey($depId)) {
                return $false
            }
            
            $depStep = $completedSteps[$depId]
            if ($depStep.Status -ne [StepStatus]::Completed -and 
                $depStep.Status -ne [StepStatus]::Skipped) {
                return $false
            }
        }
        return $true
    }
    
    [double] GetDurationSeconds() {
        if ($this.StartTime -ne [datetime]::MinValue -and 
            $this.EndTime -ne [datetime]::MinValue) {
            return ($this.EndTime - $this.StartTime).TotalSeconds
        }
        return 0
    }
}

class ParallelGroup {
    [string]$Name
    [string]$Id
    [System.Collections.ArrayList]$Steps
    [int]$MaxParallelism
    
    ParallelGroup([string]$name) {
        $this.Name = $name
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Steps = [System.Collections.ArrayList]::new()
        $this.MaxParallelism = 5
    }
    
    [void] AddStep([object]$step) {
        # Only set to Parallel if not already Conditional
        if ($step.Type -ne [StepType]::Conditional) {
            $step.Type = [StepType]::Parallel
        }
        $this.Steps.Add($step) | Out-Null
    }
}

class WfeWorkflow {
    [int]$WorkflowRetries
    [int]$WorkflowDelay
    [System.Collections.ArrayList]$Steps
    [hashtable]$StepRegistry
    [WorkflowContext]$Context
    [bool]$ContinueOnError
    [datetime]$StartTime
    [datetime]$EndTime
    
    WfeWorkflow() {
        $this.WorkflowRetries = 1
        $this.WorkflowDelay = 60
        $this.Steps = [System.Collections.ArrayList]::new()
        $this.StepRegistry = @{}
        $this.Context = [WorkflowContext]::new()
        $this.ContinueOnError = $false
        $this.StartTime = [datetime]::MinValue
        $this.EndTime = [datetime]::MinValue
    }
    
    [object] AddStep([string]$name, [scriptblock]$action) {
        $step = [WorkflowStep]::new($name, $action)
        $this.Steps.Add($step) | Out-Null
        $this.StepRegistry[$step.Id] = $step
        return $step
    }
    
    [object] AddConditionalStep([string]$name, [scriptblock]$condition, [scriptblock]$action) {
        $step = [WorkflowStep]::new($name, $action)
        $step.Type = [StepType]::Conditional
        $step.Condition = $condition
        $this.Steps.Add($step) | Out-Null
        $this.StepRegistry[$step.Id] = $step
        return $step
    }
    
    [object] AddParallelGroup([string]$name) {
        $group = [ParallelGroup]::new($name)
        $this.Steps.Add($group) | Out-Null
        return $group
    }
    
    [object] AddDependentStep([string]$name, [scriptblock]$action, [string[]]$dependsOn) {
        $step = [WorkflowStep]::new($name, $action)
        $step.DependsOn = $dependsOn
        $this.Steps.Add($step) | Out-Null
        $this.StepRegistry[$step.Id] = $step
        return $step
    }
    
    [bool] Execute() {
        $this.StartTime = Get-Date
        
        for ($attempt = 1; $attempt -le $this.WorkflowRetries; $attempt++) {
            try {
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "Workflow Attempt $attempt/$($this.WorkflowRetries)" -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""
                
                $this.ExecuteSteps()
                
                $this.EndTime = Get-Date
                $duration = $this.EndTime - $this.StartTime
                
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "Workflow Completed Successfully" -ForegroundColor Green
                Write-Host ("Duration: " + $duration.ToString('hh\:mm\:ss')) -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                
                return $true
                
            } catch {
                Write-Host ""
                Write-Host "Workflow attempt $attempt failed: $_" -ForegroundColor Red
                
                if ($attempt -lt $this.WorkflowRetries) {
                    Write-Host "Retrying in $($this.WorkflowDelay) seconds..." -ForegroundColor Yellow
                    Write-Host ""
                    Start-Sleep -Seconds $this.WorkflowDelay
                    $this.ResetSteps()
                } else {
                    $this.EndTime = Get-Date
                    Write-Host ""
                    Write-Host "========================================" -ForegroundColor Red
                    Write-Host "Workflow Failed" -ForegroundColor Red
                    Write-Host "========================================" -ForegroundColor Red
                    Write-Host ""
                    return $false
                }
            }
        }
        return $false
    }
    
    hidden [void] ExecuteSteps() {
        $completedSteps = @{}
        $stepNumber = 1
        
        foreach ($item in $this.Steps) {
            if ($item.GetType().Name -eq 'ParallelGroup') {
                $this.ExecuteParallelGroup($item, $completedSteps)
            }
            else {
                $this.ExecuteSequentialStep($item, $completedSteps, $stepNumber)
                $stepNumber++
            }
        }
    }
    
    hidden [void] ExecuteSequentialStep([object]$step, [hashtable]$completedSteps, [int]$stepNumber) {
        Write-Host ("-" * 50) -ForegroundColor Cyan
        Write-Host "Step ${stepNumber}: $($step.Name)" -ForegroundColor Cyan
        if ($step.Timeout -gt 0) {
            Write-Host "Timeout: $($step.Timeout) seconds" -ForegroundColor DarkGray
        }
        Write-Host ("-" * 50) -ForegroundColor Cyan
        
        if (-not $step.AreDependenciesMet($completedSteps)) {
            throw "Dependencies not met for step: $($step.Name)"
        }
        
        if ($step.Type -eq [StepType]::Conditional) {
            if (-not $step.ShouldExecute($this.Context)) {
                Write-Host "[SKIP] Skipped (condition not met)" -ForegroundColor Yellow
                $step.Status = [StepStatus]::Skipped
                $completedSteps[$step.Id] = $step
                return
            }
        }
        
        $step.Status = [StepStatus]::Running
        $step.StartTime = Get-Date
        
        for ($i = 1; $i -le $step.Retries; $i++) {
            try {
                # Check if timeout is configured
                if ($step.Timeout -gt 0) {
                    # Use a job for timeout support
                    $contextSnapshot = $this.Context.GetSnapshot()
                    $job = Start-Job -ScriptBlock {
                        param($actionString, $contextVars)
                        
                        $stepAction = [scriptblock]::Create($actionString)
                        $ctx = New-Object PSObject -Property @{ Variables = $contextVars }
                        
                        Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Set -Value {
                            param($key, $value)
                            $this.Variables[$key] = $value
                        } -Force
                        
                        Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Get -Value {
                            param($key)
                            if ($this.Variables.ContainsKey($key)) {
                                return $this.Variables[$key]
                            }
                            return $null
                        } -Force
                        
                        $result = & $stepAction $ctx
                        
                        return @{
                            Result = $result
                            UpdatedContext = $ctx.Variables
                        }
                    } -ArgumentList $step.Action.ToString(), $contextSnapshot
                    
                    $completed = Wait-Job -Job $job -Timeout $step.Timeout
                    
                    if ($null -eq $completed) {
                        # Timeout occurred
                        Stop-Job -Job $job
                        Remove-Job -Job $job -Force
                        throw "Step timed out after $($step.Timeout) seconds"
                    }
                    
                    # Check for job errors
                    if ($job.State -eq 'Failed') {
                        $errorMsg = $job.ChildJobs[0].JobStateInfo.Reason.Message
                        Remove-Job -Job $job -Force
                        throw $errorMsg
                    }
                    
                    $jobResult = Receive-Job -Job $job
                    Remove-Job -Job $job -Force
                    
                    # Merge context updates
                    if ($null -ne $jobResult -and $null -ne $jobResult.UpdatedContext) {
                        $this.Context.MergeUpdates($jobResult.UpdatedContext)
                    }
                    
                    $step.Result = $jobResult.Result
                    
                    if ($step.Result -eq $false) {
                        throw "Step returned false"
                    }
                } else {
                    # No timeout - run directly
                    $step.Result = & $step.Action $this.Context
                    
                    if ($step.Result -eq $false) { 
                        throw "Step returned false" 
                    }
                }
                
                $step.EndTime = Get-Date
                $duration = $step.GetDurationSeconds()
                $durationText = $duration.ToString('F2') + "s"
                
                Write-Host "[OK] Completed ($durationText)" -ForegroundColor Green
                $step.Status = [StepStatus]::Completed
                $completedSteps[$step.Id] = $step
                return
                
            } catch {
                $step.ErrorMessage = $_.ToString()
                Write-Host "[FAIL] Attempt $i/$($step.Retries) failed: $_" -ForegroundColor Yellow
                
                if ($i -lt $step.Retries) {
                    Write-Host "Retrying in $($step.RetryDelay) seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $step.RetryDelay
                } else {
                    $step.Status = [StepStatus]::Failed
                    $step.EndTime = Get-Date
                    
                    if (-not $this.ContinueOnError) {
                        throw "Step '$($step.Name)' failed: $_"
                    }
                }
            }
        }
    }
    
    hidden [void] ExecuteParallelGroup([object]$group, [hashtable]$completedSteps) {
        Write-Host ("=" * 50) -ForegroundColor Magenta
        Write-Host "Parallel Group: $($group.Name)" -ForegroundColor Magenta
        Write-Host ("=" * 50) -ForegroundColor Magenta

        $stepsToRun = [System.Collections.ArrayList]::new()

        foreach ($step in $group.Steps) {
            if (-not $step.AreDependenciesMet($completedSteps)) {
                Write-Host "[SKIP] '$($step.Name)' - Dependencies not met" -ForegroundColor Yellow
                $step.Status = [StepStatus]::Skipped
                continue
            }
            
            if ($step.Type -eq [StepType]::Conditional -and -not $step.ShouldExecute($this.Context)) {
                Write-Host "[SKIP] '$($step.Name)' - Condition not met" -ForegroundColor Yellow
                $step.Status = [StepStatus]::Skipped
                continue
            }

            $stepsToRun.Add($step) | Out-Null
        }

        if ($stepsToRun.Count -eq 0) {
            Write-Host "No steps to execute in this group" -ForegroundColor Yellow
            Write-Host ("=" * 50) -ForegroundColor Magenta
            Write-Host ""
            return
        }

        # Use runspace pool for true parallel execution (much faster than Start-Job)
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max($group.MaxParallelism, $stepsToRun.Count))
        $runspacePool.Open()
        
        $runspaces = @{}
        
        # Start all runspaces
        foreach ($step in $stepsToRun) {
            Write-Host "[START] '$($step.Name)'" -ForegroundColor Cyan
            $step.Status = [StepStatus]::Running
            $step.StartTime = Get-Date

            $contextSnapshot = $this.Context.GetSnapshot()
            $stepAction = $step.Action
            $retries = $step.Retries
            $retryDelay = $step.RetryDelay
            
            $powershell = [powershell]::Create()
            $powershell.RunspacePool = $runspacePool
            
            [void]$powershell.AddScript({
                param($actionString, $contextVars, $retries, $retryDelay)
                
                # Recreate the scriptblock from string
                $stepAction = [scriptblock]::Create($actionString)
                
                # Create simple context object
                $ctx = New-Object PSObject -Property @{ Variables = $contextVars }
                
                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Set -Value {
                    param($key, $value)
                    $this.Variables[$key] = $value
                } -Force
                
                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Get -Value {
                    param($key)
                    if ($this.Variables.ContainsKey($key)) {
                        return $this.Variables[$key]
                    }
                    return $null
                } -Force
                
                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name SetValue -Value {
                    param($key, $value)
                    $this.Variables[$key] = $value
                } -Force
                
                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name GetValue -Value {
                    param($key)
                    if ($this.Variables.ContainsKey($key)) {
                        return $this.Variables[$key]
                    }
                    return $null
                } -Force
                
                # Execute with retries
                for ($i = 1; $i -le $retries; $i++) {
                    try {
                        $result = & $stepAction $ctx
                        
                        return @{
                            Success = $true
                            Result = $result
                            UpdatedContext = $ctx.Variables
                            Error = $null
                        }
                        
                    } catch {
                        if ($i -lt $retries) {
                            Start-Sleep -Seconds $retryDelay
                        } else {
                            return @{
                                Success = $false
                                Result = $null
                                UpdatedContext = $ctx.Variables
                                Error = $_.Exception.Message
                            }
                        }
                    }
                }
            })
            
            [void]$powershell.AddArgument($stepAction.ToString())
            [void]$powershell.AddArgument($contextSnapshot)
            [void]$powershell.AddArgument($retries)
            [void]$powershell.AddArgument($retryDelay)
            
            $handle = $powershell.BeginInvoke()
            
            $runspaces[$step.Id] = @{
                PowerShell = $powershell
                Handle = $handle
                Step = $step
            }
        }

        if ($runspaces.Count -gt 0) {
            Write-Host "Waiting for $($runspaces.Count) parallel tasks..." -ForegroundColor Cyan
            
            # Wait for all runspaces to complete
            $failedStep = $null
            
            foreach ($stepId in $runspaces.Keys) {
                $runspaceInfo = $runspaces[$stepId]
                $step = $runspaceInfo.Step
                $powershell = $runspaceInfo.PowerShell
                $handle = $runspaceInfo.Handle
                
                try {
                    # Wait for this runspace to complete
                    $result = $powershell.EndInvoke($handle)
                    
                    $step.EndTime = Get-Date
                    $duration = $step.GetDurationSeconds()
                    $durationText = $duration.ToString('F2') + "s"
                    
                    # Check for errors in the stream
                    if ($powershell.Streams.Error.Count -gt 0) {
                        $errorMsg = $powershell.Streams.Error[0].ToString()
                        Write-Host "[FAIL] '$($step.Name)' stream error: $errorMsg" -ForegroundColor Red
                        $step.Status = [StepStatus]::Failed
                        $step.ErrorMessage = $errorMsg
                        
                        if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                            $failedStep = $step
                        }
                    }
                    elseif ($null -ne $result -and $result.Count -gt 0 -and $result[0].Success) {
                        Write-Host "[OK] '$($step.Name)' ($durationText)" -ForegroundColor Green
                        $step.Status = [StepStatus]::Completed
                        $step.Result = $result[0].Result
                        $completedSteps[$step.Id] = $step
                        $this.Context.MergeUpdates($result[0].UpdatedContext)
                    } else {
                        $errorMsg = if ($null -ne $result -and $result.Count -gt 0) { $result[0].Error } else { "Unknown error" }
                        Write-Host "[FAIL] '$($step.Name)' failed: $errorMsg" -ForegroundColor Red
                        $step.Status = [StepStatus]::Failed
                        $step.ErrorMessage = $errorMsg
                        
                        if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                            $failedStep = $step
                        }
                    }
                } catch {
                    $step.EndTime = Get-Date
                    Write-Host "[FAIL] '$($step.Name)' exception: $_" -ForegroundColor Red
                    $step.Status = [StepStatus]::Failed
                    $step.ErrorMessage = $_.ToString()
                    
                    if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                        $failedStep = $step
                    }
                } finally {
                    $powershell.Dispose()
                }
            }
            
            # Clean up runspace pool
            $runspacePool.Close()
            $runspacePool.Dispose()
            
            # If we had a failure and ContinueOnError is false, throw now
            if ($null -ne $failedStep) {
                throw "Parallel step '$($failedStep.Name)' failed: $($failedStep.ErrorMessage)"
            }
        }

        Write-Host ("=" * 50) -ForegroundColor Magenta
        Write-Host ""
    }
    
    hidden [void] ResetSteps() {
        foreach ($item in $this.Steps) {
            if ($item.GetType().Name -eq 'WorkflowStep') {
                $item.Status = [StepStatus]::Pending
                $item.ErrorMessage = $null
                $item.Result = $null
                $item.StartTime = [datetime]::MinValue
                $item.EndTime = [datetime]::MinValue
            }
            elseif ($item.GetType().Name -eq 'ParallelGroup') {
                foreach ($step in $item.Steps) {
                    $step.Status = [StepStatus]::Pending
                    $step.ErrorMessage = $null
                    $step.Result = $null
                    $step.StartTime = [datetime]::MinValue
                    $step.EndTime = [datetime]::MinValue
                }
            }
        }
        $this.Context = [WorkflowContext]::new()
    }
    
    [void] PrintSummary() {
        Write-Host ""
        Write-Host "+================================================+" -ForegroundColor Cyan
        Write-Host "|           WORKFLOW SUMMARY                     |" -ForegroundColor Cyan
        Write-Host "+================================================+" -ForegroundColor Cyan
        
        $allSteps = [System.Collections.ArrayList]::new()
        
        foreach ($item in $this.Steps) {
            if ($item.GetType().Name -eq 'WorkflowStep') {
                $allSteps.Add($item) | Out-Null
            }
            elseif ($item.GetType().Name -eq 'ParallelGroup') {
                foreach ($step in $item.Steps) {
                    $allSteps.Add($step) | Out-Null
                }
            }
        }
        
        $completed = 0
        $failed = 0
        $skipped = 0
        
        foreach ($step in $allSteps) {
            if ($step.Status -eq [StepStatus]::Completed) { $completed++ }
            elseif ($step.Status -eq [StepStatus]::Failed) { $failed++ }
            elseif ($step.Status -eq [StepStatus]::Skipped) { $skipped++ }
        }
        
        Write-Host ""
        Write-Host "Total Steps: $($allSteps.Count)"
        Write-Host "Completed:   $completed" -ForegroundColor Green
        Write-Host "Failed:      $failed" -ForegroundColor Red
        Write-Host "Skipped:     $skipped" -ForegroundColor Yellow
        
        if ($this.StartTime -ne [datetime]::MinValue -and $this.EndTime -ne [datetime]::MinValue) {
            $duration = $this.EndTime - $this.StartTime
            Write-Host ""
            Write-Host ("Total Duration: " + $duration.ToString('hh\:mm\:ss'))
        }
        
        Write-Host ""
        Write-Host ("-" * 50)
        Write-Host "Step Details:" -ForegroundColor Cyan
        Write-Host ("-" * 50)
        
        foreach ($step in $allSteps) {
            $statusColor = 'Gray'
            $statusSymbol = '[ ]'
            
            if ($step.Status -eq [StepStatus]::Completed) {
                $statusColor = 'Green'
                $statusSymbol = '[OK]'
            }
            elseif ($step.Status -eq [StepStatus]::Failed) {
                $statusColor = 'Red'
                $statusSymbol = '[FAIL]'
            }
            elseif ($step.Status -eq [StepStatus]::Skipped) {
                $statusColor = 'Yellow'
                $statusSymbol = '[SKIP]'
            }
            
            $durationStr = ""
            if ($step.StartTime -ne [datetime]::MinValue -and $step.EndTime -ne [datetime]::MinValue) {
                $dur = $step.GetDurationSeconds()
                $durationStr = " (" + $dur.ToString('F2') + "s)"
            }
            
            Write-Host "$statusSymbol $($step.Name)$durationStr" -ForegroundColor $statusColor
            
            if ($step.Status -eq [StepStatus]::Failed -and $step.ErrorMessage) {
                Write-Host "  Error: $($step.ErrorMessage)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }

    # ============================================================================
    # INTERACTIVE MODE METHODS
    # ============================================================================

    hidden [string] ExtractStepDescription([object]$step) {
        return ""
    }

    hidden [array] BuildStepList() {
        $stepList = @()

        foreach ($item in $this.Steps) {
            if ($item.GetType().Name -eq 'ParallelGroup') {
                foreach ($parallelStep in $item.Steps) {
                    $stepList += @{
                        OriginalStep = $parallelStep
                        ParallelGroup = $item
                        Name = $parallelStep.Name
                        Status = $parallelStep.Status
                        IsParallel = $true
                        Description = $this.ExtractStepDescription($parallelStep)
                    }
                }
            } else {
                $stepList += @{
                    OriginalStep = $item
                    ParallelGroup = $null
                    Name = $item.Name
                    Status = $item.Status
                    IsParallel = $false
                    Description = $this.ExtractStepDescription($item)
                }
            }
        }

        return $stepList
    }

    hidden [hashtable] ParseStepSelection([string]$input, [array]$stepList) {
        $input = $input.Trim().ToLower()

        if ($input -in @("exit", "quit", "q")) {
            return @{ Action = "Exit" }
        }

        if ($input -eq "all") {
            $selectedIndices = 1..$stepList.Count
            return @{
                Action = "Execute"
                SelectedIndices = $selectedIndices
                StepList = $stepList
            }
        }

        if ($input -match "^from\s+(\d+)$") {
            $start = [int]$matches[1]
            $selectedIndices = $start..$stepList.Count
            return @{
                Action = "Execute"
                SelectedIndices = $selectedIndices
                StepList = $stepList
            }
        }

        if ($input -match "^to\s+(\d+)$") {
            $end = [int]$matches[1]
            $selectedIndices = 1..$end
            return @{
                Action = "Execute"
                SelectedIndices = $selectedIndices
                StepList = $stepList
            }
        }

        $selectedIndices = @()
        $parts = $input -split ','
        foreach ($part in $parts) {
            $part = $part.Trim()
            if ($part -match '^(\d+)-(\d+)$') {
                $start = [int]$matches[1]
                $end = [int]$matches[2]
                $selectedIndices += $start..$end
            } elseif ($part -match '^\d+$') {
                $selectedIndices += [int]$part
            }
        }

        $selectedIndices = $selectedIndices | Where-Object { $_ -ge 1 -and $_ -le $stepList.Count } | Sort-Object -Unique

        return @{
            Action = "Execute"
            SelectedIndices = $selectedIndices
            StepList = $stepList
        }
    }

    hidden [hashtable] ShowInteractiveMenu() {
        Clear-Host
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  WORKFLOW INTERACTIVE MODE" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""

        $stepList = $this.BuildStepList()

        $index = 1
        foreach ($item in $stepList) {
            $status = $item.Status
            $color = switch ($status) {
                "Completed" { "Green" }
                "Failed" { "Red" }
                "Skipped" { "Yellow" }
                "Running" { "Cyan" }
                default { "White" }
            }

            $prefix = "[$index]"
            $type = if ($item.IsParallel) { "[PARALLEL]" } else { "[SEQUENTIAL]" }
            $statusText = "[$status]"

            Write-Host "$prefix $type " -NoNewline
            Write-Host $item.Name -ForegroundColor $color -NoNewline
            Write-Host " $statusText" -ForegroundColor $color

            if ($item.Description) {
                Write-Host "      $($item.Description)" -ForegroundColor Gray
            }

            $index++
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "COMMANDS:" -ForegroundColor Yellow
        Write-Host "  - Enter step numbers (e.g., 1,3,5)" -ForegroundColor Gray
        Write-Host "  - Enter range (e.g., 2-6)" -ForegroundColor Gray
        Write-Host "  - From step to end (e.g., from 3)" -ForegroundColor Gray
        Write-Host "  - Up to step (e.g., to 5)" -ForegroundColor Gray
        Write-Host "  - All steps (e.g., all)" -ForegroundColor Gray
        Write-Host "  - Exit (e.g., exit or quit)" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""

        $userInput = Read-Host "Select steps to execute"

        return $this.ParseStepSelection($userInput, $stepList)
    }

    hidden [void] ExecuteParallelGroupFiltered([object]$group, [array]$selectedSteps, [hashtable]$completedSteps) {
        Write-Host ("=" * 50) -ForegroundColor Magenta
        Write-Host "Parallel Group: $($group.Name)" -ForegroundColor Magenta
        Write-Host ("=" * 50) -ForegroundColor Magenta

        if ($selectedSteps.Count -eq 0) {
            Write-Host "No steps to execute in this group" -ForegroundColor Yellow
            Write-Host ("=" * 50) -ForegroundColor Magenta
            Write-Host ""
            return
        }

        $runspacePool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max($group.MaxParallelism, $selectedSteps.Count))
        $runspacePool.Open()

        $runspaces = @{}

        foreach ($step in $selectedSteps) {
            Write-Host "[START] '$($step.Name)'" -ForegroundColor Cyan
            $step.Status = [StepStatus]::Running
            $step.StartTime = Get-Date

            $contextSnapshot = $this.Context.GetSnapshot()
            $stepAction = $step.Action
            $retries = $step.Retries
            $retryDelay = $step.RetryDelay

            $powershell = [powershell]::Create()
            $powershell.RunspacePool = $runspacePool

            [void]$powershell.AddScript({
                param($actionString, $contextVars, $retries, $retryDelay)

                $stepAction = [scriptblock]::Create($actionString)

                $ctx = New-Object PSObject -Property @{ Variables = $contextVars }

                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Set -Value {
                    param($key, $value)
                    $this.Variables[$key] = $value
                } -Force

                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name Get -Value {
                    param($key)
                    if ($this.Variables.ContainsKey($key)) {
                        return $this.Variables[$key]
                    }
                    return $null
                } -Force

                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name SetValue -Value {
                    param($key, $value)
                    $this.Variables[$key] = $value
                } -Force

                Add-Member -InputObject $ctx -MemberType ScriptMethod -Name GetValue -Value {
                    param($key)
                    if ($this.Variables.ContainsKey($key)) {
                        return $this.Variables[$key]
                    }
                    return $null
                } -Force

                for ($i = 1; $i -le $retries; $i++) {
                    try {
                        $result = & $stepAction $ctx

                        return @{
                            Success = $true
                            Result = $result
                            UpdatedContext = $ctx.Variables
                            Error = $null
                        }

                    } catch {
                        if ($i -lt $retries) {
                            Start-Sleep -Seconds $retryDelay
                        } else {
                            return @{
                                Success = $false
                                Result = $null
                                UpdatedContext = $ctx.Variables
                                Error = $_.Exception.Message
                            }
                        }
                    }
                }
            })

            [void]$powershell.AddArgument($stepAction.ToString())
            [void]$powershell.AddArgument($contextSnapshot)
            [void]$powershell.AddArgument($retries)
            [void]$powershell.AddArgument($retryDelay)

            $handle = $powershell.BeginInvoke()

            $runspaces[$step.Id] = @{
                PowerShell = $powershell
                Handle = $handle
                Step = $step
            }
        }

        if ($runspaces.Count -gt 0) {
            Write-Host "Waiting for $($runspaces.Count) parallel tasks..." -ForegroundColor Cyan

            $failedStep = $null

            foreach ($stepId in $runspaces.Keys) {
                $runspaceInfo = $runspaces[$stepId]
                $step = $runspaceInfo.Step
                $powershell = $runspaceInfo.PowerShell
                $handle = $runspaceInfo.Handle

                try {
                    $result = $powershell.EndInvoke($handle)

                    $step.EndTime = Get-Date
                    $duration = $step.GetDurationSeconds()
                    $durationText = $duration.ToString('F2') + "s"

                    if ($powershell.Streams.Error.Count -gt 0) {
                        $errorMsg = $powershell.Streams.Error[0].ToString()
                        Write-Host "[FAIL] '$($step.Name)' stream error: $errorMsg" -ForegroundColor Red
                        $step.Status = [StepStatus]::Failed
                        $step.ErrorMessage = $errorMsg

                        if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                            $failedStep = $step
                        }
                    }
                    elseif ($null -ne $result -and $result.Count -gt 0 -and $result[0].Success) {
                        Write-Host "[OK] '$($step.Name)' ($durationText)" -ForegroundColor Green
                        $step.Status = [StepStatus]::Completed
                        $step.Result = $result[0].Result
                        $completedSteps[$step.Id] = $step
                        $this.Context.MergeUpdates($result[0].UpdatedContext)
                    } else {
                        $errorMsg = if ($null -ne $result -and $result.Count -gt 0) { $result[0].Error } else { "Unknown error" }
                        Write-Host "[FAIL] '$($step.Name)' failed: $errorMsg" -ForegroundColor Red
                        $step.Status = [StepStatus]::Failed
                        $step.ErrorMessage = $errorMsg

                        if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                            $failedStep = $step
                        }
                    }
                } catch {
                    $step.EndTime = Get-Date
                    Write-Host "[FAIL] '$($step.Name)' exception: $_" -ForegroundColor Red
                    $step.Status = [StepStatus]::Failed
                    $step.ErrorMessage = $_.ToString()

                    if (-not $this.ContinueOnError -and $null -eq $failedStep) {
                        $failedStep = $step
                    }
                } finally {
                    $powershell.Dispose()
                }
            }

            $runspacePool.Close()
            $runspacePool.Dispose()

            if ($null -ne $failedStep) {
                throw "Parallel step '$($failedStep.Name)' failed: $($failedStep.ErrorMessage)"
            }
        }

        Write-Host ("=" * 50) -ForegroundColor Magenta
        Write-Host ""
    }

    hidden [void] ExecuteSelectedSteps([hashtable]$selection) {
        $selectedIndices = $selection.SelectedIndices
        $stepList = $selection.StepList

        if ($selectedIndices.Count -eq 0) {
            Write-Host "No valid steps selected." -ForegroundColor Yellow
            return
        }

        $selectedSteps = @()
        foreach ($index in $selectedIndices) {
            $selectedSteps += $stepList[$index - 1]
        }

        $parallelGroupSelections = @{}
        $sequentialSteps = @()

        foreach ($stepInfo in $selectedSteps) {
            if ($stepInfo.IsParallel) {
                $groupId = $stepInfo.ParallelGroup.Id
                if (-not $parallelGroupSelections.ContainsKey($groupId)) {
                    $parallelGroupSelections[$groupId] = @{
                        Group = $stepInfo.ParallelGroup
                        SelectedSteps = @()
                    }
                }
                $parallelGroupSelections[$groupId].SelectedSteps += $stepInfo.OriginalStep
            } else {
                $sequentialSteps += $stepInfo.OriginalStep
            }
        }

        $completedSteps = @{}
        $stepNumber = 1

        foreach ($item in $this.Steps) {
            if ($item.GetType().Name -eq 'ParallelGroup') {
                $groupId = $item.Id
                if ($parallelGroupSelections.ContainsKey($groupId)) {
                    $stepsToRun = $parallelGroupSelections[$groupId].SelectedSteps

                    if ($stepsToRun.Count -lt $item.Steps.Count) {
                        Write-Host ""
                        Write-Host "Parallel Group: $($item.Name)" -ForegroundColor Yellow
                        Write-Host "  Selected $($stepsToRun.Count) of $($item.Steps.Count) parallel steps" -ForegroundColor Gray
                        Write-Host "  Selected steps will run in parallel" -ForegroundColor Gray
                        Write-Host ""
                    }

                    try {
                        $this.ExecuteParallelGroupFiltered($item, $stepsToRun, $completedSteps)
                    } catch {
                        if (-not $this.ContinueOnError) {
                            throw
                        }
                    }
                }
            } else {
                if ($item -in $sequentialSteps) {
                    try {
                        $this.ExecuteSequentialStep($item, $completedSteps, $stepNumber)
                        $stepNumber++
                        if ($item.Status -eq [StepStatus]::Completed) {
                            $completedSteps[$item.Id] = $item
                        }
                    } catch {
                        if (-not $this.ContinueOnError) {
                            throw
                        }
                    }
                }
            }
        }
    }

    [bool] ExecuteInteractive() {
        $this.StartTime = Get-Date

        while ($true) {
            $selection = $this.ShowInteractiveMenu()

            if ($selection.Action -eq "Exit") {
                Write-Host ""
                Write-Host "Exiting interactive mode..." -ForegroundColor Yellow
                Write-Host ""
                break
            }

            try {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "Executing selected steps..." -ForegroundColor Cyan
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""

                $this.ExecuteSelectedSteps($selection)

                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "Execution completed" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green

            } catch {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Red
                Write-Host "Execution failed: $_" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Red
            }

            $this.PrintSummary()

            Write-Host ""
            Write-Host "Press Enter to return to menu..." -ForegroundColor Cyan
            try {
                [void][System.Console]::ReadKey($true)
            } catch {
                # Fallback for environments without console (ISE, VS Code, etc.)
                Read-Host
            }
        }

        $this.EndTime = Get-Date
        return $true
    }
}

#endregion

#region Public Functions

function New-Workflow {
    <#
    .SYNOPSIS
        Creates a new workflow instance
    .DESCRIPTION
        Creates a new WfeWorkflow object that can be used to define and execute workflow steps.
    .PARAMETER WorkflowRetries
        Number of times to retry the entire workflow on failure. Default is 1.
    .PARAMETER WorkflowDelay
        Seconds to wait between workflow retries. Default is 60.
    .PARAMETER ContinueOnError
        If true, continue executing steps even if one fails. Default is false.
    .EXAMPLE
        $workflow = New-Workflow
        $workflow.AddStep("Step 1", { param($ctx) Write-Host "Hello" })
        $workflow.Execute()
    .EXAMPLE
        $workflow = New-Workflow -WorkflowRetries 3 -ContinueOnError $true
    #>
    [CmdletBinding()]
    [OutputType([WfeWorkflow])]
    param(
        [Parameter()]
        [int]$WorkflowRetries = 1,
        
        [Parameter()]
        [int]$WorkflowDelay = 60,
        
        [Parameter()]
        [bool]$ContinueOnError = $false
    )
    
    $workflow = [WfeWorkflow]::new()
    $workflow.WorkflowRetries = $WorkflowRetries
    $workflow.WorkflowDelay = $WorkflowDelay
    $workflow.ContinueOnError = $ContinueOnError
    
    return $workflow
}

function New-WorkflowStep {
    <#
    .SYNOPSIS
        Creates a new workflow step (standalone, not added to a workflow)
    .DESCRIPTION
        Creates a WorkflowStep object that can be customized before adding to a workflow or parallel group.
    .PARAMETER Name
        The name of the step
    .PARAMETER Action
        The scriptblock to execute
    .EXAMPLE
        $step = New-WorkflowStep -Name "My Step" -Action { param($ctx) Write-Host "Running" }
        $step.Retries = 5
        $step.Timeout = 120
    #>
    [CmdletBinding()]
    [OutputType([WorkflowStep])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )
    
    return [WorkflowStep]::new($Name, $Action)
}

#endregion

# Export public functions and types
Export-ModuleMember -Function @(
    'New-Workflow',
    'New-WorkflowStep'
)
