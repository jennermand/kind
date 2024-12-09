$jobs = @(    
  # start job if argo namespace is created  
  # if (kubectl get ns argo -o name) {
  #   Start-Job { kubectl -n argo port-forward service/argo-server 2746:2746 }
  # }

  # start job if argo-cd namespace is created
  #Start-Job {kubectl -n argo port-forward service/argo-server 2746:2746}
  # start job if argo-cd namespace is created
  if (kubectl get ns argo-cd -o name) {
    Start-Job { kubectl port-forward -n argo-cd service/argo-cd-server 8443:443 }
    Start-Job { kubectl port-forward -n kube-system service/quickstart-kb-http 5601 }
    Start-Job { kubectl port-forward -n kube-system service/quickstart-es-internal-http 9200 }
  }
) 

