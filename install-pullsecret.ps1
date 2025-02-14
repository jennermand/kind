# Variables
$namespace = "default"
$secretName = "dockerconfigjson-github-com"
$githubToken = $env:GITHUB_TOKEN
$serviceAccountName = "github-pull-secret-sa"
$githubUsername = "e696035_sparnord"
$YOUR_EMAIL = "e696035@sparnord.dk"

Write-Host "Namespace: $namespace"
Write-Host "Secret Name: $secretName"
Write-Host "Service Account Name: $serviceAccountName"
Write-Host "GitHub Username: $githubUsername"
Write-Host "Email: $YOUR_EMAIL"

helm repo add mittwald https://helm.mittwald.de

helm repo update

kubectl apply -f https://raw.githubusercontent.com/mittwald/kubernetes-replicator/master/deploy/rbac.yaml
# Install k8s-replicator
Write-Host "Installing k8s-replicator..."
kubectl apply -f https://raw.githubusercontent.com/mittwald/kubernetes-replicator/master/deploy/deployment.yaml

# Wait for k8s-replicator to be ready
Write-Host "Waiting for k8s-replicator to be ready..."
kubectl rollout status deployment/replicator -n replicator

# Create the pull secret in the default namespace
Write-Host "Creating secret $secretName in namespace $namespace..."
kubectl create secret docker-registry $secretName `
  --docker-server=https://ghcr.io `
  --docker-username=$githubUsername `
  --docker-password=$githubToken `
  --namespace=$namespace

# Annotate the secret for replication
Write-Host "Annotating secret $secretName for replication..."
kubectl annotate secret $secretName replicator.v1.mittwald.de/replicate-to=*

Write-Host "Pull secret $secretName created and annotated for replication to all namespaces."