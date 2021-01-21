# AzOps

## Repositories

[Azure/Enterprise-Scale](https://github.com/Azure/Enterprise-Scale)

[Azure/AzOps](https://github.com/Azure/AzOps)

## Links

[Enterprise-Scale - Policy Driven Governance by Stefan Stranger](https://stefanstranger.github.io/2020/08/28/EnterpriseScalePolicyDrivenGovernance/)

[How to operationalize Enterprise-Scale with Infrastructure-as-Code via AzOps](https://techcommunity.microsoft.com/t5/azure-architecture-blog/how-to-operationalize-enterprise-scale-with-infrastructure-as/ba-p/1759649)

## How can I do local development?

One easy way is to create PowerShell file and use Visual Studio Code
with PowerShell extension and use `Ctrl + Enter` (or `Shift + Enter` depending your setup) to execute
line one-by-one.

Here's example local development file:

```powershell
# Unfortunately, there is no PowerShell Gallery module yet!
# Maybe some day: Install-Module AzOps
# But now: git clone https://github.com/Azure/AzOps
Push-Location
Set-Location C:\GitHub\Azure\AzOps\
git pull
Import-Module C:\GitHub\Azure\AzOps\src\AzOps.psd1 -Force
Pop-Location

$azStateDirectory = Join-Path -Path (Get-Location).Path -ChildPath "azops"
$azStateDirectory

# Setup instructions:
# https://github.com/Azure/Enterprise-Scale/blob/main/docs/EnterpriseScale-Setup-azure.md
$tenantId = "<your tenant id>"
$clientID = "<your app id>" # azops
$clientSecret = "<your secret>"

$clientPassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($clientID, $clientPassword)
Login-AzAccount -Credential $credentials -ServicePrincipal -TenantId $tenantId

mkdir $azStateDirectory
$env:AZOPS_IGNORE_CONTEXT_CHECK = 1 # If set to 1, skip AAD tenant validation == 1
$env:AZOPS_STATE = $azStateDirectory

# Prepare and validate global variables
Initialize-AzOpsGlobalVariables -Verbose

# Takes a snapshot of the entire Azure environment from MG all the way down to resource level.
# Note: Only works in filesystem level. Does not commit to git.
Initialize-AzOpsRepository -Verbose -SkipResourceGroup -Force

# Azure -> Git
Invoke-AzOpsGitPull -Verbose -SkipResourceGroup -Force

# Git -> Azure
Invoke-AzOpsGitPush -Verbose -SkipResourceGroup -Force
```
