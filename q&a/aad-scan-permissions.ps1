Param ()

$ErrorActionPreference = "Stop"

class AppData {
    [string] $DisplayName
    [string] $Id
    [string] $AppId
    [datetime] $CreatedDateTime
    [string] $ResourceAppId
    [string] $ResourceAppName
    [string] $ResourceAccessId
    [string] $ResourceAccessName
    [string] $ResourceAccessValue
    [string] $ResourceAccessType
}

$token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token
$bearerToken = ConvertTo-SecureString -String $token -AsPlainText

$servicePrincipalCache = @{}

function Get-ServicePrincipalUsingCache($AppId, $PermissionId, $PermissionType) {
    $servicePrincipal = $null
    if ($servicePrincipalCache.ContainsKey($AppId)) {
        $servicePrincipal = $servicePrincipalCache[$AppId]
    } 
    else {
        $singleServicePrincipalUrl = "https://graph.microsoft.com/v1.0/servicePrincipals(appId='$AppId')?`$select=displayName,id,appId,appRoles,oauth2PermissionScopes"
        
        try {
            $jsonServicePrincipal = Invoke-RestMethod -Uri $singleServicePrincipalUrl -Authentication Bearer -Token $bearerToken
        }
        catch {
            $jsonServicePrincipal = new-object psobject -property @{
                displayName = "<Unknown>";
                appRoles    = @();
            }
            Write-Warning "Could not fetch service principal using query: $singleServicePrincipalUrl"
        }
        $servicePrincipalCache.Add($AppId, $jsonServicePrincipal)
        $servicePrincipal = $jsonServicePrincipal
    }

    if ($PermissionType -eq "Role") {
        foreach ($role in $servicePrincipal.appRoles) {
            if ($role.id -eq $PermissionId) {
                return new-object psobject -property @{
                    DisplayName = $servicePrincipal.displayName;
                    Permission  = new-object psobject -property @{
                        Id          = $role.id;
                        DisplayName = $role.displayName;
                        Type        = $role.origin;
                        Value       = $role.value;
                    };
                }
            }
        }
    }
    elseif ($PermissionType -eq "Scope") {
        foreach ($scope in $servicePrincipal.oauth2PermissionScopes) {
            if ($scope.id -eq $PermissionId) {
                return new-object psobject -property @{
                    DisplayName = $servicePrincipal.displayName;
                    Permission  = new-object psobject -property @{
                        Id          = $scope.id;
                        DisplayName = $scope.userConsentDisplayName;
                        Type        = $scope.type;
                        Value       = $scope.value;
                    };
                }
            }
        }
    }
    else {
        throw "Unknown permission type: $PermissionType"
    }
}

$url = "https://graph.microsoft.com/v1.0/applications/?`$select=displayName,id,appId,createdDateTime,requiredResourceAccess,deletedDateTime"

$apps = New-Object System.Collections.ArrayList

do {
    $json = Invoke-RestMethod -Uri $url -Authentication Bearer -Token $bearerToken

    foreach ($item in $json.value) {
        foreach ($resource in $item.requiredResourceAccess) {
            foreach ($resourceAccess in $resource.resourceAccess) {
                $spn = Get-ServicePrincipalUsingCache -AppId $resource.resourceAppId -PermissionId $resourceAccess.id -PermissionType $resourceAccess.type
                $appData = [AppData]::new()
                $appData.DisplayName = $item.displayName
                $appData.Id = $item.id
                $appData.AppId = $item.appId
                $appData.CreatedDateTime = $item.createdDateTime
                $appData.ResourceAppId = $resource.resourceAppId
                $appData.ResourceAppName = $spn.DisplayName
                $appData.ResourceAccessId = $resourceAccess.id
                $appData.ResourceAccessName = $spn.Permission.DisplayName
                $appData.ResourceAccessValue = $spn.Permission.Value
                $appData.ResourceAccessType = $spn.Permission.Type
                $apps.Add($appData)
            }
        }
    }

    $url = $json.'@odata.nextLink'
} while ($null -ne $url)

$apps | Format-Table
$apps | Export-CSV "apps.csv" -Force
