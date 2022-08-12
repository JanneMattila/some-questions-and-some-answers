# Note:
# Documentation contains similar export script. See this link for more details:
# https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/scripts/powershell-export-apps-with-expriring-secrets
#
Param (
    [Parameter(HelpMessage = "Maximum number of invalid apps found before stops the scan.")]
    [ValidateRange("Positive")]
    [int] $MaxInvalidCount = 200,

    [Parameter(HelpMessage = "Output invalid items.")] 
    [switch] $OutputInvalidItems = $false
)

$ErrorActionPreference = "Stop"

$token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/").Token
$bearerToken = ConvertTo-SecureString -String $token -AsPlainText

$url = "https://graph.microsoft.com/v1.0/applications/?`$select=displayName,id,appId,info,createdDateTime,keyCredentials,passwordCredentials,deletedDateTime"

$now = [System.DateTime]::UtcNow
$invalidCount = 0
$totalCount = 0

$invalidItems = New-Object System.Collections.ArrayList

do {
    $json = Invoke-RestMethod -Uri $url -Authentication Bearer -Token $bearerToken

    $totalCount += $json.value.Count

    foreach ($item in $json.value) {
        $hasInvalidKey = $true
        $hasInvalidPassword = $true
        foreach ($key in $item.keyCredentials) {
            if ($now -lt $key.endDateTime) {
                $hasInvalidKey = $false
                break
            }
        }
        foreach ($password in $item.passwordCredentials) {
            if ($now -lt $password.endDateTime) {
                $hasInvalidPassword = $false
                break
            }
        }

        if ($hasInvalidKey -and $hasInvalidPassword) {
            # Print out the invalid app
            if ($OutputInvalidItems) {
                $item
            }
            $invalidItems.Add($item) | Out-Null
            $invalidCount++
        }
        else {
            # Print out the valid app
            # $item
        }
    }

    "$invalidCount out of $totalCount are invalid"

    if ($MaxInvalidCount -lt $invalidCount) {
        "Stop scanning since already $invalidCount invalid apps found"
        break
    }

    $url = $json.'@odata.nextLink'
} while ($null -ne $url)

$invalidItems | Format-Table
