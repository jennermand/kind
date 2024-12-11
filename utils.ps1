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