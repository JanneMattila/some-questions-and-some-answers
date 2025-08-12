# SharePoint

## Application permissions

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

(Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token | ConvertFrom-SecureString -AsPlainText | clip
# jwt.ms
# This is ***REQUIRED*** ->
# "roles": [
#    "Sites.FullControl.All"
# ]

# List root site information
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root"

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
      "id": "$integrationClientId",
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

$bearerToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($sharedDocuments.id)/items/$($document.id)/driveItem/content" -Authentication Bearer -Token $bearerToken -OutFile $file

Start-Process $file

#########################
# Login as "Integration"
#########################

Connect-AzAccount -ServicePrincipal -ApplicationId $integrationClientId -Tenant $tenantId -CertificateThumbprint $integrationThumbprint

(Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token | ConvertFrom-SecureString -AsPlainText | clip
# jwt.ms
# This is ***REQUIRED*** ->
# "roles": [
#   "Sites.Selected"
# ],

# List root site information
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root"
# List site information
Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId"

# Directly jump to the file download
Remove-Item $file
$bearerToken = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$($sharedDocuments.id)/items/$($document.id)/driveItem/content" -Authentication Bearer -Token $bearerToken -OutFile $file

Start-Process $file
```

## Delegated permissions

[Working with SharePoint sites in Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/sharepoint?view=graph-rest-1.0)

[Using Device Code Flow in MSAL.NET](https://learn.microsoft.com/en-us/entra/msal/dotnet/acquiring-tokens/desktop-mobile/device-code-flow)

[Microsoft identity platform and the OAuth 2.0 device authorization grant flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code)

Create a new application with the following permissions:
- `Sites.Read.All` (for Read only access)
- `Sites.ReadWrite.All` (for Read and Write access)

![API Permissions](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/c30cf46f-968e-4dd2-8325-3fbd52a5bbaf)

Remember to enable "public client flow":

![Public client](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/e72a2d75-aba1-4ba3-a953-b7e57044bfbe)

During the login process, you will see the following consent screen:

![Consent](https://github.com/JanneMattila/some-questions-and-some-answers/assets/2357647/21fa68a7-b687-491b-adc7-5b35a4e83808)

```powershell
$site = "<put your site here>" # E.g., "name.sharepoint.com:/sites/integration"
$clientId = "<put your client id here>"
$tenantId = "<put your tenant id here>"

$authPayload = "scope=https://graph.microsoft.com/.default&client_id=$clientId"

$authEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$authResponse = Invoke-RestMethod -Uri $authEndpoint -Method Post -Body $authPayload
$authResponse.message

$tokenPayload = "client_id=$clientId&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=$($authResponse.device_code)"
$tokenEndpointResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $tokenPayload
$tokenEndpointResponse.access_token
$tokenEndpointResponse.access_token | clip # To copy to clipboard

# Validate scope in https://jwt.ms
# -> "scp": "Sites.ReadWrite.All User.Read profile openid email",

# List root site
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root" -Headers @{Authorization= "Bearer $($tokenEndpointResponse.access_token)"}

$siteResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$site" -Headers @{Authorization= "Bearer $($tokenEndpointResponse.access_token)"}
$siteId = $siteResponse.id

$listResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/sites/$siteId/lists" -Headers @{Authorization= "Bearer $($tokenEndpointResponse.access_token)"}
$sharedDocuments = $listResponse.value  | Where-Object { $_.name -eq "Shared Documents" }
$sharedDocuments

# Continue as in the above example
```
