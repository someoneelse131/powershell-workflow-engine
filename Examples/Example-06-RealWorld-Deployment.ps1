<#
.SYNOPSIS
    Example 06: Real-World Deployment Pipeline

.DESCRIPTION
    This example demonstrates a complete, realistic deployment workflow
    that combines all the concepts: sequential steps, parallel groups,
    conditional steps, context sharing, and error handling.

    Scenario: Deploy a web application to different environments

.PARAMETER Manual
    Run in interactive mode - choose which steps to execute

.NOTES
    Run this script from PowerShell:
    .\Example-06-RealWorld-Deployment.ps1

    For interactive mode:
    .\Example-06-RealWorld-Deployment.ps1 -Manual
#>

param(
    [switch]$Manual
)

Import-Module WorkflowEngine

# ============================================================================
# CONFIGURATION - Change these to test different scenarios!
# ============================================================================
$Config = @{
    Environment = "staging"      # Try: "development", "staging", "production"
    Version = "2.5.0"
    RunTests = $true             # Set to $false to skip tests
    NotifyTeam = $true           # Set to $false to skip notifications
    BackupFirst = $true          # Set to $false to skip backup
}

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  DEPLOYMENT PIPELINE" -ForegroundColor Cyan
Write-Host "  Environment: $($Config.Environment) | Version: $($Config.Version)" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# CREATE WORKFLOW
# ============================================================================
# - Retry entire workflow up to 2 times on failure
# - Wait 30 seconds between workflow retries
# - Stop on first error (do not continue with broken deployment)

$workflow = New-Workflow -WorkflowRetries 2 -WorkflowDelay 30 -ContinueOnError $false

# ============================================================================
# PRE-LOAD CONFIGURATION INTO CONTEXT
# ============================================================================
# This is the correct way to pass external variables into workflow steps
$workflow.Context.Set("environment", $Config.Environment)
$workflow.Context.Set("version", $Config.Version)
$workflow.Context.Set("runTests", $Config.RunTests)
$workflow.Context.Set("notifyTeam", $Config.NotifyTeam)
$workflow.Context.Set("backupFirst", $Config.BackupFirst)

# ============================================================================
# PHASE 1: INITIALIZATION
# ============================================================================

