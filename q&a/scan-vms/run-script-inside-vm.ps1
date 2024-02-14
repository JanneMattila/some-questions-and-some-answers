Param (
    [Parameter(HelpMessage = "CSV file storing state of the scanning")]
    [string] $CSV = "VirtualMachines.csv",

    [Parameter(HelpMessage = "Number of VMs to scan at once")]
    [int] $NumberOfVMsToScan = 5
)

$ErrorActionPreference = "Stop"

class VirtualMachineData {
    [string] $ResourceId
    [string] $SubscriptionId
    [string] $SubscriptionName
    [string] $ResourceGroup
    [string] $Name
    [string] $Publisher
    [string] $Offer
    [string] $SKU
    [string] $Version
    [string] $ExactVersion
    [string] $ToScan
    [string] $IsScanned
    [string] $ScanResult1
    [string] $ScanResult2
    [string] $ScanResult3
    [string] $ScanResult4
    [string] $ScanError
}

$virtualMachines = New-Object System.Collections.ArrayList

if (-not (Test-Path $CSV)) {
    Write-Host "CSV file not found: '$CSV'. Scanning virtual machines using resource graph."

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
| where properties['storageProfile']['imageReference']['publisher'] startswith "Microsoft"
| project VMResourceId = id, subscriptionName, subscriptionId, resourceGroup, name, publisher = properties['storageProfile']['imageReference']['publisher'], version = properties['storageProfile']['imageReference']['version'], sku = properties['storageProfile']['imageReference']['sku'], offer = properties['storageProfile']['imageReference']['offer'], exactVersion = properties['storageProfile']['imageReference']['exactVersion'], powerState = properties['extended']['instanceView']['powerState']['code']
"@

    $kqlQuery

    $batchSize = 50
    $skipResult = 0
    $kqlResult = @()

    [System.Collections.Generic.List[string]]$kqlResult

    while ($true) {

        if ($skipResult -gt 0) {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken
        }
        else {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize
        }

        $kqlResult += $graphResult.data

        if ($graphResult.data.Count -lt $batchSize) {
            break;
        }
        $skipResult += $skipResult + $batchSize
    }

    $kqlResult | Format-Table
    "Found $($kqlResult.Count) virtual machines."

    foreach ($row in $kqlResult) {
        $vm = [VirtualMachineData]::new()
        $vm.ResourceId = $row.VMResourceId
        $vm.SubscriptionName = $row.subscriptionName
        $vm.SubscriptionId = $row.subscriptionId
        $vm.ResourceGroup = $row.resourceGroup
        $vm.Name = $row.name
        $vm.Publisher = $row.publisher
        $vm.Offer = $row.offer
        $vm.SKU = $row.sku
        $vm.Version = $row.version
        $vm.ExactVersion = $row.exactVersion
        $vm.ToScan = "Yes"
        $vm.IsScanned = "No"
        $virtualMachines.Add($vm) | Out-Null
    }

    $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force
}

$virtualMachines = Import-Csv -Path $CSV -Delimiter ';'
"Found $($virtualMachines.Count) virtual machines in the CSV file."

$toScan = $virtualMachines | Where-Object -Property ToScan -Value "Yes" -IEQ | Select-Object -First $NumberOfVMsToScan

"Scanning $($toScan.Count) virtual machines (batch size: $NumberOfVMsToScan)."
$toScan | Format-Table

$index = 1
$jobs = @{}

foreach ($vm in $toScan) {
    "$index / $($toScan.Count): Started scanning '$($vm.Name)' in '$($vm.ResourceGroup)'"
    $index++
    $job = Invoke-AzVMRunCommand `
        -ResourceId $vm.ResourceId `
        -CommandId 'RunPowerShellScript' `
        -ScriptPath 'vm-script.ps1' `
        -AsJob
    $jobs.Add($vm.ResourceId, $job)
}

Write-Host "Waiting for all $($jobs.Count) deployment jobs to complete."

$jobs.Values | Get-Job | Wait-Job
Write-Host "All $($jobs.Count) deployment jobs have completed."

foreach ($job in $jobs.Keys) {
    $jobOutput = $jobs[$job] | Receive-Job
    $jobOutput

    if ($jobOutput.Status -ne "Succeeded") {
        Write-Host "Resource $job scanned failed: $($jobOutput.Status)"
        $vm = $virtualMachines | Where-Object -Property ResourceId -Value $job -EQ
        $vm.ToScan = "No"
        $vm.IsScanned = $jobOutput.Status
        $vm.ScanError = $jobOutput.Error.Message
    }
    else {
        $outputResult = $jobOutput.Value[0].Message
        Write-Host "Resource $job scanned successfully: $outputResult"
        $resultValues = $outputResult.Split(",")
        if ($resultValues.Count -eq 4) {
            $vm = $virtualMachines | Where-Object -Property ResourceId -Value $job -EQ
            $vm.ToScan = "No"
            $vm.IsScanned = "Yes"
            $vm.ScanResult1 = $resultValues[0]
            $vm.ScanResult2 = $resultValues[1]
            $vm.ScanResult3 = $resultValues[2]
            $vm.ScanResult4 = $resultValues[3]
            $vm.ScanError = ""
        }
        else {
            Write-Host "Invalid output from the job: $outputResult"
        }
    }

    $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force
}

"Scanning completed. Updated CSV file: '$CSV'."
# If you need to clean up jobs, here's example command:
# Get-Job | Remove-Job -Force