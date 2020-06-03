# Scanning resources

## Option: Looping over resources

```powershell
# Note: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-ga-release-faq#what-should-i-do-about-the-performance-counters-in-my-workspace-if-i-install-the-vminsights-solution
$query = @"
let UsageDisk =
InsightsMetrics
| where Namespace=="LogicalDisk" and Name=="FreeSpaceMB"
| summarize min(Val), min(todouble(parse_json(Tags).["vm.azm.ms/diskSizeMB"])) by Computer
| project Computer, FreeSpaceMB=min_Val, DiskspaceMB=['min_Tags_vm.azm.ms/diskSizeMB'];
let UsageCPU =
InsightsMetrics
| where Namespace=="Processor" and Name=="UtilizationPercentage"
| summarize max(Val), max(todouble(parse_json(Tags).["vm.azm.ms/totalCpus"])) by Computer
| project Computer, CPUUtilization=max_Val, CPUCount=['max_Tags_vm.azm.ms/totalCpus'];
let UsageMemory =
InsightsMetrics
| where Namespace=="Memory" and Name=="AvailableMB"
| summarize min(Val), max(todouble(parse_json(Tags).["vm.azm.ms/memorySizeMB"])) by Computer
| project Computer, MemoryAvailableMB=min_Val, MemorySizeMB=['max_Tags_vm.azm.ms/memorySizeMB'];
UsageDisk
| join (UsageCPU) 
on Computer
| join (UsageMemory)
on Computer
| project Computer, FreeSpaceMB, DiskspaceMB, CPUUtilization, CPUCount, MemoryAvailableMB, MemorySizeMB
"@

$subscriptions = [array](Get-AzSubscription)

Write-Host "Found $($subscriptions.length) subscriptions"

for($i = 0; $i -lt $subscriptions.length; $i++) {
  $subscription = $subscriptions[$i]
  Select-AzSubscription -SubscriptionObject $subscription
  Write-Host "Processing subscription $($i + 1) / $($subscriptions.length) - $($subscription.name)"
  
  # Example: Look for Log Analytics workspaces
  $workspaces = [array](Get-AzOperationalInsightsWorkspace)
  Write-Host "Found $($workspaces.length) workspaces"
  for($j = 0; $j -lt $workspaces.length; $j++) {
    $workspace = $workspaces[$j]
    Write-Host "Processing workspace $($j + 1) / $($workspaces.length) - $($workspace.name)"
    $result = Invoke-AzOperationalInsightsQuery `
      -Workspace $workspace `
      -Query $query `
      -Wait (60*10) `
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

Here's example query to find all the used license types of VMs and SQL databases:

```powershell
$result = Search-AzGraph -Query @"
Resources
| where type == "microsoft.compute/virtualmachines" or type == "microsoft.sql/servers/databases"
| project license = properties.licenseType, type
| summarize Count=count() by tostring(license), type
| sort by Count desc
"@
$result | Format-Table
```

Here's example of the data:

![resource graph licenses query output](https://user-images.githubusercontent.com/2357647/83683000-5b8cae80-a5ed-11ea-8cb9-b93df300ec12.png)

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

# For testing take example rows from above result set:
# $rows = $result.Results | select -First 10
$rows = $result.Results

# Upload all data to same partition per day
$partitionKey = [DateTime]::UtcNow.ToString("yyyy-MM-dd")
foreach($row in $rows){
  $rowKey = $row.Computer
  $properties = @{}
  $row.psobject.properties | Foreach { $properties[$_.Name] = $_.Value }
  Add-AzTableRow `
    -Table $reportTable `
    -PartitionKey $partitionKey `
    -RowKey $rowKey `
    -Property $properties
}
```

Here's example of the collected data:

![collected data in table storage](https://user-images.githubusercontent.com/2357647/83232491-f290db00-a195-11ea-9bcd-fe61dc1e126f.png)
