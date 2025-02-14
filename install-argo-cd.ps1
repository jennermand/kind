# Check if the namespace exists, and create it if it does not
if (-not (kubectl get ns $namespace -o jsonpath='{.metadata.name}' 2>$null)) {
  kubectl create ns $namespace
}

Start-Sleep -Seconds 5  

Write-Host "👌 Installere ArgoCD i $namespace namespace..."

# Define the repositories parameter
$repositories = @(
  @{ repo = "https://github.com/sparnord/jensk-dev"; name = "jensk-dev"; token = $token },
  @{ repo = "https://github.com/sparnord/helm-charts"; name = "aks-chart"; token = $token },
  @{ repo = "https://github.com/sparnord/aks-dev"; name = "aks-dev-values"; token = $token },
  @{ repo = "https://github.com/sparnord/aks-test"; name = "aks-test-values"; token = $token }
)

# Function to create a pull secret from GitHub
function Create-GithubPullSecret {
  param (
    [string]$namespace,
    [string]$githubUsername,
    [string]$githubToken
  )

  $dockerConfigJson = @{
    auths = @{
      "https://index.docker.io/v1/" = @{
        auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${githubUsername}:${githubToken}"))
      }
    }
  } | ConvertTo-Json -Compress

  kubectl create secret generic dockerconfigjson-github-com `
    --from-literal=.dockerconfigjson=$dockerConfigJson `
    --type=kubernetes.io/dockerconfigjson `
    -n $namespace
}

# Construct the --set parameters for each repository
$setParams = @()
for ($i = 0; $i -lt $repositories.Count; $i++) {
  $setParams += "--set"
  $setParams += "argocd.repositories[$i].repo=$($repositories[$i].repo)"
  $setParams += "--set"
  $setParams += "argocd.repositories[$i].name=$($repositories[$i].name)"
  $setParams += "--set"
  $setParams += "argocd.repositories[$i].token=$($repositories[$i].token)"
}

# Run the Helm upgrade command with the --set parameters
helm upgrade -i argo-cd ./0-boot -n $namespace `
  $setParams `
  --set "events.argocd.token=$token" `
  --set "argocd.token=$token" `
  --set "argocd.argocd.token=$token" `
  --set "argocd.argocd.repo=$gitrepo" `
  --set "events.argocd.event=$enableEvents" `
  --set "argocd.argocd.workflows=$enableWorkflows" `
  --set "argocd.argocd.version=$ARGO_WORKFLOWS_VERSION" `
  


  
if ($LASTEXITCODE -ne 0) { 
  Write-Host "Error: Helm install failed." -ForegroundColor Red 
}