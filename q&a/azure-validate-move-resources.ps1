# https://learn.microsoft.com/en-us/powershell/module/az.resources/move-azresource?view=azps-11.5.0
# https://learn.microsoft.com/en-us/rest/api/resources/resources/validate-move-resources?view=rest-resources-2021-04-01&viewFallbackFrom=rest-resources-2022-12-01
Param (
    [Parameter(HelpMessage = "Output file to use.")]
    [string] $OutputFile = "azure-validate-move-resources.csv",

    [Parameter(HelpMessage = "Source Subscription Id", Mandatory = $true)]
    [string] $SourceSubscription,

    [Parameter(HelpMessage = "Target Subscription Id", Mandatory = $true)]
    [string] $TargetSubscription,
    
    [Parameter(HelpMessage = "Target placeholder Resource Group used for validation")]
    [string] $TargetResourceGroupName = "rg-validate-move-resources",
    
    [Parameter(HelpMessage = "Target placeholder Resource Group location")]
    [string] $TargetResourceGroupLocation = "westeurope"
)

$ErrorActionPreference = "Stop"

class MoveSummary {
    [string] $ResourceGroup
    [string] $Code
    [string] $Target
    [string] $Message
    [string] $DetailsCode
    [string] $DetailsMessage
}

$list = New-Object Collections.Generic.List[MoveSummary]

Select-AzSubscription -SubscriptionId $TargetSubscription
New-AzResourceGroup -Name $TargetResourceGroupName -Location $TargetResourceGroupLocation -Force

Select-AzSubscription -SubscriptionId $SourceSubscription
$sourceResourceGroups = Get-AzResourceGroup
$sourceResourceGroups | Format-Table

$resourceGroupName = $sourceResourceGroups[2]
foreach ($resourceGroupName in $sourceResourceGroups) {
    $resourceGroupName.ResourceGroupName

    # Get all resources
    $resources = Get-AzResource -ResourceGroupName $resourceGroupName.ResourceGroupName
    $resources | Format-Table

    $payload = @{
        resources           = $resources.ResourceId
        targetResourceGroup = "/subscriptions/$TargetSubscription/resourceGroups/$TargetResourceGroupName"
    } | ConvertTo-Json

    $parameters = @{
        Method  = "POST"
        Path    = "/subscriptions/$SourceSubscription/resourceGroups/$($resourceGroupName.ResourceGroupName)/validateMoveResources?api-version=2021-04-01"
        Payload = $payload
    }
    $validateMoveResources = Invoke-AzRestMethod @parameters
    $validateMoveResources

    $validateMoveResponse = $null
    while ($true) {
        Start-Sleep -Seconds 15
        
        $validateMoveResources2 = Invoke-AzRestMethod -Path $validateMoveResources.Headers.Location.PathAndQuery
        $validateMoveResources2

        if ($validateMoveResources2.StatusCode -ne 202) {
            $validateMoveResponse = $validateMoveResources2.Content | ConvertFrom-Json
            break
        }
    }
    $validateMoveResponse
    
    if ($null -ne $validateMoveResponse.error) {
        $validateMoveResponse.error | Format-List

        foreach ($details in $validateMoveResponse.error.details) {
            $details | Format-List

            $moveSummary = New-Object MoveSummary
            $moveSummary.ResourceGroup = $resourceGroupName.ResourceGroupName
            $moveSummary.Code = $validateMoveResponse.error.code
            $moveSummary.Target = $validateMoveResponse.error.details.target
            $moveSummary.Message = $validateMoveResponse.error.details.message
            $moveSummary.DetailsCode = $details.code
            $moveSummary.DetailsMessage = $details.message

            $list.Add($moveSummary)
        }
    }
    else {
        # Success
    }
}

$list | Format-Table
$list | Export-Csv $OutputFile -Delimiter ';' -Force

"Scan completed. Updated CSV file: '$OutputFile'."
Start-Process $OutputFile
