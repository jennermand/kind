. ./utils.ps1

$WSNamespace = "argo"

Write-Host "🛠️ installing argo workflows in $WSNamespace"

$valuesFilePath = "./0-boot/charts/03-argo-workflow/values.yaml"

if (!(kubectl get namespace $WSNamespace)) {
    Write-Host "👌 Installere Argo Workflows i $WSNamespace ws-namespace..."
    kubectl create namespace $WSNamespace
}

# Download the Argo Workflows Helm chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install or upgrade Argo Workflows using the custom values.yaml file
helm upgrade --install argo-workflows argo/argo-workflows -n $WSNamespace -f $valuesFilePath 

#wait until the argo server service is running before port-forwarding

Write-Host "🔍 Venter på at Argo Workflows server service er oppe..."
if (-not (Wait-ForPods -Namespace $WSNamespace -LabelSelector "app.kubernetes.io/name=argo-workflows-server")) {
    Write-Host "Error: Pods did not become ready in time." -ForegroundColor Red
    exit 1
}

Start-Process "http://localhost:2746"
Start-Job { kubectl -n argo port-forward service/argo-workflows-server 2746:2746 }

