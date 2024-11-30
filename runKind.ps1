# Some documentation
# https://mauilion.dev/posts/kind-pvc-localdata/

$namespace="argo-cd"
$token=$env:GITHUB_TOKEN
$gitrepo="https://github.com/jennermand/kind.git"

kind delete cluster --name kind 
kind delete clusters --all

docker ps -aq | ForEach-Object { docker rm -f $_ }

kind create cluster --config volume.yaml

kubectl create ns $namespace
kubectl create namespace argo-events

Start-Sleep -Seconds 5
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
# Install with a validating admission controller
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml

Write-Host "👌 Installere ArgoCD i $namespace namespace..."
helm install $namespace ./0-boot -n $namespace --set "argocd.argocd.token=$token,argocd.argocd.repo=$gitrepo"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Helm install failed." -ForegroundColor Red
    exit 1
}


# helm install boot $bootDir/01-boot 

# kubectl wait --for=condition=complete -n argo-cd service/argo-cd-server
while ((kubectl get pods -n $namespace --no-headers | Select-String -Pattern "Running").Count -ne (kubectl get pods -n $namespace --no-headers).Count) {
    Write-Host "Venter på at alle pods er i 'Running' tilstand i $namespace namespace..."
    Start-Sleep -Seconds 5
}


Write-Host "Alle pods er nu i 'Running' tilstand i $namespace namespace."

# . .\mountVolumnes.ps1

Start-Sleep -Seconds 5

# kubectl apply -f .\volume.yaml

# helm install kubeservices $bootDir/02-kubeservices

# helm install start $bootDir/02-start

# kubectl port-forward -n argo-cd service/argo-cd-server 8443:443

Start-Process "http://localhost:8443"

kubectl apply -f .\pull-secret.yaml

. .\portForward.ps1