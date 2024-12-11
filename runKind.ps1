$namespace = "argo-cd"
$token = $env:GITHUB_TOKEN
$gitrepo = "https://github.com/jennermand/kind.git"
$ARGO_WORKFLOWS_VERSION = "v3.6.2"
$enableWorkflows = $false
$enableEvents = $false
$CLUSTER_NAME = "kind"

# Some documentation
# https://mauilion.dev/posts/kind-pvc-localdata/
#test if docker is running
if (!(docker info --format '{{.ServerVersion}}')) {
    Write-Host "❌ Docker is not running. Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

function Show-Spinner {
    param (
        [string]$Namespace,
        [int]$TimeoutSeconds = 300
    )
    
    $spinner = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    $startTime = Get-Date
    $i = 0
    
    Write-Host "`n"
    while ((Get-Date) -le $startTime.AddSeconds($TimeoutSeconds)) {
        $status = kubectl get pods -A --no-headers
        $totalPods = ($status).Count
        $runningPods = ($status | Select-String -Pattern "Running").Count
        
        Write-Host "`r$($spinner[$i]) Waiting for pods in cluster ... ($runningPods/$totalPods) " -NoNewline
        $i = ($i + 1) % $spinner.Length
        
        if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
            Write-Host "`r✓ All pods are running in '$Namespace' namespace!     " -ForegroundColor Green
            return $true
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "`r✗ Timeout waiting for pods in '$Namespace' namespace!     " -ForegroundColor Red
    return $false
}

function preCheckCluster() {
    $existingCluster = kind get clusters | Select-String -Pattern $CLUSTER_NAME

    if ($existingCluster) {
        # Ask the user if the existing cluster should be deleted
        $response = Read-Host "A kind cluster named '$CLUSTER_NAME' is already running. Do you want to delete it? (y/n)"
        if ($response -eq 'y') {
            Write-Host "Deleting the existing kind cluster..."
            kind delete cluster --name $CLUSTER_NAME
            kind delete clusters --all
            docker ps -aq | ForEach-Object { docker rm -f $_ }
            
            # Wait until the cluster is deleted
            Write-Host "Waiting for the kind cluster to be fully deleted..."
            $maxRetries = 30
            $retryCount = 0
            $clusterDeleted = $false

            while (-not $clusterDeleted -and $retryCount -lt $maxRetries) {
                $existingCluster = kind get clusters | Select-String -Pattern $CLUSTER_NAME
                if (-not $existingCluster) {
                    $clusterDeleted = $true
                }
                else {
                    Start-Sleep -Seconds 10
                    $retryCount++
                }
            }

            if (-not $clusterDeleted) {
                Write-Host "❌ The kind cluster was not deleted in time." -ForegroundColor Red
                exit 1
            }

            Write-Host "✅ The kind cluster has been deleted."
        }
    }
}

function CreateKindCluster() {
    if (!$existingCluster) {
        $kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: C:\Temp\kind\data\certs\certificate.crt
        containerPath: /etc/ssl/certs/ca-certificates.crt
"@

        # Write the configuration to a temporary file
        $tempConfigPath = [System.IO.Path]::GetTempFileName()
        $tempConfigPath = [System.IO.Path]::ChangeExtension($tempConfigPath, ".yaml")
        $kindConfig | Out-File -FilePath $tempConfigPath -Encoding utf8

        # Create the kind cluster with the specified configuration
        kind create cluster --name $CLUSTER_NAME --config $tempConfigPath

    }
}

function installArgoCD() {
    kubectl create ns $namespace 
 
    Start-Sleep -Seconds 5  
 
    Write-Host "👌 Installere ArgoCD i $namespace namespace..." 
    helm install $namespace ./0-boot -n $namespace `
        --set "events.argocd.token=$token" `
        --set "argocd.argocd.token=$token" `
        --set "argocd.argocd.repo=$gitrepo" `
        --set "events.argocd.event=$enableEvents" `
        --set "argocd.argocd.workflows=$enableWorkflows" `
        --set "argocd.argocd.version=$ARGO_WORKFLOWS_VERSION" `
 
    if ($LASTEXITCODE -ne 0) { 
        Write-Host "Error: Helm install failed." -ForegroundColor Red 
    }
}

function Show-ClusterStatus {
    param (
        [string]$Namespace,
        [int]$TimeoutSeconds = 300
    )
    
    $spinner = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    $startTime = Get-Date
    $i = 0
    
    Write-Host "`n📦 Initializing cluster status check..."
    while ((Get-Date) -le $startTime.AddSeconds($TimeoutSeconds)) {
        try {
            # Get Docker status
            $dockerStatus = docker ps --format "{{.Status}}" 2>$null
            $totalContainers = ($dockerStatus).Count
            $runningContainers = ($dockerStatus | Select-String -Pattern "Up").Count

            # Get K8s status
            $podStatus = kubectl get pods -A --no-headers
            $totalPods = ($podStatus).Count
            $runningPods = ($podStatus | Select-String -Pattern "Running").Count
            
            # Create multi-line status display that stays in place
            $status = @"
`r$($spinner[$i]) Cluster Status                                          
   🐳 Docker: ($runningContainers/$totalContainers) containers running    
   ☸️  K8s: ($runningPods/$totalPods) pods running                       
"@

            # \e[nA - Move cursor up n lines
            # \e[nB - Move cursor down n lines
            # \e[nC - Move cursor forward n characters
            # \e[nD - Move cursor backward n characters
            # \e[2J - Clear entire screen
            # \e[K  - Clear from cursor to end of line
            # Use ANSI escape codes to move cursor up 2 lines after each update
            
            Write-Host "`e[2A" -NoNewline
            $i = ($i + 1) % $spinner.Length
            
            if (($runningContainers -eq $totalContainers) -and 
                ($runningPods -eq $totalPods) -and 
                ($totalPods -gt 0)) {
                Write-Host "`n`n✅ Cluster is ready!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "`n❌ Error: $_" -ForegroundColor Red
            return $false
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "`n⏰ Timeout after $TimeoutSeconds seconds" -ForegroundColor Yellow
    return $false
}



function waitForCompletion() {
    # Usage in runKind.ps1:
    Show-ClusterStatus -TimeoutSeconds 300
    Show-Spinner -Namespace $namespace -TimeoutSeconds 300
    Write-Host "Alle pods er nu i 'Running' tilstand i $namespace namespace."
    Start-Sleep -Seconds 5
    Start-Process "http://localhost:8443"

    # kubectl apply -f .\pull-secret.yaml

    . .\portForward.ps1

}

function startMenu() {
    $menuParams = @{
        namespace              = $namespace
        token                  = $token
        gitrepo                = $gitrepo
        ARGO_WORKFLOWS_VERSION = $ARGO_WORKFLOWS_VERSION
        enableWorkflows        = $enableWorkflows
        enableEvents           = $enableEvents
    }
    # pause - wait for key pressed
    
    
    # Call k8s-menu.ps1 with parameters
    try {
        . .\k8s-menu.ps1
    }
    catch {
        Write-Host "❌ Error launching menu: $_" -ForegroundColor Red
        exit 1
    }
}


preCheckCluster

CreateKindCluster

installArgoCD

waitForCompletion

startMenu


# At the end of runKind.ps1

# Create parameter hashtable for splatting


