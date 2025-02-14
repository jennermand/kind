az aks connection create keyvault `
  --connection kind_cluster_kv_connection `
  --resource-group snb-aks-corp-dev-swc-aks-rg-01 `
  --name snbakscorpdevswccorp01 `
  --target-resource-group snb-aks-corp-dev-swc-shd-rg-01 `
  --vault snbakscorpdevswcshdkv01 `
  --enable-csi `
  --client-type none