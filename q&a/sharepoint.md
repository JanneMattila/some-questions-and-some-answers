# SharePoint

[Controlling app access on a specific SharePoint site collections is now available in Microsoft Graph](https://devblogs.microsoft.com/microsoft365dev/controlling-app-access-on-specific-sharepoint-site-collections/)

[Granting access via Azure AD App-Only](https://learn.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azuread)

[Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)

[Working with SharePoint sites in Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/sharepoint?view=graph-rest-1.0)

[Create permission](https://learn.microsoft.com/en-us/graph/api/site-post-permissions?view=graph-rest-1.0&tabs=http)

We're going to create two applications, one for the AdminTool and another for the Integration. 

AdminTool has `Sites.FullControl.All` permissions and will be used to onboard the Integration application.

```powershell
# Certificate password
$certificatePasswordPlainText = "<your certificate password>"
$certificatePassword = ConvertTo-SecureString -String $certificatePasswordPlainText -Force -AsPlainText

$certAdminTool = New-SelfSignedCertificate -certstorelocation cert:\currentuser\my -subject "CN=AdminTool"
$certIntegration = New-SelfSignedCertificate -certstorelocation cert:\currentuser\my -subject "CN=Integration"

# Export pfx
Export-PfxCertificate -Cert $certAdminTool -FilePath admintool.pfx -Password $certificatePassword
Export-PfxCertificate -Cert $certIntegration -FilePath integration.pfx -Password $certificatePassword

# Export cer
Export-Certificate -Cert $certAdminTool -FilePath admintool.cer
Export-Certificate -Cert $certIntegration -FilePath integration.cer

# Set thumbprint variables for later use
$admintoolThumbprint = $certAdminTool.thumbprint
$integrationThumbprint = $certIntegration.thumbprint
```

Here are the user API permissions:

![admintool](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/6e33ee0e-ce29-49ae-bca1-da95c24a8b0a)

![integration](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/dc3b1de3-e1aa-4ad5-a2a6-7db88c7777e8)

```powershell
$site = "<put your site here>" # E.g., "name.sharepoint.com:/sites/integration"
$admintoolClientId = "<put your client id here>"
$integrationClientId = "<put your client id here>"
$tenantId = "<put your tenant id here>"
$clientDisplayName = "<put your client display name here>"

########################
# Login as "AdminTool"
########################

Connect-AzAccount -ServicePrincipal -ApplicationId $admintoolClientId -Tenant $tenantId -CertificateThumbprint $admintoolThumbprint

(Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token | clip
# jwt.ms
# This is ***REQUIRED*** ->
# "roles": [
#    "Sites.FullControl.All"
# ]

# List sites
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites"

$siteResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$site"
$siteResponse
$siteId = ($siteResponse.Content | ConvertFrom-Json).id
$siteId

Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId"
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions"

$json = @"
{
  "roles": ["write"],
  "grantedToIdentities": [{
    "application": {
      "id": "$clientId",
      "displayName": "$clientDisplayName"
    }
  }]
}
"@

$json

# Grant permissions to the Integration application
$sitePermissionsResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions" -Method POST -Payload $json
$sitePermissionsResponse

$listResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists"
$sharedDocuments = ($listResponse.Content | ConvertFrom-Json).value  | Where-Object { $_.name -eq "Shared Documents" }
$sharedDocuments

$documentsResponse = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($sharedDocuments.id)/items"
$documentsResponse

$document = ($documentsResponse.Content | ConvertFrom-Json).value  | Select-Object -First 1
$document
$file = $document.webUrl.Split("/")[-1]
$file

$documentDownloadResponse= Invoke-AzRestMethod -Uri $document.webUrl
$documentsResponse

$bearerToken = ConvertTo-SecureString -String (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token -AsPlainText
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($sharedDocuments.id)/items/$($document.id)/driveItem/content" -Authentication Bearer -Token $bearerToken -OutFile $file

Start-Process $file

#########################
# Login as "Integration"
#########################

Connect-AzAccount -ServicePrincipal -ApplicationId $integrationClientId -Tenant $tenantId -CertificateThumbprint $integrationThumbprint

(Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token | clip
# jwt.ms
# This is ***REQUIRED*** ->
# "roles": [
#   "Sites.Selected"
# ],

# List sites (this returns empty list)
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites"
# List site information
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId"

# Directly jump to the file download
Remove-Item $file
$bearerToken = ConvertTo-SecureString -String (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token -AsPlainText
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($sharedDocuments.id)/items/$($document.id)/driveItem/content" -Authentication Bearer -Token $bearerToken -OutFile $file

Start-Process $file
```
