if (!(kubectl get namespace argo-events)) {
    kubectl create namespace argo-events
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/namespace-install.yaml
    # Install with a validating admission controller
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
    kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
    kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/event-sources/webhook.yaml


    # Install with a validating admission controller
    Write-Host "👌 Installere Argo Events i argo-events namespace..."
}
$token = $env:GITHUB_TOKEN
$enableEvents = $true
Write-Host "👌 Applying local settings i argo-events...."
helm upgrade -i argo-events ./0-boot/charts/02-argo-events/ -n argo-events `
    --set "argocd.token=$token" `
    --set "argocd.repo=$gitrepo" `
    --set "argocd.event=$enableEvents" `
    --set "argocd.workflows=$enableWorkflows" `
    --set "argocd.version=$ARGO_WORKFLOWS_VERSION" `
    --set "argocd.repo=$gitrepo" `
    
    
    