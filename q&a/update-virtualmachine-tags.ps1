Param (
    [Parameter(HelpMessage = "CSV file storing state")]
    [string] $CSV = "VirtualMachines.csv",

    [Parameter(HelpMessage = "Number of VMs to update at once")]
    [int] $NumberOfVMsToUpdate = 1,
    
    [Parameter(HelpMessage = "Tag to add to Defender for each VM")]
    [string] $TagToAdd = "janne"
)

$ErrorActionPreference = "Stop"

class VirtualMachineData {
    [string] $ResourceId
    [string] $SubscriptionId
    [string] $SubscriptionName
    [string] $ResourceGroup
    [string] $Name
    [string] $AzureVMId
    [string] $DefenderDeviceId
    [string] $LastSeen
    [string] $UpdateTag
    [string] $TagValue
    [string] $MachineTags
}

$virtualMachines = New-Object System.Collections.ArrayList

if (-not (Test-Path $CSV)) {
    "CSV file not found: '$CSV'. Scanning virtual machines from Azure using resource graph."

    $installedModule = Get-Module -Name "Az.ResourceGraph" -ListAvailable
    if ($null -eq $installedModule) {
        Install-Module "Az.ResourceGraph" -Scope CurrentUser
    }
    else {
        # Should be imported automatically but if not then you need this
        # Import-Module "Az.ResourceGraph"
    }
    
    $kqlQuery = @"
resources
| join kind=leftouter (ResourceContainers | where
type=='microsoft.resources/subscriptions' | project subscriptionName = name,subscriptionId) on
subscriptionId 
| where type == "microsoft.compute/virtualmachines"
| project VMResourceId = id, subscriptionName, subscriptionId, resourceGroup, name, vmId = properties.vmId
"@

    $kqlQuery

    $batchSize = 50
    $skipResult = 0

    [System.Collections.Generic.List[string]]$searchResult

    while ($true) {

        if ($skipResult -gt 0) {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken
        }
        else {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize
        }

        $searchResult += $graphResult.data

        if ($graphResult.data.Count -lt $batchSize) {
            break;
        }
        $skipResult += $skipResult + $batchSize
    }

    $searchResult | Format-Table
    "Found $($searchResult.Count) virtual machines from Azure."

    foreach ($row in $searchResult) {
        $vm = [VirtualMachineData]::new()
        $vm.ResourceId = $row.VMResourceId
        $vm.SubscriptionName = $row.subscriptionName
        $vm.SubscriptionId = $row.subscriptionId
        $vm.ResourceGroup = $row.resourceGroup
        $vm.Name = $row.name
        $vm.AzureVMId = $row.vmId
        $vm.DefenderDeviceId = ""
        $vm.LastSeen = ""
        $vm.UpdateTag = "Yes"
        $vm.TagValue = ""
        $vm.MachineTags = ""
        $virtualMachines.Add($vm) | Out-Null
    }

    $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force

    "Scanning virtual machines from Defender"
    $token = (Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com").Token
    $bearerToken = ConvertTo-SecureString -String $token -AsPlainText
    
    $batchSize = 10000
    $skipResult = 0

    while ($true) {
        $url = "https://api.securitycenter.microsoft.com/api/machines?`$skip=$skipResult&`$top=$batchSize"

        $vms = Invoke-RestMethod -Method Get -Uri $url -Authentication Bearer -Token $bearerToken

        $vms.value | Format-Table
        foreach ($row in $vms.value) {
            if ($null -eq $row.vmMetadata) {
                "Skipping virtual machine without metadata: $($row.id)"
                continue
            }

            if ($row.vmMetadata.cloudProvider -ne "Azure") {
                "Skipping non-Azure virtual machine: $($row.id)"
                continue
            }

            $existingRow = $virtualMachines | Where-Object -Property ResourceId -Value $row.vmMetadata.resourceId -IEQ | Select-Object -First 1
            
            if ($null -ne $existingRow) {
                $existingRow.DefenderDeviceId = $row.id
                $existingRow.LastSeen = $row.lastSeen.ToString("yyyy-MM-dd HH:mm:ss")
                $vm.MachineTags = $row.machineTags

                if ($null -ne $row.machineTags) {
                    if ($row.machineTags -like "*$TagToAdd*") {
                        $existingRow.UpdateTag = "No"
                        $existingRow.TagValue = $TagToAdd
                    }
                }
            }
            else {
                $vm = [VirtualMachineData]::new()
                $vm.ResourceId = $row.vmMetadata.resourceId
                $vm.SubscriptionName = ""
                $vm.SubscriptionId = ""
                $vm.ResourceGroup = ""
                $vm.Name = $row.computerDnsName
                $vm.AzureVMId = $row.vmMetadata.vmId
                $vm.DefenderDeviceId = $row.id
                $vm.LastSeen = $row.lastSeen.ToString("yyyy-MM-dd HH:mm:ss")
                $vm.UpdateTag = "No"
                $vm.TagValue = ""
                $vm.MachineTags = $row.machineTags
                $virtualMachines.Add($vm) | Out-Null
            }
        }

        if ($vms.value.Count -lt $batchSize) {
            break;
        }
        $skipResult += $skipResult + $batchSize
    }

    $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force

    "Virtual machines exported to $CSV!"
    "Opening Excel..."
    ""
    "Validate the data collected."
    "Edit the 'UpdateTag' column to 'Yes' for the virtual machines you want to update tags."
    "Edit the 'UpdateTag' column to 'No' for preventing update of that virtual machine."
    ""
    "Save the file and close Excel and re-run the process."
    Start-Process $CSV
    return
}

while ($true) {
    $virtualMachines = Import-Csv -Path $CSV -Delimiter ';'
    "Found $($virtualMachines.Count) virtual machines in the CSV file."

    $toUpdate = $virtualMachines | Where-Object -Property UpdateTag -Value "Yes" -IEQ | Select-Object -First $NumberOfVMsToUpdate

    if ($toUpdate.Count -eq 0) {
        "No more virtual machines to update."
        break
    }

    $token = (Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com").Token
    $bearerToken = ConvertTo-SecureString -String $token -AsPlainText
    
    $index = 1

    foreach ($vm in $toUpdate) {
        "$index / $($toUpdate.Count): Started tag update '$($vm.Name)' in '$($vm.ResourceGroup)'"
        $index++

        $vmId = $vm.DefenderDeviceId;
        $url = "https://api.securitycenter.microsoft.com/api/machines/$vmId/tags"

        $body = ConvertTo-Json -Depth 20 -InputObject @{
            "Action" = "Add";
            "Value"  = $TagToAdd;
        }

        try {
            $response = Invoke-RestMethod -Method Post -Uri $url -Body $body -ContentType "application/json" -Authentication Bearer -Token $bearerToken

            $vm.UpdateTag = "No"
            $vm.TagValue = $TagToAdd
            $vm.MachineTags += " " + $TagToAdd
        }
        catch {
        }
    }

    $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force

    # Quick exit to prevent accidentally running too many VMs at once
    break
}

"Tag update completed. Updated CSV file: '$CSV'."
Start-Process $CSV
