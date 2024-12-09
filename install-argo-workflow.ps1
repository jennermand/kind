$namespace = "argo"
$ARGO_WORKFLOWS_VERSION = "v3.6.2"
$valuesFilePath = "./0-boot/charts/03-argo-workflow/values.yaml"

if (!(kubectl get namespace $namespace)) {
    Write-Host "👌 Installere Argo Workflows i $namespace namespace..."
    kubectl create namespace $namespace
}

# Download the Argo Workflows Helm chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install or upgrade Argo Workflows using the custom values.yaml file
helm upgrade --install argo-workflows argo/argo-workflows -n $namespace -f $valuesFilePath 

#wait until the argo server service is running before port-forwarding
Write-Host "🔍 Venter på at Argo Workflows server service er oppe..."
while (!(kubectl get svc -n $namespace argo-workflows-server)) {
    Start-Sleep -Seconds 5
}

Start-Sleep -Seconds 10
Start-Job { kubectl -n $namespace port-forward service/argo-workflows-server 2746:2746 }
Start-Process "http://localhost:2746"

# # Retrieve the token from the Kubernetes secret
# $secretName = "argo-workflow"
# $tokenBase64 = kubectl get secret $secretName -n $namespace -o jsonpath='{.data.token}'

# # Decode the base64 encoded token
# $tokenBytes = [System.Convert]::FromBase64String($tokenBase64)
# $token = [System.Text.Encoding]::UTF8.GetString($tokenBytes)

# # Prepend "Bearer " to the token
# $ARGO_TOKEN = "Bearer $token"

# # Output the token
# Write-Host $ARGO_TOKEN