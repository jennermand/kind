if (!(kubectl get namespace argo)) {
    Write-Host "👌 Installere Argo Workflows i argocd namespace..."
    kubectl create namespace argo    
    kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/$ARGO_WORKFLOWS_VERSION/install.yaml
}

    