$workflow.AddStep("Initialize Pipeline", {
    param($ctx)
    
    Write-Host "  Loading configuration..."
    
    # Get pre-loaded config from context
    $environment = $ctx.Get("environment")
    $version = $ctx.Get("version")
    
    # Add additional context values
    $ctx.Set("startTime", (Get-Date))
    $ctx.Set("deploymentId", "DEPLOY-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    
    # Environment-specific settings
    $envConfig = switch ($environment) {
        "development" { @{ Server = "dev-server"; Replicas = 1; HealthCheckUrl = "http://dev.example.com/health" } }
        "staging"     { @{ Server = "stage-server"; Replicas = 2; HealthCheckUrl = "http://staging.example.com/health" } }
        "production"  { @{ Server = "prod-cluster"; Replicas = 5; HealthCheckUrl = "http://example.com/health" } }
    }
    $ctx.Set("envConfig", $envConfig)
    
    Write-Host "  Deployment ID: $($ctx.Get('deploymentId'))"
    Write-Host "  Target server: $($envConfig.Server)"
    Write-Host "  Replicas: $($envConfig.Replicas)"
})

# ============================================================================
# PHASE 2: PRE-DEPLOYMENT CHECKS
# ============================================================================

$workflow.AddStep("Validate Environment", {
    param($ctx)
    
    Write-Host "  Checking prerequisites..."
    
    # Simulate checks
    $checks = @(
        @{ Name = "Git repository"; Status = $true }
        @{ Name = "Docker daemon"; Status = $true }
        @{ Name = "Kubernetes cluster"; Status = $true }
        @{ Name = "Registry access"; Status = $true }
    )
    
    $allPassed = $true
    foreach ($check in $checks) {
        $symbol = if ($check.Status) { "[OK]" } else { "[FAIL]" }
        $color = if ($check.Status) { "Green" } else { "Red" }
        Write-Host "    $symbol $($check.Name)" -ForegroundColor $color
        if (-not $check.Status) { $allPassed = $false }
    }
    
    if (-not $allPassed) {
        return $false
    }
    
    $ctx.Set("validationPassed", $true)
})

# Conditional: Production requires approval
$workflow.AddConditionalStep(
    "Production Approval Gate",
    { param($ctx) $ctx.Get("environment") -eq "production" },
    {
        param($ctx)
        
        $version = $ctx.Get("version")
        
        Write-Host ""
        Write-Host "  +=========================================================+" -ForegroundColor Red
        Write-Host "  |           PRODUCTION DEPLOYMENT WARNING                 |" -ForegroundColor Red
        Write-Host "  |                                                         |" -ForegroundColor Red
        Write-Host "  |   Version: $version                                        |" -ForegroundColor Red
        Write-Host "  |   This will affect ALL production users!                |" -ForegroundColor Red
        Write-Host "  |                                                         |" -ForegroundColor Red
        Write-Host "  |   Deployment will proceed in 5 seconds...               |" -ForegroundColor Red
        Write-Host "  +=========================================================+" -ForegroundColor Red
        Write-Host ""
        
        for ($i = 5; $i -ge 1; $i--) {
            Write-Host "    Proceeding in $i..." -ForegroundColor Yellow
            Start-Sleep 1
        }
    }
)

# Conditional: Backup before deployment
$workflow.AddConditionalStep(
    "Backup Current Version",
    { param($ctx) $ctx.Get("backupFirst") -eq $true },
    {
        param($ctx)
        
        Write-Host "  Creating backup of current deployment..."
        Start-Sleep 1
        
        $backupId = "BACKUP-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        $ctx.Set("backupId", $backupId)
        
        Write-Host "  Backup created: $backupId"
    }
)

# ============================================================================
# PHASE 3: BUILD (Parallel)
# ============================================================================

$buildGroup = $workflow.AddParallelGroup("Build Application")

$buildGroup.AddStep((New-WorkflowStep -Name "Build Docker Image" -Action {
    param($ctx)
    Write-Host "  [DOCKER] Building image..."
    Start-Sleep 2
    Write-Host "  [DOCKER] Image built: myapp:latest"
    $ctx.Set("dockerImage", "myapp:latest")
}))

$buildGroup.AddStep((New-WorkflowStep -Name "Compile Static Assets" -Action {
    param($ctx)
    Write-Host "  [ASSETS] Compiling CSS/JS..."
    Start-Sleep 1
    Write-Host "  [ASSETS] Minified 24 files"
}))

$buildGroup.AddStep((New-WorkflowStep -Name "Generate Documentation" -Action {
    param($ctx)
    Write-Host "  [DOCS] Generating API documentation..."
    Start-Sleep 1
    Write-Host "  [DOCS] Documentation ready"
}))

# ============================================================================
# PHASE 4: TEST (Conditional + Parallel)
# ============================================================================

# Only run tests if configured
$workflow.AddConditionalStep(
    "Run Unit Tests",
    { param($ctx) $ctx.Get("runTests") -eq $true },
    {
        param($ctx)
        
        Write-Host "  Running unit tests..."
        Start-Sleep 1
        
        $results = @{ Passed = 247; Failed = 0; Skipped = 3 }
        $ctx.Set("unitTestResults", $results)
        
        Write-Host "    Passed: $($results.Passed)"
        Write-Host "    Failed: $($results.Failed)"
        Write-Host "    Skipped: $($results.Skipped)"
        
        if ($results.Failed -gt 0) {
            return $false
        }
    }
)

$workflow.AddConditionalStep(
    "Run Integration Tests",
    { param($ctx) $ctx.Get("runTests") -eq $true },
    {
        param($ctx)
        
        Write-Host "  Running integration tests..."
        Start-Sleep 1
        
        $results = @{ Passed = 42; Failed = 0 }
        $ctx.Set("integrationTestResults", $results)
        
        Write-Host "    Passed: $($results.Passed)"
        Write-Host "    Failed: $($results.Failed)"
        
        if ($results.Failed -gt 0) {
            return $false
        }
    }
)

# ============================================================================
# PHASE 5: DEPLOY
# ============================================================================

$workflow.AddStep("Push to Registry", {
    param($ctx)
    
    $image = $ctx.Get("dockerImage")
    if (-not $image) { $image = "myapp:latest" }
    Write-Host "  Pushing $image to container registry..."
    Start-Sleep 1
    Write-Host "  Push complete"
})

$workflow.AddStep("Deploy to Cluster", {
    param($ctx)
    
    $env = $ctx.Get("environment")
    $envConfig = $ctx.Get("envConfig")
    $version = $ctx.Get("version")
    
    Write-Host "  Deploying to $($envConfig.Server)..."
    Write-Host "    Version: $version"
    Write-Host "    Replicas: $($envConfig.Replicas)"
    
    Start-Sleep 2
    
    Write-Host "  Rolling update in progress..."
    for ($i = 1; $i -le $envConfig.Replicas; $i++) {
        Write-Host "    Pod $i/$($envConfig.Replicas) updated"
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "  Deployment complete!"
})

# ============================================================================
# PHASE 6: VERIFICATION
# ============================================================================

$verifyStep = $workflow.AddStep("Health Check", {
    param($ctx)
    
    $envConfig = $ctx.Get("envConfig")
    Write-Host "  Checking application health..."
    Write-Host "    URL: $($envConfig.HealthCheckUrl)"
    
    Start-Sleep 1
    
    # Simulate health check
    $healthy = $true
    
    if ($healthy) {
        Write-Host "  [OK] Application is healthy!" -ForegroundColor Green
        $ctx.Set("deploymentSuccessful", $true)
    } else {
        Write-Host "  [FAIL] Health check failed!" -ForegroundColor Red
        return $false
    }
})
$verifyStep.Retries = 5
$verifyStep.RetryDelay = 5

# ============================================================================
# PHASE 7: NOTIFICATION
# ============================================================================

$workflow.AddConditionalStep(
    "Send Notifications",
    { param($ctx) $ctx.Get("notifyTeam") -eq $true },
    {
        param($ctx)
        
        Write-Host "  Sending notifications..."
        
        $env = $ctx.Get("environment")
        $version = $ctx.Get("version")
        $deploymentId = $ctx.Get("deploymentId")
        $startTime = $ctx.Get("startTime")
        $duration = (Get-Date) - $startTime
        
        Write-Host "    -> Slack: #deployments"
        Write-Host "    -> Email: team@example.com"
        
        # Summary
        Write-Host ""
        Write-Host "  +=========================================================+" -ForegroundColor Green
        Write-Host "  |              DEPLOYMENT SUCCESSFUL                      |" -ForegroundColor Green
        Write-Host "  +=========================================================+" -ForegroundColor Green
        Write-Host "  |  Deployment ID: $deploymentId              |" -ForegroundColor Green
        Write-Host "  |  Environment:   $env                                   |" -ForegroundColor Green
        Write-Host "  |  Version:       $version                                     |" -ForegroundColor Green
        Write-Host "  |  Duration:      $($duration.ToString('mm\:ss'))                                  |" -ForegroundColor Green
        Write-Host "  +=========================================================+" -ForegroundColor Green
    }
)

# ============================================================================
# EXECUTE
# ============================================================================

if ($Manual) {
    # Interactive mode - user selects which steps to run
    $workflow.ExecuteInteractive()
} else {
    # Automatic mode - run all steps
    $success = $workflow.Execute()
    $workflow.PrintSummary()
}

# Final status
Write-Host ""
if ($success) {
    Write-Host "Pipeline completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Pipeline failed. Check the summary above for details." -ForegroundColor Red
}

<#
WHAT THIS EXAMPLE DEMONSTRATES:
-------------------------------
1. Real-world pipeline structure with phases
2. Configuration-driven behavior
3. Environment-specific logic (dev/staging/prod)
4. Conditional steps for optional tasks
5. Parallel builds for speed
6. Health checks with retries
7. Proper error handling
8. Comprehensive status reporting

HOW TO PASS EXTERNAL VARIABLES:
-------------------------------
Instead of using $using: (which does not work), pre-load values into context:

    $workflow.Context.Set("myVar", $externalVariable)

Then access inside steps:

    $workflow.AddStep("My Step", {
        param($ctx)
        $value = $ctx.Get("myVar")
    })

TRY THESE MODIFICATIONS:
------------------------
- Change Config.Environment to "production" to see the approval gate
- Set Config.RunTests to $false to skip tests
- Set Config.BackupFirst to $false to skip backup
- The workflow demonstrates a complete CI/CD pipeline pattern

ADAPTING FOR YOUR USE:
----------------------
Replace the simulated operations (Start-Sleep) with real commands:
- Docker: docker build, docker push
- Kubernetes: kubectl apply, kubectl rollout status
- Testing: Invoke-Pester, npm test
- Notifications: Send-SlackMessage, Send-MailMessage
#>
