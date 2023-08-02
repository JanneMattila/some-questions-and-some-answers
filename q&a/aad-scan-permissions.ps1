Param ()

$ErrorActionPreference = "Stop"

class AppData {
    [string] $DisplayName
    [string] $Id
    [string] $AppId
    [datetime] $CreatedDateTime
    [string] $ResourceAppId
    [string] $ResourceAccessId
    [string] $ResourceAccessType
}

$token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token
$bearerToken = ConvertTo-SecureString -String $token -AsPlainText

$url = "https://graph.microsoft.com/v1.0/applications/?`$select=displayName,id,appId,createdDateTime,requiredResourceAccess,deletedDateTime"

$apps = New-Object System.Collections.ArrayList

do {
    $json = Invoke-RestMethod -Uri $url -Authentication Bearer -Token $bearerToken

    foreach ($item in $json.value) {
        foreach ($resource in $item.requiredResourceAccess) {
            foreach ($resourceAccess in $resource.resourceAccess) {
                $resourceAccess
                $appData = [AppData]::new()
                $appData.DisplayName = $item.displayName
                $appData.Id = $item.id
                $appData.AppId = $item.appId
                $appData.CreatedDateTime = $item.createdDateTime
                $appData.ResourceAppId = $resource.resourceAppId
                $appData.ResourceAccessId = $resourceAccess.id
                $appData.ResourceAccessType = $resourceAccess.type
                $apps.Add($appData)
            }
        }
    }

    $url = $json.'@odata.nextLink'
} while ($null -ne $url)

$apps | Format-Table
$apps | Export-CSV "apps.csv" -Force
