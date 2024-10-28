Param (
    [Parameter(HelpMessage = "Name of the new Entra ID Group")]
    [string] $GroupName,

    [Parameter(HelpMessage = "Description of the new Entra ID Group")]
    [string] $GroupDescription,

    [Parameter(HelpMessage = "Mail nickname of the new Entra ID Group")]
    [string] $GroupMailNickName,
    
    [Parameter(HelpMessage = "Owner of the group")]
    [string] $ClientId,

    [Parameter(HelpMessage = "Users to add to the new Entra ID Group")]
    [string[]] $MemberUPNs
)

$ErrorActionPreference = "Stop"

$memberIds = New-Object System.Collections.ArrayList

foreach ($memberUPN in $MemberUPNs) {

    $userResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/users/$($memberUPN)?`$select=displayName,id"
    $userResponse

    if ($userResponse.StatusCode -eq 200) {
        $memberIds.Add(($userResponse.Content | ConvertFrom-Json | Select-Object -ExpandProperty id)) | Out-Null
    }
    else {
        Write-Error "User $memberUPN not found"
    }

}

# Create a new group
$groupJson = [ordered]@{
    displayName         = $GroupName
    description         = $GroupDescription
    mailEnabled         = $false
    mailNickname        = $GroupMailNickName
    securityEnabled     = $true
    groupTypes          = @()
    "owners@odata.bind" = [string[]]"https://graph.microsoft.com/v1.0/servicePrincipals(appId='$($ClientId)')"
} | ConvertTo-Json


$groupResponse = Invoke-AzRestMethod `
    -Uri "https://graph.microsoft.com/v1.0/groups" `
    -Method Post -Payload $groupJson
$group = $groupResponse.Content | ConvertFrom-Json

$memberIds | ForEach-Object {
    $id = $_
    $bodyJson = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$id"
    } | ConvertTo-Json

    Invoke-AzRestMethod `
        -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/members/`$ref" `
        -Method POST -Payload $bodyJson
}
