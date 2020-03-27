# Azure AD Automations

## Service Principal (SPN) & App automations

Tons of good examples about Azure AD and SPN automations can be found
in GitHub. Here is one good reference:

[Azure-Samples / active-directory-javascript-graphapi-v2](https://github.com/Azure-Samples/active-directory-javascript-graphapi-v2/tree/quickstart/AppCreationScripts)

This repository contains `PowerShell` examples of the automation.
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

You can also use `Az` PowerShell module for the automation.
Example commands from that module are:

```powershell
New-AzADApplication
New-AzADServicePrincipal

Get-AzADApplication
```

[Az module and Active Directory](https://docs.microsoft.com/en-us/powershell/module/az.resources)

Similarly for `Azure CLI` these are the most important commands:

```bash
az ad app create # Create app
az ad app permission add # Add permission
az ad app permission grant # Grant the delegated permissions
az ad app owner # Manage application owners
```

[Manage applications with Azure AD Graph API using CLI](https://docs.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest)

**Tip**: If you have issues with your CLI scripting then use `--debug`
flag to give you extra hints what's going on. And yes typically they are permission related.

Typically you need some permissions from these APIs:

| Application ID | Resource URI | Name |
|---|---|---|
| 00000002-0000-0000-c000-000000000000 | https://graph.windows.net/ | [Azure AD Graph API](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-graph-api) |
| 00000003-0000-0000-c000-000000000000 | https://graph.microsoft.com/ | [Microsoft Graph](https://docs.microsoft.com/en-us/graph/overview) |

*Just to re-iterate*: You need to understand that many times different applications actually use `Azure AD Graph API` behind the covers even if you think that they are using `Microsoft Graph` (just like above).
You should be extra careful with those ones and assign correct permissions to make things work
(and not just blindly assign more and more permissions without any impact).

Easiest way to get Application ID identifiers for different APIs
is to create app manually in Azure Portal and
then assign those required permissions manually to it. Then you can export
manifest json and look for the actual `resourceAppId` values from the export content.

**Tip**: In order try different Graph API endpoints you need access token for that.
You can use following commands to get them:

```bash
# Get access token for Microsoft Graph API
az account get-access-token --resource https://graph.microsoft.com/

# Get access token for Azure AD Graph API
az account get-access-token --resource https://graph.windows.net/
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
