$ErrorActionPreference = "Stop"

class SubscriptionInformation {
    [string] $SubscriptionID
    [string] $Name
    [string] $TenantID
}

class TenantInformation {
    [string] $TenantID
    [string] $DisplayName
    [string] $DomainName
}

class PrivateEndpointConnectionData {
    [string] $ID
    [string] $Name
    [string] $Type
    [string] $Location
    [string] $ResourceGroup
    [string] $SubscriptionName
    [string] $SubscriptionID
    [string] $TenantID
    [string] $TenantDisplayName
    [string] $TenantDomainName
    [string] $TargetResourceId
    [string] $TargetSubscriptionName
    [string] $TargetSubscriptionID
    [string] $TargetTenantID
    [string] $TargetTenantDisplayName
    [string] $TargetTenantDomainName
    [string] $Description
    [string] $Status
    [string] $External
}

$installedModule = Get-Module -Name "Az.ResourceGraph" -ListAvailable
if ($null -eq $installedModule) {
    Install-Module "Az.ResourceGraph" -Scope CurrentUser
}
else {
    Import-Module "Az.ResourceGraph"
}

$kqlQuery = @"
resourcecontainers | where type == 'microsoft.resources/subscriptions'
| project  subscriptionId, name, tenantId
"@

$batchSize = 1000
$skipResult = 0

$subscriptions = @{}

while ($true) {

    if ($skipResult -gt 0) {
        $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken -UseTenantScope
    }
    else {
        $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -UseTenantScope
    }

    foreach ($row in $graphResult.data) {
        $s = [SubscriptionInformation]::new()
        $s.SubscriptionID = $row.subscriptionId
        $s.Name = $row.name
        $s.TenantID = $row.tenantId

        $subscriptions.Add($s.SubscriptionID, $s) | Out-Null
    }

    if ($graphResult.data.Count -lt $batchSize) {
        break;
    }
    $skipResult += $skipResult + $batchSize
}

"Found $($subscriptions.Count) subscriptions"

function Get-SubscriptionInformation($SubscriptionID) {
    if ($subscriptions.ContainsKey($SubscriptionID)) {
        return $subscriptions[$SubscriptionID]
    } 

    Write-Warning "Using fallback subscription information for '$SubscriptionID'"
    $s = [SubscriptionInformation]::new()
    $s.SubscriptionID = $SubscriptionID
    $s.Name = "<unknown>"
    $s.TenantID = [Guid]::Empty.Guid
    return $s
}

$tenantCache = @{}
$subscriptionToTenantCache = @{}

function Get-TenantInformation($TenantID) {
    $domain = $null
    if ($tenantCache.ContainsKey($TenantID)) {
        $domain = $tenantCache[$TenantID]
    } 
    else {
        try {
            $tenantResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/tenantRelationships/findTenantInformationByTenantId(tenantId='$TenantID')"
            $tenantInformation = ($tenantResponse.Content | ConvertFrom-Json)

            $ti = [TenantInformation]::new()
            $ti.TenantID = $TenantID
            $ti.DisplayName = $tenantInformation.displayName
            $ti.DomainName = $tenantInformation.defaultDomainName

            $domain = $ti
        }
        catch {
            Write-Warning "Failed to get domain information for '$TenantID'"
        }

        if ([string]::IsNullOrEmpty($domain)) {
            Write-Warning "Using fallback domain information for '$TenantID'"
            $ti = [TenantInformation]::new()
            $ti.TenantID = $TenantID
            $ti.DisplayName = "<unknown>"
            $ti.DomainName = "<unknown>"

            $domain = $ti
        }

        $tenantCache.Add($TenantID, $domain) | Out-Null
    }

    return $domain
}

