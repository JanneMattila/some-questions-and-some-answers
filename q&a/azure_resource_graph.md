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
