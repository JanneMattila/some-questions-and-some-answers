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

class PrivateEndpointData {
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
| where type == "microsoft.network/privateendpoints"
| where isnotnull(properties) and properties contains "manualPrivateLinkServiceConnections"
| where array_length(properties.manualPrivateLinkServiceConnections) > 0
| mv-expand properties.manualPrivateLinkServiceConnections
| extend status = properties_manualPrivateLinkServiceConnections.properties.privateLinkServiceConnectionState.status
| extend description = coalesce(properties_manualPrivateLinkServiceConnections.properties.privateLinkServiceConnectionState.description, "")
| extend privateLinkServiceId = properties_manualPrivateLinkServiceConnections.properties.privateLinkServiceId
| extend privateLinkServiceSubscriptionId = tostring(split(privateLinkServiceId, "/")[2])
| project id, name, location, type, resourceGroup, subscriptionId, tenantId, privateLinkServiceId, privateLinkServiceSubscriptionId, status, description
"@

$batchSize = 1000
$skipResult = 0

$privateEndpoints = New-Object System.Collections.ArrayList

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

        $si2 = Get-SubscriptionInformation -SubscriptionID $row.PrivateLinkServiceSubscriptionId
        $tenant2 = Get-TenantFromSubscription -SubscriptionID $si2.SubscriptionID
        $ti2 = Get-TenantInformation -TenantID $tenant2

        $peData = [PrivateEndpointData]::new()
        $peData.ID = $row.ID
        $peData.Name = $row.Name
        $peData.Type = $row.Type
        $peData.Location = $row.Location
        $peData.ResourceGroup = $row.ResourceGroup
        
        $peData.SubscriptionName = $si1.Name
        $peData.SubscriptionID = $si1.SubscriptionID
        $peData.TenantID = $ti1.TenantID
        $peData.TenantDisplayName = $ti1.DisplayName
        $peData.TenantDomainName = $ti1.DomainName

        $peData.TargetResourceId = $row.PrivateLinkServiceId
        $peData.TargetSubscriptionName = $si2.Name
        $peData.TargetSubscriptionID = $si2.SubscriptionID
        $peData.TargetTenantID = $ti2.TenantID
        $peData.TargetTenantDisplayName = $ti2.DisplayName
        $peData.TargetTenantDomainName = $ti2.DomainName
        
        $peData.Description = $row.Description
        $peData.Status = $row.Status

        if ($ti2.DomainName -eq "MSAzureCloud.onmicrosoft.com") {
            $peData.External = "Managed by Microsoft"
        }
        elseif ($si2.TenantID -eq [Guid]::Empty.Guid) {
            $peData.External = "Yes"
        }
        else {
            $peData.External = "No"
        }

        $privateEndpoints.Add($peData) | Out-Null
    }

    if ($graphResult.data.Count -lt $batchSize) {
        break;
    }
    $skipResult += $skipResult + $batchSize
}

$privateEndpoints | Format-Table
$privateEndpoints | Export-CSV "private-endpoints.csv" -Delimiter ';' -Force

"Found $($privateEndpoints.Count) private endpoints with manual connections"

if ($privateEndpoints.Count -ne 0) {
    Start-Process "private-endpoints.csv"
}