function Get-TenantFromSubscription($SubscriptionID) {
    $tenant = $null
    if ($subscriptionToTenantCache.ContainsKey($SubscriptionID)) {
        $tenant = $subscriptionToTenantCache[$SubscriptionID]
    }
    elseif ($subscriptions.ContainsKey($SubscriptionID)) {
        $tenant = $subscriptions[$SubscriptionID].TenantID
        $subscriptionToTenantCache.Add($SubscriptionID, $tenant) | Out-Null
    }
    else {
        try {

            $subscriptionResponse = Invoke-AzRestMethod -Path "/subscriptions/$($SubscriptionID)?api-version=2022-12-01"
            $startIndex = $subscriptionResponse.Headers.WwwAuthenticate.Parameter.IndexOf("https://login.windows.net/")
            $tenantID = $subscriptionResponse.Headers.WwwAuthenticate.Parameter.Substring($startIndex + "https://login.windows.net/".Length, 36)

            $tenant = $tenantID
        }
        catch {
            Write-Warning "Failed to get tenant from subscription '$SubscriptionID'"
        }

        if ([string]::IsNullOrEmpty($tenant)) {
            Write-Warning "Using fallback tenant information for '$SubscriptionID'"

            $tenant = [Guid]::Empty.Guid
        }

        $subscriptionToTenantCache.Add($SubscriptionID, $tenant) | Out-Null
    }

    return $tenant
}

$kqlQuery = @"
resources
| where isnotnull(properties) and properties contains "privateEndpointConnections"
| where array_length(properties.privateEndpointConnections) > 0
| mv-expand properties.privateEndpointConnections
| extend status = properties_privateEndpointConnections.properties.privateLinkServiceConnectionState.status
| extend description = coalesce(properties_privateEndpointConnections.properties.privateLinkServiceConnectionState.description, "")
| extend privateEndpointResourceId = properties_privateEndpointConnections.properties.privateEndpoint.id
| extend privateEndpointSubscriptionId = tostring(split(privateEndpointResourceId, "/")[2])
| project id, name, location, type, resourceGroup, subscriptionId, tenantId, privateEndpointResourceId, privateEndpointSubscriptionId, status, description
"@

$batchSize = 1000
$skipResult = 0

$privateEndpointConnections = New-Object System.Collections.ArrayList

while ($true) {

    if ($skipResult -gt 0) {
        $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken -UseTenantScope
    }
    else {
        $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -UseTenantScope
    }

    foreach ($row in $graphResult.data) {

        $si1 = Get-SubscriptionInformation -SubscriptionID $row.SubscriptionID
        $ti1 = Get-TenantInformation -TenantID $row.TenantID

        $si2 = Get-SubscriptionInformation -SubscriptionID $row.PrivateEndpointSubscriptionID
        $tenant2 = Get-TenantFromSubscription -SubscriptionID $si2.SubscriptionID
        $ti2 = Get-TenantInformation -TenantID $tenant2

        $pecData = [PrivateEndpointConnectionData]::new()
        $pecData.ID = $row.ID
        $pecData.Name = $row.Name
        $pecData.Type = $row.Type
        $pecData.Location = $row.Location
        $pecData.ResourceGroup = $row.ResourceGroup
        
        $pecData.SubscriptionName = $si1.Name
        $pecData.SubscriptionID = $si1.SubscriptionID
        $pecData.TenantID = $ti1.TenantID
        $pecData.TenantDisplayName = $ti1.DisplayName
        $pecData.TenantDomainName = $ti1.DomainName

        $pecData.TargetResourceId = $row.PrivateEndpointResourceID
        $pecData.TargetSubscriptionName = $si2.Name
        $pecData.TargetSubscriptionID = $si2.SubscriptionID
        $pecData.TargetTenantID = $ti2.TenantID
        $pecData.TargetTenantDisplayName = $ti2.DisplayName
        $pecData.TargetTenantDomainName = $ti2.DomainName
        
        $pecData.Description = $row.Description
        $pecData.Status = $row.Status

        if ($ti2.DomainName -eq "MSAzureCloud.onmicrosoft.com") {
            $pecData.External = "Managed by Microsoft"
        }
        elseif ($si2.TenantID -eq [Guid]::Empty.Guid) {
            $pecData.External = "Yes"
        }
        else {
            $pecData.External = "No"
        }

        $privateEndpointConnections.Add($pecData) | Out-Null
    }

    if ($graphResult.data.Count -lt $batchSize) {
        break;
    }
    $skipResult += $skipResult + $batchSize
}

$privateEndpointConnections | Format-Table
$privateEndpointConnections | Export-CSV "private-endpoint-connections.csv" -Delimiter ';' -Force

"Found $($privateEndpointConnections.Count) private endpoint connections"

if ($privateEndpointConnections.Count -ne 0) {
    Start-Process "private-endpoint-connections.csv"
}
