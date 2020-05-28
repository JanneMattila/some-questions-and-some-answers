# Scanning resources

## Option: Looping over resources

```powershell
# Note: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-ga-release-faq#what-should-i-do-about-the-performance-counters-in-my-workspace-if-i-install-the-vminsights-solution
$query = @"
InsightsMetrics
| where Namespace in ("Processor", "Memory", "LogicalDisk")
| order  by TimeGenerated desc
| distinct Computer, Namespace, Name, Val
"@

$subscriptions = [array](Get-AzSubscription)

Write-Host "Found $($subscriptions.length) subscriptions"

for($i = 0; $i -lt $subscriptions.length; $i++) {
  $subscription = $subscriptions[$i]
  Write-Host "Processing subscription $($i + 1) / $($subscriptions.length) - $($subscription.name)"
  
  # Example: Look for Log Analytics workspaces
  $workspaces = [array] (Get-AzOperationalInsightsWorkspace)
  Write-Host "Found $($workspaces.length) workspaces"
  for($j = 0; $j -lt $workspaces.length; $j++) {
    $workspace = $workspaces[$j]
    Write-Host "Processing workspace $($j + 1) / $($workspaces.length) - $($workspace.name)"
    $result = Invoke-AzOperationalInsightsQuery `
      -Workspace $workspace `
      -Query $query `
      -Wait (60*10)`
      -Timespan (New-TimeSpan -Hours 24)
    $result.Results | Format-Table

    # For further filtering e.g.
    # $result.Results | `
    #   where {$_.CounterName -eq "Disk Reads/sec" } | `
    #   sort -Property CounterValue -Descending | `
    #   select -First 10 | `
    #   ft Computer,CounterName,CounterValue
  }
}
```

## Option: Resource Graph

Note: This requires `Az.ResourceGraph` (To install run: `Install-Module -Name Az.ResourceGraph`).

```powershell
$result = Search-AzGraph -Query @"
Resources
| where type =~ "microsoft.compute/virtualmachines"
| project name, vmSize=tostring(properties.hardwareProfile.vmSize)
"@
$result | Format-Table
```
