$identityName = "id-entra-id-automation-identity"
$resourceGroupName = "rg-entra-id-automation"
$location = "swedencentral"

# Create a new resource group
New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location

# Create a new managed identity
$identity = New-AzUserAssignedIdentity `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $identityName

# Get Microsoft Graph permissions
$microsoftGraphApp = Get-AzADServicePrincipal -ApplicationId "00000003-0000-0000-c000-000000000000"
$graphPermissions = $microsoftGraphApp | Select-Object -ExpandProperty AppRole

$appRoleJson = [ordered]@{
    principalId = $identity.PrincipalId
    resourceId  = $microsoftGraphApp.Id
    appRoleId   = ($graphPermissions `
        | Where-Object { $_.Value -eq "Group.Create" } `
        | Select-Object -ExpandProperty Id)
} | ConvertTo-Json
$appRoleJson

$response = Invoke-AzRestMethod `
    -Method Post `
    -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($microsoftGraphApp.Id)/appRoleAssignedTo" `
    -Payload $appRoleJson
$response

New-AzADServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $identity.PrincipalId `
    -ResourceId $microsoftGraphApp.Id `
    -AppRoleId ($graphPermissions `
    | Where-Object { $_.Value -eq "Group.Create" } `
    | Select-Object -ExpandProperty Id)

$appRoleJson = [ordered]@{
    principalId = $identity.PrincipalId
    resourceId  = $microsoftGraphApp.Id
    appRoleId   = ($graphPermissions `
        | Where-Object { $_.Value -eq "User.ReadBasic.All" } `
        | Select-Object -ExpandProperty Id)
} | ConvertTo-Json
$appRoleJson

$response = Invoke-AzRestMethod `
    -Method Post `
    -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($microsoftGraphApp.Id)/appRoleAssignedTo" `
    -Payload $appRoleJson
$response
