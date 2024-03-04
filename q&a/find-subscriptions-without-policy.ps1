Param (
    [Parameter(HelpMessage = "CSV file storing state")]
    [string] $CSV = "Subscriptions.csv",
    
    [Parameter(HelpMessage = "Identifier of the policy to validate")]
    [string] $PolicyDefinitionId = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
)

$ErrorActionPreference = "Stop"

class SubscriptionData {
    [string] $SubscriptionId
    [string] $SubscriptionName
    [string] $HasRequiredPolicy
}

$subscriptions = New-Object System.Collections.ArrayList

if (-not (Test-Path $CSV)) {
    "CSV file not found: '$CSV'. Scanning subscriptions from Azure using resource graph."

    $installedModule = Get-Module -Name "Az.ResourceGraph" -ListAvailable
    if ($null -eq $installedModule) {
        Install-Module "Az.ResourceGraph" -Scope CurrentUser
    }
    else {
        # Should be imported automatically but if not then you need this
        # Import-Module "Az.ResourceGraph"
    }
    
    $kqlQuery = @"
ResourceContainers 
| where type=='microsoft.resources/subscriptions'
| project subscriptionId, name
"@

    $kqlQuery

    $batchSize = 50
    $skipResult = 0

    [System.Collections.Generic.List[string]]$searchResult

    while ($true) {

        if ($skipResult -gt 0) {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken -UseTenantScope
        }
        else {
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -UseTenantScope
        }

        $searchResult += $graphResult.data

        if ($graphResult.data.Count -lt $batchSize) {
            break;
        }
        $skipResult += $skipResult + $batchSize
    }

    $searchResult | Format-Table
    "Found $($searchResult.Count) subscriptions."

    foreach ($row in $searchResult) {
        $s = [SubscriptionData]::new()
        $s.SubscriptionName = $row.name
        $s.SubscriptionId = $row.subscriptionId
        $s.HasRequiredPolicy = "Not checked"
        $subscriptions.Add($s) | Out-Null
    }

    $subscriptions | Export-Csv $CSV -Delimiter ';' -Force
    "Opening Excel..."
    ""
    "Validate the data collected."
    "Edit the 'HasRequiredPolicy' column to 'Not checked' for the subscription you want to validate."
    "Edit the 'HasRequiredPolicy' column to 'Ignore' for the subscription to prevent validating it."
    ""
    "Save the file and close Excel and re-run the process."
    Start-Process $CSV
    return
}

$subscriptions = Import-Csv -Path $CSV -Delimiter ';'
"Found $($subscriptions.Count) subscriptions in the CSV file."

$toValidate = $subscriptions | Where-Object -Property HasRequiredPolicy -Value "Not checked" -IEQ

if ($toValidate.Count -eq 0) {
    "No more subscriptions to validate."
    break
}

$index = 1

foreach ($subscription in $toValidate) {
    "$index / $($toValidate.Count): Started subscription validation '$($subscription.SubscriptionName)'"
    $index++

    Select-AzSubscription -SubscriptionId $subscription.SubscriptionId | Out-Null
    $assignment = Get-AzPolicyAssignment `
        -Scope "/subscriptions/$($subscription.SubscriptionId)" `
        -PolicyDefinitionId $PolicyDefinitionId
    $subscription.HasRequiredPolicy = $null -ne $assignment ? "Yes" : "No"

    "$($subscription.SubscriptionName) validation result: $($subscription.HasRequiredPolicy)"
}

$subscriptions | Export-Csv $CSV -Delimiter ';' -Force

"Scan completed. Updated CSV file: '$CSV'."
Start-Process $CSV
