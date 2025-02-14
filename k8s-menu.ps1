. .\utils.ps1

# Add to menu options
function FunctionA {
    param (
        [string]$param1
    )
    Write-Host "Performing function A with parameter: $param1"
    # Add your code for function A here
}

function FunctionB {
    param (
        [string]$param1
    )
    Write-Host "Performing function B with parameter: $param1"
    # Add your code for function B here
}

function StopAllJobsAndExit {
    Write-Host "Stopping all jobs"
    # Get all running jobs
    $jobs = Get-Job

    # Check if there are any jobs to stop
    if ($jobs) {
        foreach ($job in $jobs) {
            # Stop the job
            Stop-Job -Id $job.Id
            # Remove the job
            Remove-Job -Id $job.Id
        }
        Write-Output "All jobs have been stopped and removed."
    }
    else {
        Write-Output "No jobs found."
    }
}

# Define the menu options as a hashtable
$menuOptions = @{   
    'b' = @{
        Description = "Install or upgrade Argo-Events"
        Action      = { 
            . .\install-argo-events.ps1 
        }
    }
    'c' = @{
        Description = "Install or upgrade Argo-Workflow"
        Action      = { 
            . .\install-argo-workflow.ps1            
        }
    }
    'd' = @{
        Description = "Install or upgrade Argo-Rollouts"
        Action      = { 
            . .\install-argo-rollouts.ps1            
        }
    }
    'e' = @{
        Description = "Port forward again"
        Action      = { 
            . .\portForward.ps1         
        }
    }
    'f' = @{
        Description = "Install extra funcs (prometheus, secret-replicator, csi-secret-store)"
        Action      = { 
            . .\install-prometheus.ps1
        }
    }
    'x' = @{
        Description = "Exit"
        Action      = { StopAllJobsAndExit }
    }
    # 'r' = @{
    #     Description = "reload script"
    #     Action      = { Reload-Script }
    # }
}
function Update-ArgoCD {
    . ./install-argo-cd.ps1 
}
$menuOptions['v'] = @{
    Description = "View all variables"
    Action      = { Show-Variables }
}

# Update menu option to use new function
$menuOptions['a'] = @{
    Description = "Update Argo CD installation"
    Action      = { Update-ArgoCD -Namespace $namespace }
}

function Show-Menu {
    Clear-Host
    Write-Host "====================="
    Write-Host " Kubernetes Menu"
    Write-Host "====================="
    foreach ($key in $menuOptions.Keys | Sort-Object) {
        Write-Host "$key : $($menuOptions[$key].Description)"
    }
    Write-Host "====================="
}

do {
    # show meny ordered by key    
    Show-Menu

    Write-Host "`n" -NoNewline -BackgroundColor DarkGreen -ForegroundColor White
    Write-Host "Available options: " -NoNewline -BackgroundColor DarkGreen -ForegroundColor White
    
    $choice = Read-Host "Enter your choice"
    try {

        if ($menuOptions.ContainsKey($choice)) {
            & $menuOptions[$choice].Action
            if ($choice -ne 'x') {
                Pause
            }
        }
        else {
            Write-Host "Invalid choice, please try again."
            Pause
        }
    }
    catch {
        Write-Host "Dang - something went wrong: $_"
        Pause
        continue
    }
} while ($choice -ne 'x')

Write-Host "Exiting..."
