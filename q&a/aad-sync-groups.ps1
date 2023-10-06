# Usage: .\aad-sync-groups.ps1 -SourceGroupID "e70e58dd-e6a6-46c6-a6eb-06ba38182ac6" -TargetGroupID "f6a92b38-7f40-4a6f-9316-4042878bd298"
Param (
    [Parameter(HelpMessage = "Source Azure AD Group Object ID")]
    [string] $SourceGroupID,

    [Parameter(HelpMessage = "Target Azure AD Group Object ID")]
    [string] $TargetGroupID
)

$ErrorActionPreference = "Stop"

$token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token
$bearerToken = ConvertTo-SecureString -String $token -AsPlainText

function Get-AllMembers($Collection, $ObjectID) {
    "Getting members for group $ObjectID"
    $groupJson = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$ObjectID/members" -Authentication Bearer -Token $bearerToken

    foreach ($member in $groupJson.value) {
        "Processing member $($member.displayName), type: $($member.'@odata.type')"

        if ($member.'@odata.type' -eq "#microsoft.graph.group") {
            "Group $($member.displayName) found"
            Get-AllMembers $Collection $member.id
        }
        elseif ($member.'@odata.type' -eq "#microsoft.graph.user") {
            if ($Collection.ContainsKey($member.id) -eq $true) {
                "User $($member.displayName) already exists in collection"
            }
            else {
                "User $($member.displayName) added to collection"
                $Collection.Add($member.id, $member) | Out-Null
            }
        }
    }
}

$sourceUsers = @{}
Get-AllMembers $sourceUsers $SourceGroupID
$sourceUsers

$targetUsers = @{}
Get-AllMembers $targetUsers $TargetGroupID
$targetUsers

$usersToAdd = @{}
$usersToRemove = @{}

foreach ($sourceUser in $sourceUsers.Values) {
    if ($targetUsers.ContainsKey($sourceUser.id) -eq $false) {
        "User $($sourceUser.displayName) should be added to target group"
        $usersToAdd.Add($sourceUser.id, $sourceUser) | Out-Null
    }
}

foreach ($targetUser in $targetUsers.Values) {
    if ($sourceUsers.ContainsKey($targetUser.id) -eq $false) {
        "User $($targetUser.displayName) should be removed from target group"
        $usersToRemove.Add($targetUser.id, $targetUser) | Out-Null
    }
}

$usersToAdd
$usersToRemove

$usersToAdd.Values | ForEach-Object {
    $user = $_
    $body = @{}
    $body.Add("@odata.id", "https://graph.microsoft.com/v1.0/directoryObjects/$($user.id)")
    $bodyJson = $body | ConvertTo-Json

    "Adding user $($user.displayName) to target group"
    Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupID/members/`$ref" -Method POST -Body $bodyJson -ContentType "application/json" -Authentication Bearer -Token $bearerToken
}

$usersToRemove.Values | ForEach-Object {
    $user = $_
    $body = @{}
    $body.Add("@odata.id", "https://graph.microsoft.com/v1.0/users/$($user.id)")
    $bodyJson = $body | ConvertTo-Json

    "Removing user $($user.displayName) from target group"
    Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupID/members/$($user.id)/`$ref" -Method DELETE -Body $bodyJson -ContentType "application/json" -Authentication Bearer -Token $bearerToken
}

"-------------------------------------------"
"Summary:"
"-------------------------------------------"
if ($usersToAdd.Count -eq 0 -and $usersToRemove.Count -eq 0) {
    "No changes needed"
}
else {
    "Following changes applied:"
    $usersToAdd.Values | ForEach-Object {
        "User $($_.displayName) added to target group"
    }
    $usersToRemove.Values | ForEach-Object {
        "User $($_.displayName) removed from target group"
    }
}