# Azure Resource Graph

## Unmanaged disks deprecation

[Migrate your Azure unmanaged disks by September 30, 2025](https://learn.microsoft.com/en-us/azure/virtual-machines/unmanaged-disks-deprecation)

Here are example resource graph queries to find all the unmanaged disks:

```kusto
// Search unmanaged OS disks
resources
| where type == "microsoft.compute/virtualmachines"
| where isnotnull(properties.storageProfile.osDisk.vhd)

// Search unmanaged data disks
resources
| where type == "microsoft.compute/virtualmachines"
| mv-expand dataDisk = properties.storageProfile.dataDisks
| where isnotnull(dataDisk.vhd)
```

## Classic Storage Account deprecation

[Migrate your classic storage accounts to Azure Resource Manager by August 31, 2024](https://learn.microsoft.com/en-us/azure/storage/common/classic-account-migration-overview)

```kusto
resources
| where type == "microsoft.classicstorage/storageaccounts"
```

## Microsoft Monitoring Agent

[We're retiring the Log Analytics agent in Azure Monitor on 31 August 2024](https://azure.microsoft.com/en-us/updates/were-retiring-the-log-analytics-agent-in-azure-monitor-on-31-august-2024/)

```kusto
resources
| join kind=leftouter (ResourceContainers | where type=='microsoft.resources/subscriptions' | project subscriptionName=name, subscriptionId) on subscriptionId
| where type == "microsoft.compute/virtualmachines/extensions" and name has "MicrosoftMonitoringAgent"
| project VMName=split(id, "/")[-3], name, subscriptionName, subscriptionId, location, resourceGroup
```

## Quota and usage

```kusto
QuotaResources 
| where type =~ 'microsoft.compute/locations/usages' 
| where isnotempty(properties) 
| mv-expand propertyJson = properties.value 
| extend usage = propertyJson.currentValue, 
         quota = propertyJson.['limit'], 
         quotaName = tostring(propertyJson.['name'].value) 
| extend usagePercent = toint(usage) * 100 / toint(quota) 
| project-away properties
| where usagePercent > 80
| join kind=leftouter (ResourceContainers | where type=='microsoft.resources/subscriptions' | project subscriptionName=name, subscriptionId) on subscriptionId
| project subscriptionId, subscriptionName, location, usage, quota, quotaName, usagePercent
```

Example output:

| subscriptionId                       | subscriptionName            | location      | usage | quota | quotaName        | usagePercent |
| :----------------------------------- | --------------------------- | ------------- | ----- | ----- | ---------------- | ------------ |
| 84d7a8e8-aeee-46fb-a1e9-56c4ec4e4857 | workload2-production-online | swedencentral | 83    | 100   | standardBSFamily | 83           |
| 84d7a8e8-aeee-46fb-a1e9-56c4ec4e4857 | workload2-production-online | swedencentral | 83    | 100   | cores            | 83           |
| 12acde3e-956c-4529-a9ed-7af3713aee0b | workload3-development-corp  | swedencentral | 84    | 100   | standardBSFamily | 83           |
| 12acde3e-956c-4529-a9ed-7af3713aee0b | workload3-development-corp  | swedencentral | 84    | 100   | cores            | 83           |
