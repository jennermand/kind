$namespace = "argo-cd"
$token = $env:GITHUB_TOKEN
$gitrepo = "https://github.com/sparnord/jensk-dev.git"
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
    $existingCluster = kind get clusters 

    if ($existingCluster) {
        # Ask the user if the existing cluster should be deleted
        $response = Read-Host "A kind cluster named '$CLUSTER_NAME' is already running. Do you want to delete it? (y/n)"
        if ($response -eq 'y') {
            Write-Host "Deleting the existing kind cluster..."
            docker ps -aq | ForEach-Object { docker rm -f $_ }
            
            kind delete clusters --all
            
            Start-Sleep -Milliseconds 2000
            # Wait until the cluster is deleted
            Write-Host "Waiting for the kind cluster to be fully deleted..."
            $maxRetries = 30
            $retryCount = 0
            $clusterDeleted = $false

            while (-not $clusterDeleted -and $retryCount -lt $maxRetries) {
                $existingCluster = kind get clusters 
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
    - hostPath: ${SERVICE_ACCOUNT_KEY_FILE}
      containerPath: /etc/kubernetes/pki/sa.pub
    - hostPath: ${SERVICE_ACCOUNT_SIGNING_KEY_FILE}
      containerPath: /etc/kubernetes/pki/sa.key
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        service-account-issuer: ${SERVICE_ACCOUNT_ISSUER}
        service-account-key-file: /etc/kubernetes/pki/sa.pub
        service-account-signing-key-file: /etc/kubernetes/pki/sa.key
    controllerManager:
      extraArgs:
        service-account-private-key-file: /etc/kubernetes/pki/sa.key
"@

        # Write the configuration to a temporary file
        $tempConfigPath = [System.IO.Path]::GetTempFileName()
        $tempConfigPath = [System.IO.Path]::ChangeExtension($tempConfigPath, ".yaml")
        $kindConfig | Out-File -FilePath $tempConfigPath -Encoding utf8

        # Create the kind cluster with the specified configuration
        kind create cluster --name $CLUSTER_NAME --config $tempConfigPath

    }
}

function installPrometheus() {
    . ./install-prometheus.ps1
}

function installArgoCD() {
    . ./install-argo-cd.ps1
}

function Show-ClusterStatus {
    param (
        [string]$Namespace,
        [int]$TimeoutSeconds = 300
    )
    
    $spinner = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    $startTime = Get-Date
    $i = 0
    Start-Sleep -Milliseconds 5000
    
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
            Start-Sleep -Milliseconds 2000
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
            Write-Host $status -NoNewline 
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

    . ./portForward.ps1

}

function startMenu() {    
    # Call k8s-menu.ps1 with parameters
    try {
        . ./k8s-menu.ps1
    }
    catch {
        Write-Host "❌ Error launching menu: $_" -ForegroundColor Red
        exit 1
    }
}

function Check-ExtraMounts {
    # Get the control plane node name
    $controlPlaneNode = kubectl get nodes --selector='node-role.kubernetes.io/control-plane' --output=jsonpath='{.items[0].metadata.name}'
    
    if ($controlPlaneNode) {
        Write-Host "Control plane node: $controlPlaneNode"
        
        # Get the Docker container ID for the control plane node
        $controlPlaneContainer = docker ps --filter "name=$controlPlaneNode" --format "{{.ID}}"
        
        if ($controlPlaneContainer) {
            Write-Host "Inspecting control plane container: $controlPlaneContainer"
            
            # Get the mounts of the control plane container
            $mounts = docker inspect $controlPlaneContainer | ConvertFrom-Json | Select-Object -ExpandProperty Mounts
            
            # Filter and display the extra mounts
            $extraMounts = $mounts | Where-Object { $_.Destination -eq "/etc/ssl/certs/ca-certificates.crt" -or $_.Destination -eq "/etc/kubernetes/pki/sa.pub" -or $_.Destination -eq "/etc/kubernetes/pki/sa.key" }
            
            if ($extraMounts) {
                Write-Host "Extra mounts in control plane container:"
                $extraMounts | ForEach-Object {
                    Write-Host "HostPath: $($_.Source) -> ContainerPath: $($_.Destination)"
                }
            }
            else {
                Write-Host "No extra mounts found in control plane container."
            }
        }
        else {
            Write-Host "Control plane container not found."
        }
    }
    else {
        Write-Host "Control plane node not found."
    }
}

# Define the environment variables
$env:AZURE_STORAGE_ACCOUNT = "snbakscorpdevswcshdsa01"
$env:AZURE_STORAGE_CONTAINER = "datawarehouse-storage"

# Export the environment variables
$SERVICE_ACCOUNT_ISSUER = "https://snbakscorpdevswcshdsa01.blob.core.windows.net/$($env:AZURE_STORAGE_CONTAINER)/"
$SERVICE_ACCOUNT_KEY_FILE = "$(Get-Location)\certs\sa.pub"
$SERVICE_ACCOUNT_SIGNING_KEY_FILE = "$(Get-Location)\certs\sa.key"

# Print the variables to verify
# Write-Host "SERVICE_ACCOUNT_ISSUER: $SERVICE_ACCOUNT_ISSUER"
# Write-Host "SERVICE_ACCOUNT_KEY_FILE: $SERVICE_ACCOUNT_KEY_FILE"
# Write-Host "SERVICE_ACCOUNT_SIGNING_KEY_FILE: $SERVICE_ACCOUNT_SIGNING_KEY_FILE"


preCheckCluster

CreateKindCluster

# should be added to menu or passed as a paramter
# installPrometheus

installArgoCD

waitForCompletion
# post checks
Check-ExtraMounts

. ./install-pullsecret.ps1 

startMenu

# At the end of runKind.ps1

# Create parameter hashtable for splatting

