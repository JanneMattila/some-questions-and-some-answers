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
| join kind=leftouter (ResourceContainers | where type=='microsoft.resources/subscriptions' | project subscriptionName=name, subscriptionId) on subscriptionId
| where type == "microsoft.compute/virtualmachines/extensions" and name has "MicrosoftMonitoringAgent"
| project name, subscriptionName, subscriptionId, location, resourceGroup
```
