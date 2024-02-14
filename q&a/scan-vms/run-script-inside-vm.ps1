Param (
    [Parameter(HelpMessage = "CSV file storing state of the scanning")]
    [string] $CSV = "VirtualMachines.csv",

    [Parameter(HelpMessage = "Number of VMs to scan at once")]
    [int] $NumberOfVMsToScan = 1
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

$payload = @{
    commandId = "RunPowerShellScript"
    script    = Get-Content "vm-script.ps1"
} | ConvertTo-Json

$virtualMachines = New-Object System.Collections.ArrayList

if (-not (Test-Path $CSV)) {
    "CSV file not found: '$CSV'. Scanning virtual machines using resource graph."

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

    "Virtual machines exported to $CSV!"
    "Opening Excel..."
    ""
    "Validate the data collected."
    "Edit the 'ToScan' column to 'Yes' for the virtual machines you want to scan."
    "Edit the 'ToScan' column to 'No' for preventing scan of that virtual machine."
    ""
    "Save the file and close Excel."
    Start-Process $CSV
    pause
}

while ($true) {
    $virtualMachines = Import-Csv -Path $CSV -Delimiter ';'
    "Found $($virtualMachines.Count) virtual machines in the CSV file."

    $toScan = $virtualMachines | Where-Object -Property ToScan -Value "Yes" -IEQ | Select-Object -First $NumberOfVMsToScan

    if ($toScan.Count -eq 0) {
        "No more virtual machines to scan."
        break
    }

    "Scanning $($toScan.Count) virtual machines (batch size: $NumberOfVMsToScan)."
    $toScan | Format-Table

    $index = 1
    $jobs = @{}

    foreach ($vm in $toScan) {
        "$index / $($toScan.Count): Started scanning '$($vm.Name)' in '$($vm.ResourceGroup)'"
        $index++
        $job = Invoke-AzRestMethod -Path "$($vm.ResourceId)/runCommand?api-version=2023-09-01" `
            -Method POST `
            -Payload $payload `
            -AsJob
        $jobs.Add($vm.ResourceId, $job)
    }

    "Waiting for all $($jobs.Count) deployment jobs to complete."

    $jobs.Values | Get-Job | Wait-Job
    "All $($jobs.Count) deployment jobs have completed."

    foreach ($job in $jobs.Keys) {
        $jobRun = $jobs[$job]
        $vm = $virtualMachines | Where-Object -Property ResourceId -Value $job -EQ
        $vm.ToScan = "No"
        $vm.IsScanned = "No"
        try {
            $jobOutput = $jobRun | Receive-Job -ErrorAction Stop

            if ($jobOutput.StatusCode -ne 202) {
                "Resource $job scanned failed: $($jobOutput.StatusCode)"
                $errorJson = $jobOutput.Content | ConvertFrom-Json
                $vm.ScanError = $errorJson.error.message
            }
            else {
                while ($true) {
                    $result = Invoke-AzRestMethod -Uri $jobOutput.Headers.Location.AbsoluteUri
                    if ($result.StatusCode -ne 200) {
                        "Waiting for the job to complete..."
                        Start-Sleep -Seconds 5
                    }
                    else {
                        break
                    }
                }

                $jobOutput = $result.Content | ConvertFrom-Json
                $outputResult = $jobOutput.value[0].message
                "Resource $job scanned successfully: $outputResult"
                $resultValues = $outputResult.Split(",")
                if ($resultValues.Count -eq 4) {
                    $vm.IsScanned = "Yes"
                    $vm.ScanResult1 = $resultValues[0]
                    $vm.ScanResult2 = $resultValues[1]
                    $vm.ScanResult3 = $resultValues[2]
                    $vm.ScanResult4 = $resultValues[3]
                    $vm.ScanError = ""
                }
                else {
                    $vm.ScanError = "Invalid output from the job: $outputResult"
                }
            }
        }
        catch {
            $message = $_.Exception.Message
            $vm.ScanError = $message
        }

        $virtualMachines | Export-Csv $CSV -Delimiter ';' -Force
    }

    # Quick exit to prevent accidentally running too many VMs at once
    break
}


"Scanning completed. Updated CSV file: '$CSV'."
Start-Process $CSV
# If you need to clean up jobs, here's example command:
# Get-Job | Remove-Job -Force