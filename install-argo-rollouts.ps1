. ./utils.ps1

$RONamespace = "argo-rollouts"

Write-Host "🛠️ Installing Argo Rollouts in $RONamespace"

$valuesFilePath = "./0-boot/charts/04-argo-rollout/values.yaml"

if (!(kubectl get namespace $RONamespace -o name)) {
  Write-Host "👌 Creating namespace '$RONamespace'..."
  kubectl create namespace $RONamespace
}

# Download the Argo Rollouts Helm chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install or upgrade Argo Rollouts using the custom values.yaml file
helm upgrade --install argo-rollouts argo/argo-rollouts -n $RONamespace -f $valuesFilePath `
  --set dashboard.enabled=true `
  --set dashboard.service.type=LoadBalancer

# Wait until the Argo Rollouts controller is running before port-forwarding
Write-Host "🔍 Waiting for Argo Rollouts controller to be up..."
if (-not (Wait-ForPods -Namespace $RONamespace -LabelSelector "app.kubernetes.io/component=rollouts-controller")) {
  Write-Host "Error: Pods did not become ready in time." -ForegroundColor Red
  exit 1
}

# Wait until the Argo Rollouts dashboard is running before port-forwarding
Write-Host "🔍 Waiting for Argo Rollouts dashboard to be up..."
if (-not (Wait-ForPods -Namespace $RONamespace -LabelSelector "app.kubernetes.io/component=rollouts-dashboard")) {
  Write-Host "Error: Dashboard pods did not become ready in time." -ForegroundColor Red
  exit 1
}

# Port-forward the Argo Rollouts dashboard service
Start-Process "http://localhost:3100"
Start-Job { kubectl -n $RONamespace port-forward service/argo-rollouts-dashboard 3100:3100 }