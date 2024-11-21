# installing charts
Everything must be run in sequence

# prerequisists

## 1 install argo-cd
```
helm dependency update 0-boot
helm install argo-cd .\0-boot
```

*tips*
Getting password for argocd is done with: 


```
kubectl get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 1 bootstrap argo-cd