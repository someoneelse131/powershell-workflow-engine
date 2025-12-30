# PowerShell Workflow Engine (WFE)

A powerful, production-ready workflow execution engine for PowerShell that enables sequential, parallel, and conditional task orchestration with advanced features like context sharing, automatic retries, timeout controls, dependency management, and interactive execution.

## Features

- **Sequential Execution** - Run tasks in a defined order with full control over execution flow
- **Parallel Execution** - Execute independent tasks simultaneously using efficient runspace pools
- **Conditional Steps** - Run steps based on dynamic conditions evaluated at runtime
- **Context Sharing** - Share data between steps using a built-in context system
- **Error Handling** - Automatic retries with configurable delays for both individual steps and entire workflows
- **Timeout Support** - Prevent runaway tasks with configurable timeout limits
- **Dependency Management** - Define dependencies between steps to control execution order
- **Interactive Execution** - Select and run specific steps on-demand with an interactive menu
- **Detailed Reporting** - Comprehensive execution summaries with timing information
- **PowerShell 5.1+ Compatible** - Works on Windows PowerShell 5.1 and later

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Usage Examples](#usage-examples)
  - [Basic Sequential Workflow](#basic-sequential-workflow)
  - [Parallel Execution](#parallel-execution)
  - [Conditional Steps](#conditional-steps)
  - [Context Sharing](#context-sharing)
  - [Error Handling](#error-handling)
  - [Step Dependencies](#step-dependencies)
  - [Interactive Execution](#interactive-execution)
- [API Reference](#api-reference)
- [Configuration Options](#configuration-options)
- [Advanced Features](#advanced-features)
- [Real-World Examples](#real-world-examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Option 1: Import Module Directly

Folder Workflowengine is the Module. Copy folder into a powrshell module folder
default C:\Program Files\WindowsPowerShell\Modules
or C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules


Import the module directly from its location:

```powershell
Import-Module "C:\path\to\wfe\WorkflowEngine"
```

### Option 2: Install to PowerShell Modules Folder

Copy the module to a system modules directory for global access (run as Administrator):

```powershell
$modulePath = "$env:ProgramFiles\WindowsPowerShell\Modules\WorkflowEngine"
Copy-Item -Path "C:\path\to\WorkflowEngine" -Destination $modulePath -Recurse -Force

# Now you can import from anywhere
Import-Module WorkflowEngine
```

**Alternative: Current User Only (no admin required)**

```powershell
$userModules = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
if (-not (Test-Path $userModules)) { New-Item -ItemType Directory -Path $userModules -Force }
Copy-Item -Path "C:\path\to\wfe\WorkflowEngine" -Destination "$userModules\WorkflowEngine" -Recurse -Force
```

### Option 3: Install from PSGallery (Coming Soon)

```powershell
Install-Module -Name WorkflowEngine
```

## Quick Start

Create and run your first workflow in seconds:

```powershell
# Load the module
Import-Module WorkflowEngine

# Create a workflow
$workflow = New-Workflow

# Add steps
$workflow.AddStep("Step 1", {
    param($ctx)
    Write-Host "Hello from Step 1!"
})

$workflow.AddStep("Step 2", {
    param($ctx)
    Write-Host "Hello from Step 2!"
})

# Execute
$workflow.Execute()

# View summary
$workflow.PrintSummary()
```

## Core Concepts

### Workflows

A workflow is a container for steps that executes them according to your defined logic. Workflows support:
- Multiple retry attempts for the entire workflow
- Configurable delays between retries
- Optional continuation on error
- Interactive execution mode

### Steps

Steps are individual units of work within a workflow. Each step:
- Has a unique name and ID
- Contains a scriptblock (code to execute)
- Can be sequential, parallel, or conditional
- Supports retries and timeouts
- Can depend on other steps

### Context

The context is a shared data store that allows steps to communicate:
- Store values: `$ctx.Set("key", $value)`
- Retrieve values: `$value = $ctx.Get("key")`
- Automatically synchronized across parallel steps

### Step Types

- **Sequential** - Steps execute one after another in order
- **Parallel** - Steps execute simultaneously in a parallel group
- **Conditional** - Steps execute only when a condition is met

## Usage Examples

### Basic Sequential Workflow

```powershell
Import-Module WorkflowEngine

$workflow = New-Workflow

$workflow.AddStep("Initialize", {
    param($ctx)
    Write-Host "Initializing system..."
    $ctx.Set("initialized", $true)
})

$workflow.AddStep("Process", {
    param($ctx)
    if ($ctx.Get("initialized")) {
        Write-Host "Processing data..."
    }
})

$workflow.AddStep("Finalize", {
    param($ctx)
    Write-Host "Finalizing..."
})

$workflow.Execute()
$workflow.PrintSummary()
```

### Parallel Execution

Run multiple independent tasks simultaneously to save time:

```powershell
$workflow = New-Workflow

# Sequential setup
$workflow.AddStep("Prepare Environment", {
    param($ctx)
    Write-Host "Setting up..."
    $ctx.Set("ready", $true)
})

# Parallel group
$parallelGroup = $workflow.AddParallelGroup("Build All Services")

$parallelGroup.AddStep([WorkflowStep]::new("Build API", {
    param($ctx)
    Write-Host "Building API..."
    Start-Sleep 2  # Simulates build time
    Write-Host "API built!"
}))

$parallelGroup.AddStep([WorkflowStep]::new("Build Frontend", {
    param($ctx)
    Write-Host "Building frontend..."
    Start-Sleep 2  # Also 2 seconds, but runs in parallel
    Write-Host "Frontend built!"
}))

# These 2 builds complete in ~2 seconds instead of 4!

$workflow.Execute()
```

**Controlling Parallelism:**

```powershell
# Limit to 2 concurrent tasks
$parallelGroup.MaxParallelism = 2
```

### Conditional Steps

Execute steps only when conditions are met:

```powershell
$workflow = New-Workflow

# Pre-load configuration
$workflow.Context.Set("environment", "production")
$workflow.Context.Set("deployToProduction", $true)

# Regular step
$workflow.AddStep("Build Application", {
    param($ctx)
    Write-Host "Building application..."
})

# Conditional step - only runs in production
$workflow.AddConditionalStep(
    "Production Safety Check",
    { param($ctx) $ctx.Get("environment") -eq "production" },  # Condition
    {
        param($ctx)
        Write-Host "Running production safety checks..."
        Start-Sleep 2
        Write-Host "Safety checks passed!"
    }
)

# Another conditional step
$workflow.AddConditionalStep(
    "Send Deployment Notification",
    { param($ctx) $ctx.Get("deployToProduction") -eq $true },
    {
        param($ctx)
        Write-Host "Sending notification to team..."
    }
)

$workflow.Execute()
```

### Context Sharing

Share data between steps using the context:

```powershell
$workflow = New-Workflow

$workflow.AddStep("Fetch Data", {
    param($ctx)

    # Store data in context
    $ctx.Set("userName", "JohnDoe")
    $ctx.Set("userId", 12345)
    $ctx.Set("timestamp", (Get-Date))
})

$workflow.AddStep("Process Data", {
    param($ctx)

    # Retrieve data from context
    $userName = $ctx.Get("userName")
    $userId = $ctx.Get("userId")

    Write-Host "Processing data for user: $userName (ID: $userId)"

    # Store processed result
    $ctx.Set("processed", $true)
})

$workflow.AddStep("Save Results", {
    param($ctx)

    if ($ctx.Get("processed")) {
        $userName = $ctx.Get("userName")
        Write-Host "Saving results for $userName..."
    }
})

$workflow.Execute()
```

### Error Handling

Configure retries at both step and workflow levels:

```powershell
$workflow = New-Workflow -WorkflowRetries 3 -WorkflowDelay 60

# Add a step with custom retry settings
$unstableStep = $workflow.AddStep("Unstable Operation", {
    param($ctx)

    # Simulate an operation that might fail
    $random = Get-Random -Minimum 1 -Maximum 100
    if ($random -lt 70) {
        throw "Random failure occurred!"
    }

    Write-Host "Operation succeeded!"
})

# Configure step-level retries
$unstableStep.Retries = 5          # Try up to 5 times
$unstableStep.RetryDelay = 10      # Wait 10 seconds between attempts
$unstableStep.Timeout = 30         # Timeout after 30 seconds

$workflow.Execute()
```

**Continue on Error:**

```powershell
# Create workflow that continues even if steps fail
$workflow = New-Workflow -ContinueOnError $true

$workflow.AddStep("Might Fail", {
    param($ctx)
    throw "This step failed!"
})

$workflow.AddStep("Will Still Run", {
    param($ctx)
    Write-Host "I run even though previous step failed!"
})

$workflow.Execute()  # Workflow completes despite the failure
```

### Step Dependencies

Control execution order based on step dependencies:

```powershell
$workflow = New-Workflow

# Step 1: Independent
$step1 = $workflow.AddStep("Download Source", {
    param($ctx)
    Write-Host "Downloading source code..."
})

# Step 2: Independent
$step2 = $workflow.AddStep("Setup Database", {
    param($ctx)
    Write-Host "Setting up database..."
})

# Step 3: Depends on both Step 1 and Step 2
$step3 = $workflow.AddDependentStep(
    "Build Application",
    {
        param($ctx)
        Write-Host "Building application..."
    },
    @($step1.Id, $step2.Id)  # Won't run until both dependencies complete
)

# Step 4: Depends only on Step 3
$step4 = $workflow.AddDependentStep(
    "Deploy Application",
    {
        param($ctx)
        Write-Host "Deploying application..."
    },
    @($step3.Id)
)

$workflow.Execute()
```

### Interactive Execution

Run workflows interactively to select which steps to execute. This is useful for debugging, development, and recovery scenarios.

```powershell
$workflow = New-Workflow

$workflow.AddStep("Step 1: Initialize", { param($ctx) Write-Host "Initializing..." })
$workflow.AddStep("Step 2: Build", { param($ctx) Write-Host "Building..." })
$workflow.AddStep("Step 3: Test", { param($ctx) Write-Host "Testing..." })
$workflow.AddStep("Step 4: Deploy", { param($ctx) Write-Host "Deploying..." })

# Run interactively - presents a menu to select steps
$workflow.ExecuteInteractive()
```

**Interactive Commands:**

| Command | Description |
|---------|-------------|
| `all` | Run all steps |
| `1,3,5` | Run specific steps (comma-separated) |
| `2-6` | Run a range of steps |
| `from 5` | Run from step 5 to the end |
| `to 4` | Run from step 1 to step 4 |
| `1,3-5,9` | Mix individual steps and ranges |
| `exit` / `quit` / `q` | Exit interactive mode |

**Using the -Manual Parameter Pattern:**

Most examples support a `-Manual` switch for interactive mode:

```powershell
# In your script
param(
    [switch]$Manual
)

Import-Module WorkflowEngine

$workflow = New-Workflow
# ... add steps ...

if ($Manual) {
    $workflow.ExecuteInteractive()
} else {
    $workflow.Execute()
}
```

Run normally:
```powershell
.\MyWorkflow.ps1
```

Run interactively:
```powershell
.\MyWorkflow.ps1 -Manual
```

**Common Use Cases for Interactive Mode:**

- **Debugging:** Run only the failing step: `3`
- **Resume:** Skip completed steps and resume: `from 6`
- **Partial Run:** Run only the build phase: `1-5`
- **Quick Test:** Run only the tests: `7,8`
- **Full Run:** Run everything: `all`

## API Reference

### New-Workflow

Creates a new workflow instance.

```powershell
New-Workflow [-WorkflowRetries <int>] [-WorkflowDelay <int>] [-ContinueOnError <bool>]
```

**Parameters:**
- `WorkflowRetries` - Number of times to retry the entire workflow on failure (default: 1)
- `WorkflowDelay` - Seconds to wait between workflow retries (default: 60)
- `ContinueOnError` - Continue executing steps even if one fails (default: false)

### Workflow Methods

#### AddStep

Add a sequential step to the workflow.

```powershell
$step = $workflow.AddStep("Step Name", {
    param($ctx)
    # Your code here
})
```

**Returns:** WorkflowStep object

#### AddConditionalStep

Add a step that only executes when a condition is met.

```powershell
$step = $workflow.AddConditionalStep(
    "Step Name",
    { param($ctx) $ctx.Get("someValue") -eq $true },  # Condition
    {
        param($ctx)
        # Your code here
    }
)
```

**Returns:** WorkflowStep object

#### AddParallelGroup

Create a group of steps that execute in parallel.

```powershell
$group = $workflow.AddParallelGroup("Group Name")
$group.AddStep([WorkflowStep]::new("Parallel Step 1", { param($ctx) ... }))
$group.AddStep([WorkflowStep]::new("Parallel Step 2", { param($ctx) ... }))
```

**Returns:** ParallelGroup object

#### AddDependentStep

Add a step that depends on other steps completing first.

```powershell
$step = $workflow.AddDependentStep(
    "Step Name",
    { param($ctx) ... },
    @($step1.Id, $step2.Id)  # Array of step IDs this depends on
)
```

**Returns:** WorkflowStep object

#### Execute

Execute the workflow (all steps in order).

```powershell
$success = $workflow.Execute()
```

**Returns:** Boolean - true if successful, false if failed

#### ExecuteInteractive

Execute the workflow interactively, allowing selection of specific steps.

```powershell
$workflow.ExecuteInteractive()
```

Presents a menu where you can select which steps to run using commands like `all`, `1,3,5`, `2-6`, `from 5`, `to 4`, or `exit`.

#### PrintSummary

Display a detailed execution summary.

```powershell
$workflow.PrintSummary()
```

### WorkflowStep Properties

```powershell
$step = $workflow.AddStep("My Step", { param($ctx) ... })

# Configure step behavior
$step.Retries = 5           # Number of retry attempts (default: 3)
$step.RetryDelay = 30       # Seconds between retries (default: 30)
$step.Timeout = 120         # Timeout in seconds (0 = no timeout)
$step.DependsOn = @($id1)   # Array of step IDs this depends on

# Read-only properties
$step.Id                    # Unique step identifier
$step.Name                  # Step name
$step.Status                # Current status (Pending, Running, Completed, Failed, Skipped)
$step.Result                # Return value from the step
$step.ErrorMessage          # Error message if step failed
$step.StartTime             # When step started
$step.EndTime               # When step ended
```

### Context Methods

```powershell
# Set a value
$ctx.Set("key", $value)
$ctx.SetValue("key", $value)  # Alias

# Get a value
$value = $ctx.Get("key")
$value = $ctx.GetValue("key")  # Alias

# Get all variables as hashtable
$allVars = $ctx.GetSnapshot()
```

## Configuration Options

### Workflow-Level Configuration

```powershell
$workflow = New-Workflow `
    -WorkflowRetries 3 `          # Retry entire workflow up to 3 times
    -WorkflowDelay 60 `            # Wait 60 seconds between workflow retries
    -ContinueOnError $true         # Continue even if steps fail
```

### Step-Level Configuration

```powershell
$step = $workflow.AddStep("My Step", { param($ctx) ... })

$step.Retries = 5              # Retry step up to 5 times
$step.RetryDelay = 15          # Wait 15 seconds between step retries
$step.Timeout = 300            # Timeout after 5 minutes (300 seconds)
```

### Parallel Group Configuration

```powershell
$group = $workflow.AddParallelGroup("Build Group")
$group.MaxParallelism = 3      # Only run 3 tasks concurrently
```

## Advanced Features

### Timeouts

Prevent runaway operations with timeouts:

```powershell
$step = $workflow.AddStep("Long Running Task", {
    param($ctx)
    # This task might take too long
    Start-Sleep 600  # 10 minutes
})

$step.Timeout = 60  # Kill it after 60 seconds
```

### Pre-Loading Context

Pass external variables into your workflow:

```powershell
# CORRECT WAY: Pre-load into context
$externalConfig = @{
    Server = "prod-server"
    Port = 8080
}

$workflow = New-Workflow
$workflow.Context.Set("config", $externalConfig)
$workflow.Context.Set("environment", "production")

$workflow.AddStep("Use External Config", {
    param($ctx)
    $config = $ctx.Get("config")
    Write-Host "Connecting to $($config.Server):$($config.Port)"
})
```

### Custom Step Status Checks

```powershell
$workflow.Execute()

# Check individual step status
foreach ($item in $workflow.Steps) {
    if ($item.GetType().Name -eq 'WorkflowStep') {
        $duration = $item.GetDurationSeconds()
        Write-Host "$($item.Name): $($item.Status) ($($duration)s)"
    }
}
```

### Accessing Step Results

```powershell
$step1 = $workflow.AddStep("Calculate Sum", {
    param($ctx)
    $sum = 10 + 20
    return $sum  # Return value stored in step
})

$workflow.Execute()

# Access the result
Write-Host "Step returned: $($step1.Result)"  # Outputs: 30
```

## Real-World Examples

### CI/CD Deployment Pipeline

```powershell
$workflow = New-Workflow -WorkflowRetries 2 -WorkflowDelay 30

# Pre-load configuration
$workflow.Context.Set("environment", "staging")
$workflow.Context.Set("version", "2.5.0")

# Initialize
$workflow.AddStep("Initialize Pipeline", {
    param($ctx)
    $env = $ctx.Get("environment")
    $ctx.Set("deploymentId", "DEPLOY-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Write-Host "Deploying to $env..."
})

# Parallel builds
$buildGroup = $workflow.AddParallelGroup("Build Services")
$buildGroup.AddStep([WorkflowStep]::new("Build API", {
    param($ctx)
    # docker build -t myapp-api:latest ./api
    Write-Host "Building API service..."
}))
$buildGroup.AddStep([WorkflowStep]::new("Build Frontend", {
    param($ctx)
    # npm run build
    Write-Host "Building frontend..."
}))

# Tests
$workflow.AddStep("Run Tests", {
    param($ctx)
    # npm test
    Write-Host "Running tests..."
})

# Deploy
$deployStep = $workflow.AddStep("Deploy to Cluster", {
    param($ctx)
    # kubectl apply -f deployment.yaml
    Write-Host "Deploying to Kubernetes..."
})
$deployStep.Retries = 3
$deployStep.RetryDelay = 10

# Health check
$healthStep = $workflow.AddStep("Health Check", {
    param($ctx)
    # Invoke-WebRequest -Uri "https://myapp.com/health"
    Write-Host "Checking application health..."
})
$healthStep.Retries = 5
$healthStep.RetryDelay = 10

$workflow.Execute()
$workflow.PrintSummary()
```

### Data Processing Pipeline

```powershell
$workflow = New-Workflow

# Extract
$workflow.AddStep("Extract Data", {
    param($ctx)
    # $data = Invoke-SqlCmd -Query "SELECT * FROM source_table"
    $ctx.Set("recordCount", 1000)
    Write-Host "Extracted data from source"
})

# Transform (parallel processing)
$transformGroup = $workflow.AddParallelGroup("Transform Data")
$transformGroup.AddStep([WorkflowStep]::new("Clean Data", {
    param($ctx)
    Write-Host "Cleaning data..."
}))
$transformGroup.AddStep([WorkflowStep]::new("Enrich Data", {
    param($ctx)
    Write-Host "Enriching data..."
}))
$transformGroup.AddStep([WorkflowStep]::new("Validate Data", {
    param($ctx)
    Write-Host "Validating data..."
}))

# Load
$workflow.AddStep("Load Data", {
    param($ctx)
    $count = $ctx.Get("recordCount")
    # Invoke-SqlCmd -Query "INSERT INTO target_table ..."
    Write-Host "Loaded $count records to destination"
})

$workflow.Execute()
```

### Server Maintenance Workflow

```powershell
$workflow = New-Workflow

# Pre-load server list
$servers = @("server1", "server2", "server3")
$workflow.Context.Set("servers", $servers)

$workflow.AddStep("Create Backup", {
    param($ctx)
    Write-Host "Creating backup before maintenance..."
    $backupId = "BACKUP-" + (Get-Date -Format "yyyyMMdd")
    $ctx.Set("backupId", $backupId)
})

# Parallel maintenance
$maintenanceGroup = $workflow.AddParallelGroup("Update Servers")
foreach ($server in $servers) {
    $maintenanceGroup.AddStep([WorkflowStep]::new("Update $server", {
        param($ctx)
        # Invoke-Command -ComputerName $using:server -ScriptBlock { ... }
        Write-Host "Updating $server..."
        Start-Sleep 2
    }))
}

$workflow.AddStep("Verify All Servers", {
    param($ctx)
    $servers = $ctx.Get("servers")
    foreach ($server in $servers) {
        # Test-Connection -ComputerName $server
        Write-Host "Verified $server is online"
    }
})

$workflow.Execute()
```

## Testing

The project includes comprehensive unit tests. Run them with:

```powershell
# Run all tests
Pester .\WorkflowEngine.Tests.ps1

# Run specific test
Pester .\WorkflowEngine.Tests.ps1 -TestName "Basic Workflow Execution"
```

### Test Coverage

The test suite covers:
- Basic workflow execution
- Context sharing between steps
- Conditional step execution
- Parallel execution with runspaces
- Error handling and retries
- Timeout functionality
- Step dependencies
- Real-world scenarios

## Performance Considerations

### Parallel Execution Performance

Parallel execution uses runspace pools, which are significantly faster than PowerShell jobs:

- **Sequential:** 4 tasks × 2s = 8 seconds
- **Parallel (4 runspaces):** ~2 seconds
- **Speedup:** 4x faster

### Best Practices

1. **Use Parallel Groups for Independent Tasks**
   - Network operations (API calls, downloads)
   - Independent builds or compilations
   - File processing tasks

2. **Set Appropriate MaxParallelism**
   ```powershell
   $group.MaxParallelism = [Environment]::ProcessorCount
   ```

3. **Keep Parallel Steps Self-Contained**
   - Avoid external function dependencies in parallel steps
   - Include all necessary logic within the scriptblock

4. **Use Timeouts for External Operations**
   ```powershell
   $step.Timeout = 300  # 5 minutes max
   ```

## Troubleshooting

### Common Issues

**Issue:** Context values not available in parallel steps

**Solution:** Parallel steps receive a snapshot of the context. Set values before the parallel group:
```powershell
$workflow.Context.Set("myValue", 123)  # Before parallel group
```

**Issue:** Functions not available in parallel steps

**Solution:** Include the function definition inside the parallel step scriptblock:
```powershell
$step = [WorkflowStep]::new("Task", {
    param($ctx)

    function MyHelper {
        param($x)
        return $x * 2
    }

    $result = MyHelper -x 5
})
```

**Issue:** Step times out even though it should complete quickly

**Solution:** Increase the timeout or check for blocking operations:
```powershell
$step.Timeout = 600  # Increase to 10 minutes
```

## Requirements

- **PowerShell 5.1** or later
- **Windows PowerShell 5.1** or later
- No external dependencies

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

1. Clone the repository
2. Make your changes to `WorkflowEngine/WorkflowEngine.psm1`
3. Add tests to `WorkflowEngine.Tests.ps1`
4. Run the test suite
5. Submit a pull request

### Coding Standards

- Follow PowerShell best practices
- Include comment-based help for new functions
- Add examples for new features
- Ensure all tests pass

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Changelog

### Version 1.0.0
- Initial release
- Sequential workflow execution
- Parallel execution with runspace pools
- Conditional steps
- Context sharing
- Error handling and retries
- Timeout support
- Step dependencies
- Interactive execution mode
- Comprehensive test suite
- 9 example workflows

## Support

For issues, questions, or contributions:
- **Issues:** Open an issue on GitHub
- **Discussions:** Use GitHub Discussions for questions
- **Examples:** Check the `Examples/` folder for working code

## Acknowledgments

Built with PowerShell 5.1+ compatibility in mind.
