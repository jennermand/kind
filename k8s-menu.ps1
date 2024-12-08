
function Show-Variables {
    param()
    
    Write-Host "`n=== Current Variables ===" -ForegroundColor Cyan
    
    $variables = @(
        @{Name = "Namespace"; Value = $namespace; Type = $namespace.GetType().Name }
        @{Name = "Token"; Value = "***${token.Substring(0,4)}..."; Type = $token.GetType().Name }
        @{Name = "Git Repo"; Value = $gitrepo; Type = $gitrepo.GetType().Name }
        @{Name = "Argo Version"; Value = $ARGO_WORKFLOWS_VERSION; Type = $ARGO_WORKFLOWS_VERSION.GetType().Name }
        @{Name = "Workflows Enabled"; Value = $enableWorkflows; Type = $enableWorkflows.GetType().Name }
        @{Name = "Events Enabled"; Value = $enableEvents; Type = $enableEvents.GetType().Name }
    )

    $nameWidth = ($variables | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    $typeWidth = ($variables | ForEach-Object { $_.Type.Length } | Measure-Object -Maximum).Maximum

    foreach ($var in $variables) {
        $name = $var.Name.PadRight($nameWidth)
        $type = $var.Type.PadRight($typeWidth)
        Write-Host ("{0} [{1}]: " -f $name, $type) -NoNewline -ForegroundColor Yellow
        Write-Host $var.Value -ForegroundColor Green
    }
    Write-Host "=====================`n" -ForegroundColor Cyan
}

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

function FunctionC {
    Write-Host "Performing function C..."
    # Add your code for function C here
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
    'x' = @{
        Description = "Exit"
        Action      = { FunctionC }
    }
    # 'r' = @{
    #     Description = "reload script"
    #     Action      = { Reload-Script }
    # }
}
function Update-ArgoCD {
    param(
        [string]$Namespace = "argo-cd",
        [hashtable]$Values
    )

    try {
        # Validate helm exists
        if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
            throw "Helm is not installed or not in PATH"
        }

        # Validate path exists
        if (-not (Test-Path "./0-boot")) {
            throw "Chart path './0-boot' not found"
        }

        # Create hashtable of helm values
        $helmValues = @{
            "events.argocd.token"     = $token
            "argocd.argocd.token"     = $token
            "argocd.argocd.repo"      = ""
            "events.argocd.event"     = $enableEvents
            "argocd.argocd.workflows" = $enableWorkflows
            "argocd.argocd.version"   = $ARGO_WORKFLOWS_VERSION
        }

        # Convert hashtable to --set parameters
        $setParams = $helmValues.GetEnumerator() | ForEach-Object {
            "--set=$($_.Key)=$($_.Value)"
        }

        # Execute helm upgrade
        $result = helm upgrade argo-cd ./0-boot -n $Namespace $setParams

        if ($LASTEXITCODE -ne 0) {
            throw "Helm upgrade failed with exit code $LASTEXITCODE"
        }

        Write-Host "✅ Argo CD upgraded successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error upgrading Argo CD: $_" -ForegroundColor Red
        return $false
    }
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
