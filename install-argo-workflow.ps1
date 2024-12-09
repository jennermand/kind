if (!(kubectl get namespace argo)) {
    Write-Host "👌 Installere Argo Workflows i argocd namespace..."
    kubectl create namespace argo    
    kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/$ARGO_WORKFLOWS_VERSION/install.yaml
}

if (kubectl get ns argo -o name) {
    Start-Job { kubectl -n argo port-forward service/argo-server 2746:2746 }

    Start-Sleep -Seconds 5
    Start-Process "http://localhost:2746"
}