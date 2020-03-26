# Service Principal (SPN) Automation

Tons of good examples about SPN automation can be found
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

Similarly for `Azure CLI` these are the most important commands:

```bash
az ad app create # Create app
az ad app permission add # Add permission
az ad app permission grant # Grant the delegated permissions
az ad app owner # Manage application owners
```

[Manage applications with AAD Graph](https://docs.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest)

**Tip**: If you have issues with your CLI scripting then use `--debug`
flag to give you extra hints what's going on.

Typically you need some permissions from these APIs:

| Application ID   | Resource URI   | Name   |
|---|---|---|
| 00000002-0000-0000-c000-000000000000 | https://graph.windows.net/ | AzureAD Graph API |
| 00000003-0000-0000-c000-000000000000 | https://graph.microsoft.com/ | Microsoft Graph |

Easiest way to get these is to create app manually in Azure Portal and then export
manifest json and look for the actual `resourceAppId` values from the export file.
