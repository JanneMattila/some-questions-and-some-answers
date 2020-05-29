# Scanning resources

## Option: Looping over resources

```powershell
# Note: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-ga-release-faq#what-should-i-do-about-the-performance-counters-in-my-workspace-if-i-install-the-vminsights-solution
$query = @"
let UsageDisk =
InsightsMetrics
| where Namespace=="LogicalDisk" and Name=="FreeSpaceMB"
| summarize min(Val) by Computer
| project Computer, FreeSpaceMB=min_Val;
let UsageCPU =
InsightsMetrics
| where Namespace=="Processor" and Name=="UtilizationPercentage"
| summarize max(Val) by Computer
| project Computer, CPU=max_Val;
UsageDisk
| join (UsageCPU) 
on Computer
| project Computer, FreeSpaceMB, CPU
"@

$subscriptions = [array](Get-AzSubscription)

Write-Host "Found $($subscriptions.length) subscriptions"

for($i = 0; $i -lt $subscriptions.length; $i++) {
  $subscription = $subscriptions[$i]
  Select-AzSubscription -SubscriptionObject $subscription
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

    # Note: To analyze data in grid view use this
    # $result.Results | Out-GridView

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

### Storing scanning results to Table storage

Note: This requires `AzTable` (To install run: `Install-Module AzTable`).

```powershell
$storageResourceGroup = "rg-automation"
$storageName = "yourautomationstoragedemo"
$storage = Get-AzStorageAccount -ResourceGroupName $storageResourceGroup -Name $storageName
$ctx = $storage.Context

$reportTableName = "reports"
New-AzStorageTable -Name $reportTableName -Context $ctx -ErrorAction Continue

$reportTable = (Get-AzStorageTable -Name $reportTableName -Context $ctx).CloudTable

# Take example rows from above result set:
$rows = $result.Results | select -First 10

# Upload all data to same partition per day
$partitionKey = [DateTime]::UtcNow.ToString("yyyy-MM-dd")
$rowNumbering = 1000000
for($r = 0; $r -lt $rows.length; $r++) {
  $row = $rows[$r]
  $rowKey = ($rowNumbering + $r)
  $properties = @{}
  $row.psobject.properties | Foreach { $properties[$_.Name] = $_.Value }
  Add-AzTableRow `
    -Table $reportTable `
    -PartitionKey $partitionKey `
    -RowKey $rowKey `
    -Property $properties
}
```
