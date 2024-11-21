$jobs = @(    
  Start-Job {kubectl port-forward -n argo-cd service/argo-cd-server 8443:443}
  Start-Job {kubectl port-forward -n kube-system service/quickstart-kb-http 5601}
  Start-Job {kubectl port-forward -n kube-system service/quickstart-es-internal-http 9200}
) 

try {
  Write-Host "Port forwarding jobs running. Press Ctrl+C to stop..."
  $jobs |Wait-Job
}
catch {
  Write-Error "Error occurred: $_"
}
finally {
  $jobs |Remove-Job -Force
}