Param (
    [Parameter(HelpMessage = "Output file to use.")]
    [string] $OutputFile = "apps-with-nonallowed-secrets.csv",

    [Parameter(HelpMessage = "Maximum number of days to the future secret is allowed.")]
    [ValidateRange("Positive")]
    [int] $MaxDaysToFuture = 365 * 2
)

$ErrorActionPreference = "Stop"

class Apps {
    [string] $ObjectId
    [string] $ClientId
    [string] $DisplayName
    [string] $ExpirationDate
}

$url = "https://graph.microsoft.com/v1.0/applications/?`$select=displayName,id,appId,info,createdDateTime,keyCredentials,passwordCredentials,deletedDateTime"

$mandatoryExpirationDate = [System.DateTime]::UtcNow.AddDays($MaxDaysToFuture)

$apps = New-Object System.Collections.ArrayList

do {
    $json = (Invoke-AzRestMethod -Uri $url).Content | ConvertFrom-Json

    $totalCount += $json.value.Count

    foreach ($item in $json.value) {
        $hasNonAllowedKey = $false
        $hasNonAllowedSecret = $false
        $expirationDate = $null
        foreach ($key in $item.keyCredentials) {
            if ($mandatoryExpirationDate -lt $key.endDateTime) {
                $hasNonAllowedKey = $true
                $expirationDate = $key.endDateTime
                break
            }
        }
        foreach ($password in $item.passwordCredentials) {
            if ($mandatoryExpirationDate -lt $password.endDateTime) {
                $hasNonAllowedSecret = $true
                $expirationDate = $password.endDateTime
                break
            }
        }

        if ($hasNonAllowedKey -or $hasNonAllowedSecret) {
            $app = [Apps]::new()
            $app.ObjectId = $item.id
            $app.ClientId = $item.appId
            $app.DisplayName = $item.displayName
            $app.ExpirationDate = $expirationDate.ToString("yyyy-MM-dd")
            $apps.Add($app) | Out-Null
        }
    }

    $url = $json.'@odata.nextLink'
} while ($null -ne $url)

$apps | Format-Table

if ($apps.Count -eq 0) {
    "No apps with non-allowed secrets found"
}
else {
    "$($apps.Count) apps with non-allowed secrets found"
    $apps | Export-CSV $OutputFile -Delimiter ';' -Force
    Start-Process $OutputFile
}
