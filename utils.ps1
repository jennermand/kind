# FILE: utils.ps1

function Wait-ForPods {
  param (
    [string]$Namespace,
    [string]$LabelSelector,
    [int]$TimeoutSeconds = 300
  )

  $startTime = Get-Date
  $spinner = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
  $i = 0

  Write-Host "`n"
  while ((Get-Date) -le $startTime.AddSeconds($TimeoutSeconds)) {
    $status = kubectl get pods -n $Namespace -l $LabelSelector --no-headers
    $totalPods = ($status).Count
    $runningPods = ($status | Select-String -Pattern "Running").Count

    Write-Host "`r$($spinner[$i]) Waiting for pods in namespace '$Namespace' with label '$LabelSelector' ... ($runningPods/$totalPods) " -NoNewline
    $i = ($i + 1) % $spinner.Length

    if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
      Write-Host "`r✓ All pods are running in namespace '$Namespace' with label '$LabelSelector'!     " -ForegroundColor Green
      return $true
    }

    Start-Sleep -Seconds 5
  }

  Write-Host "`r✗ Timeout waiting for pods in namespace '$Namespace' with label '$LabelSelector'!     " -ForegroundColor Red
  return $false
}

function Show-Variables {
  param()
  
  Write-Host "`n=== Current Variables ===" -ForegroundColor Cyan
  
  $variables = @(
    @{Name = "Namespace"; Value = $namespace; Type = $namespace.GetType().Name }
    @{Name = "Token"; Value = "***${token.Substring(0,4)}..."; Type = $token.GetType().Name }
    @{Name = "Git Repo"; Value = $gitrepo; Type = $gitrepo.GetType().Name }
    @{Name = "Argo Version"; Value = $ARGO_WORKFLOWS_VERSION; Type = $ARGO_WORKFLOWS_VERSION.GetType().Name }
    @{Name = "Workflows Enabled"; Value = $enableWorkflows; Type = $enableWorkflows.GetType().Name }
    @{Name = "Events Enabled"; Value = $enableEvents; Type = $enableEvents.GetType().Name }
  )

  $nameWidth = ($variables | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
  $typeWidth = ($variables | ForEach-Object { $_.Type.Length } | Measure-Object -Maximum).Maximum

  foreach ($var in $variables) {
    $name = $var.Name.PadRight($nameWidth)
    $type = $var.Type.PadRight($typeWidth)
    Write-Host ("{0} [{1}]: " -f $name, $type) -NoNewline -ForegroundColor Yellow
    Write-Host $var.Value -ForegroundColor Green
  }
  Write-Host "=====================`n" -ForegroundColor Cyan
}