Param (
    [Parameter(HelpMessage = "Resource group to scan for roles.")]
    [string] $ResourceGroup
)

$ErrorActionPreference = "Stop"

class UserAssignedRole {
    [string] $DisplayName
    [string] $UserPrincipalName
    [string] $Role
}

$context = Get-AzContext
$tenant = $context.Tenant.TenantId

Write-Host "Preparing Microsoft.Graph module..."

$installedModule = Get-Module -Name "Microsoft.Graph" -ListAvailable
if ($null -eq $installedModule) {
    Install-Module Microsoft.Graph -Scope CurrentUser
}
else {
    # Should be imported automatically but if not then you need this
    # Import-Module Microsoft.Graph
}

Write-Host "Connecting to Microsoft Graph..."
$accessToken = Get-AzAccessToken -ResourceTypeName MSGraph -TenantId $tenant
Connect-MgGraph -AccessToken $accessToken.Token | Out-Host

$list = New-Object Collections.Generic.List[UserAssignedRole]
$roleAssignments = Get-AzRoleAssignment -ResourceGroupName $ResourceGroup

foreach ($roleAssignment in $roleAssignments) {
    if ($roleAssignment.ObjectType -eq "User") {
        $user = Get-MgUser -UserId $roleAssignment.ObjectId
        $uar = New-Object UserAssignedRole
        $uar.DisplayName = $user.DisplayName
        $uar.UserPrincipalName = $user.UserPrincipalName
        $uar.Role = $roleAssignment.RoleDefinitionName
        $list.Add($uar)
    }
    elseif ($roleAssignment.ObjectType -eq "Group") {
        $groupMembers = Get-MgGroupTransitiveMember -GroupId $roleAssignment.ObjectId
        foreach ($groupMember in $groupMembers) {
            if ($groupMember.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
                $uar = New-Object UserAssignedRole
                $uar.DisplayName = $groupMember.AdditionalProperties.displayName
                $uar.UserPrincipalName = $groupMember.AdditionalProperties.userPrincipalName
                $uar.Role = $roleAssignment.RoleDefinitionName
                $list.Add($uar)
            }
        }
    }
}

$list
