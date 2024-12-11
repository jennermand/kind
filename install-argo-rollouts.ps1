. ./utils.ps1

$RONamespace = "argo-rollouts"

Write-Host "🛠️ installing argo Rollouts in $RONamespace"

$valuesFilePath = "./0-boot/charts/03-argo-workflow/values.yaml"

if (!(kubectl get namespace $RONamespace)) {
  Write-Host "👌 Installere Argo Rollouts i $RONamespace ws-namespace..."
  kubectl create namespace $RONamespace
}

# Download the Argo Workflows Helm chart
helm repo add argo-rollout https://argoproj.github.io/argo-rollouts
helm repo update

# Install or upgrade Argo Workflows using the custom values.yaml file
helm upgrade --install argo-rollouts argo/argo-rollouts -n $RONamespace -f $valuesFilePath 

#wait until the argo server service is running before port-forwarding

Write-Host "🔍 Venter på at Argo Workflows server service er oppe..."
if (-not (Wait-ForPods -Namespace $RONamespace -LabelSelector "app.kubernetes.io/component=rollouts-controller")) {
  Write-Host "Error: Pods did not become ready in time." -ForegroundColor Red
  exit 1
}

Start-Process "http://localhost:3100"
# Start-Job { kubectl -n argo port-forward service/Rollouts 3100:3100 }