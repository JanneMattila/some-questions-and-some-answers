# Azure AD Automations

## Service Principal (SPN) & App automations

Tons of good examples about Azure AD and SPN automations can be found
in GitHub. Here are few:

- [Azure-Samples / active-directory-javascript-graphapi-v2](https://github.com/Azure-Samples/active-directory-javascript-graphapi-v2/tree/quickstart/AppCreationScripts)
- [cradle77 / Blazor.Msal](https://github.com/cradle77/Blazor.Msal/blob/master/src/AppCreationScripts/Create.ps1) example scripts
- [microsoftgraph / powershell-intune-samples](https://github.com/microsoftgraph/powershell-intune-samples/blob/master/ManagedDevices/ManagedDevices_Get.ps1)

To quickly summarize the key pieces:

```powershell
# Use AzureAD module
if ((Get-Module -ListAvailable -Name "AzureAD") -eq $null) {
    Install-Module AzureAD -Scope CurrentUser
}

Import-Module AzureAD

Connect-AzureAD # with parameters

# For permissions handling these are the key pieces:
$resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
$resourceAccess.Type = $permissionType # Scope = Delegated permissions | Role = Application permissions
$resourceAccess.Id = $exposedPermission.Id # Read directory data
$requiredAccess.ResourceAccess.Add($resourceAccess)

# Create commands
New-AzureADApplication
New-AzureADServicePrincipal

# Manage application owners
Get-AzureADApplicationOwner
Add-AzureADApplicationOwner
```

[AzureAD & Applications](https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0#applications)

*Important note*: Above command rely on `Azure AD Graph API` and there is also
another set of [commands](https://docs.microsoft.com/en-us/powershell/azure/active-directory/ad-pshell-v2-version-history?view=azureadps-2.0#20276---general-availability-release-of-the-azuread-module) which in turn rely on `Microsoft Graph API`. They have `"MS"` in the name:

```powershell
Get-AzureADMSApplication
New-AzureADMSApplication

Get-AzureADMSApplicationOwner
Add-AzureADMSApplicationOwner
```

**Note about Azure Pipelines**: If you're using Azure Pipelines
in your deployments and want to re-use credentials from "Azure PowerShell" task in your
automations then you still need to separately use `Connect-AzureAD`.
There are examples how to get access token from Azure PowerShell
session:

- [Azure/azure-functions-core-tools](https://github.com/Azure/azure-functions-core-tools/blob/f53563b622ee68f00811ddaaaa67d1199067f8ad/src/Azure.Functions.Cli/Actions/AzureActions/BaseAzureAction.cs#L266-L273)
- [Using pipeline identity for Connect-AzureAD, Graph and other endpoints](https://www.lieben.nu/liebensraum/2020/01/using-pipeline-identity-for-connect-azuread-graph-and-other-endpoints/)
- [Azure/azure-powershell](https://github.com/Azure/azure-powershell/issues/7752#issuecomment-517005553)

**Note about assembly load related issues**: You might get
following issues if you use PowerShell and you have different
versions of the `Microsoft.IdentityModel.Clients.ActiveDirectory`
assemblies loaded (especially in your local machine but of course does not
apply to Hosted build agent the same way). Error message can be something like this:

```powershell
Connect-AzureAD: Could not load file or assembly 'Microsoft.IdentityModel.Clients.ActiveDirectory,
Version=x.y.z, Culture=neutral, PublicKeyToken=31bf3856ad364e35'.
Could not find or load a specific file. (0x80131621)
```

First check that you don't have `AzureADPreview` installed
which might have conflicting assemblies with `Az` module.
Then you might need to use `Windows PowerShell` in case you
continue to have issues with `PowerShell Core` ([more info](https://github.com/Azure/azure-powershell/issues/11446)).

Here is example script based on how to use current `Get-AzContent`
for connecting to `Connect-AzureAD`:

```powershell
$context = Get-AzContext
$accountId = $context.Account.Id
$tenant = $context.Tenant.TenantId
$scope = "https://graph.windows.net" # Azure AD Graph API
$dialog = [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never

$azureSession = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $tenant, $null, $dialog, $null, $scope)

# Azure AD Graph API token
$accessToken = $azureSession.AccessToken

$aadInstalledModule = Get-Module -Name "AzureAD" -ListAvailable
if ($null -eq $aadInstalledModule)
{
  Install-Module AzureAD -Scope CurrentUser
}
else
{
  Import-Module AzureAD
}

Connect-AzureAD -AadAccessToken $accessToken -AccountId $accountId -TenantId $tenant
```

You can also use `Az` PowerShell module for the Azure AD automation.
Example commands from that module are:

```powershell
New-AzADApplication
New-AzADServicePrincipal

Get-AzADApplication
```

Read more: [Az module and Active Directory](https://docs.microsoft.com/en-us/powershell/module/az.resources)

Similarly for `Azure CLI` these are the most important commands:

```bash
az ad app create # Create app
az ad app permission add # Add permission
az ad app permission grant # Grant the delegated permissions
az ad app owner # Manage application owners
```

Read more: [Manage applications with Azure AD Graph API using CLI](https://docs.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest)

**Tip**: If you have issues with your CLI scripting then use `--debug`
flag to give you extra hints what's going on. And yes typically they are permission related.

Typically you need some permissions from these APIs:

| Application ID                       | Resource URI                 | Name                                                                                                             |
|--------------------------------------|------------------------------|------------------------------------------------------------------------------------------------------------------|
| 00000002-0000-0000-c000-000000000000 | https://graph.windows.net/   | [Azure AD Graph API](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-graph-api) |
| 00000003-0000-0000-c000-000000000000 | https://graph.microsoft.com/ | [Microsoft Graph](https://docs.microsoft.com/en-us/graph/overview)                                               |

*Just to re-iterate*: You need to understand that many times different applications actually use `Azure AD Graph API` behind the covers even if you think that they are using `Microsoft Graph` (just like above).
You should be extra careful with those ones and assign correct permissions to make things work
(and not just blindly assign more and more permissions without any impact).

Easiest way to get Application ID identifiers for different APIs
is to create app manually in Azure Portal and
then assign those required permissions manually to it. Then you can export
manifest json and look for the actual `resourceAppId` values from the export content.

**Tip**: In order try different Graph API endpoints you need access token for that.
You can use following commands to get them in Azure CLI:

```bash
# Get access token for Microsoft Graph API
az account get-access-token --resource https://graph.microsoft.com/

# Get access token for Azure AD Graph API
az account get-access-token --resource https://graph.windows.net/
```

Or in PowerShell:

```powershell
# Get access token for Microsoft Graph API
Get-AzAccessToken -ResourceUrl https://graph.microsoft.com/

# Get access token for Azure AD Graph API
Get-AzAccessToken -ResourceUrl https://graph.windows.net/
```

Then you can use e.g. Visual Studio Code with Rest client and try APIs out.

Few examples about `Microsoft Graph API`:

```http
@accesstoken = put_here_token_you_got_from_cli

### Retrieve the properties and relationships of user object
GET https://graph.microsoft.com/v1.0/me HTTP/1.1
Content-Type: application/json; charset=utf-8
Authorization: Bearer {{accesstoken}}

### Get groups and directory roles that the user is a direct member of
GET https://graph.microsoft.com/v1.0/me/memberOf HTTP/1.1
Content-Type: application/json; charset=utf-8
Authorization: Bearer {{accesstoken}}

### Return all of the groups that this group is a member of
POST https://graph.microsoft.com/v1.0/groups/{id}/getMemberObjects HTTP/1.1
Content-Type: application/json; charset=utf-8
Authorization: Bearer {{accesstoken}}

{
  "securityEnabledOnly": false
}
```

More information about the required Microsoft Graph API permissions per API can be found in here:
[Microsoft Graph REST API reference](https://docs.microsoft.com/en-us/graph/api/overview)
(and similarly for [Azure AD Graph API reference](https://docs.microsoft.com/en-us/previous-versions/azure/ad/graph/api/api-catalog)).

Few examples about `Azure AD Graph API`:

```http
@accesstoken = put_here_token_you_got_from_cli

### Gets the signed-in user
GET https://graph.windows.net/me?api-version=1.6 HTTP/1.1
Content-Type: application/json; charset=utf-8
Authorization: Bearer {{accesstoken}}

### Get groups and directory roles that the user is a direct member of
GET https://graph.windows.net/me/$links/memberOf?api-version=1.6 HTTP/1.1
Content-Type: application/json; charset=utf-8
Authorization: Bearer {{accesstoken}}
```

## Login as service principal

Using PowerShell:

```powershell
$tenantId = "<your tenant id>"
$clientID = "<your service principal Application (client) ID>"
$clientSecret = "<your service principal secret>"
$clientPassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($clientID, $clientPassword)

Login-AzAccount -Credential $credentials -ServicePrincipal -TenantId $tenantId
```

Using Azure CLI:

```bash
tenantId="<your tenant id>"
clientID="<your service principal Application (client) ID>"
clientSecret="<your service principal secret>"

az login --service-principal --username $clientID --password $clientSecret --tenant $tenantId
```

## Testing authentication and claims

If you have created new Azure AD app registration
for your web application and you want to test it,
easiest way is to hand craft test login url.

First set the redirect url to be `https://jws.ms`
so that we can better analyze the token content.

Here is example url if you have multi-tenant
app (tenant = `common`). You just need to update
`client_id` from your newly created app registration:

```curl
https://login.microsoftonline.com/common/oauth2/v2.0/authorize
  ?client_id=f6e62627-60f2-40d7-b2eb-355a1d0f922d
  &redirect_uri=https%3A%2F%2Fjwt.ms
  &response_mode=fragment
  &response_type=id_token
  &scope=openid
  &nonce=dummy
  &state=12345
```

Here is similar example for you sigle tenant
application. Update `client_id` and `<tenant_id>`
to match your app registration:

```curl
https://login.microsoftonline.com/<tenant_id>/oauth2/v2.0/authorize
  ?client_id=f6e62627-60f2-40d7-b2eb-355a1d0f922d
  &redirect_uri=https%3A%2F%2Fjwt.ms
  &response_mode=fragment
  &response_type=id_token
  &scope=openid
  &nonce=dummy
  &state=12345
```

## `Application.ReadWrite.OwnedBy` permission

If you need to create automation that creates new app registrations
and manages their information (such as secrets etc.), then you'll
need to use `Application.ReadWrite.OwnedBy` permission in
your application.

Read more about [application permissions](https://docs.microsoft.com/en-us/graph/permissions-reference#application-permissions-4).

## Scan Azure AD Application in PowerShell

See example [scan applications](aad-scan-applications.ps1) written in PowerShell.

## Scenario: App Service authentication and service-to-service integration

See example [App Service authentication and service-to-service integration](aad_app_service_and_s2s.md).

## Scenario: Maintain Enterprise application user assignments automatically

See example [Maintain Enterprise application user assignments automatically](aad_enterprise_app_user_assignments.md).

## Links

[What is the Microsoft identity platform?](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-overview)

[Relationship between application objects and service principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals#relationship-between-application-objects-and-service-principals)
