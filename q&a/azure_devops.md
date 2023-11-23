# Azure DevOps

## Azure DevOps Rest API usage

Look for example Single-page application (SPA) that
connect to [Azure DevOps Rest APIs](https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-5.1) to [create git repository](https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/create?view=azure-devops-rest-5.1),
fills it with few files etc. You can find source repository
of the example here [JanneMattila/azure-devops-simple-content-generator](https://github.com/JanneMattila/azure-devops-simple-content-generator).

## Azure Pipelines

### How do I queue build in Azure Pipelines using Az CLI

Here are the steps that you can use to queue build named `AbsolutelyEmpty-CI`:

```bash
# Install extension to Az CLI if you haven't done it yet
az extension add --name azure-devops

# Set defaults
az devops configure --defaults organization=https://dev.azure.com/YourOrganizationNameHere/
az devops configure --defaults project=YourProjectNameHere

# Queue build
az pipelines build queue --definition-name AbsolutelyEmpty-CI -o table
```

### How do I queue build in Azure Pipelines using PowerShell

Here are the steps that you can use to queue build using PowerShell:

```powershell
$organization = "YourOrganizationNameHere"
$project = "YourProjectNameHere"
$definition = 1 # Build definition id

$username = "" # Can be left blank
$password = "" # Token generated with "Build" scope.

$basicAuth = ("{0}:{1}" -f $username, $password)
$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$basicAuth = [System.Convert]::ToBase64String($basicAuth)
$headers = @{Authorization=("Basic {0}" -f $basicAuth)}

$json = "{ `"definition`": { `"id`": $($definition) } }"
$uri = "https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=2.0"

$parameters = @{
  Headers = $headers
  Uri = $uri
  Method = "POST"
  ContentType = "application/json"
  Body = $json
}
Invoke-RestMethod @parameters
```

### How do I queue release in Azure Pipelines using PowerShell

Here are the steps that you can use to [create release](https://learn.microsoft.com/en-us/rest/api/azure/devops/release/releases/create) using PowerShell:

```powershell
$organization = "YourOrganizationNameHere"
$project = "YourProjectNameHere"
$definition = 1 # Release definition id

$username = "" # Can be left blank
$password = "" # Token generated with "Release: Read, write, & execute" scope.

$basicAuth = ("{0}:{1}" -f $username, $password)
$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$basicAuth = [System.Convert]::ToBase64String($basicAuth)
$headers = @{Authorization=("Basic {0}" -f $basicAuth)}

$json = ConvertTo-Json -Depth 50 @{
  "definitionId" = "$definition"
  "description"  = "This is example release started from PowerShell"
  "isDraft"      =  $false
  "reason"       = "none"
  "variables"    = @{
      "myparam1" = @{
        "allowOverride" = $false
        "isSecret"      = $false
        "value"         = "Value from PowerShell 1"
      }
      "myparam2" = @{
        "allowOverride" = $false
        "isSecret"      = $false
        "value"         = "Value from PowerShell 2"
      }
  }
}
$uri = "https://vsrm.dev.azure.com/$organization/$project/_apis/release/releases?api-version=7.0"

$parameters = @{
  Headers = $headers
  Uri = $uri
  Method = "POST"
  ContentType = "application/json"
  Body = $json
}
$response = Invoke-RestMethod @parameters
$response | ConvertTo-Json
```

### How do I queue pipeline in Azure Pipelines using PowerShell

Here are the steps that you can use to [run pipeline](https://learn.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/run-pipeline?view=azure-devops-rest-7.1) using PowerShell:

Note: Requires `vso.build_execute` permission.

```powershell
$organization = "YourOrganizationNameHere"
$project = "YourProjectNameHere"
$pipelineId = 1 # Pipeline id

$username = "" # Can be left blank
$password = "" # Token generated with "Build: Read, write, & execute" scope.

$basicAuth = ("{0}:{1}" -f $username, $password)
$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$basicAuth = [System.Convert]::ToBase64String($basicAuth)
$headers = @{Authorization=("Basic {0}" -f $basicAuth)}

$json = ConvertTo-Json  @{
  "templateParameters"    = @{
      "myparam1" = "Value from PowerShell 1"
      "myparam2" = "Value from PowerShell 2"
  }
}
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$pipelineId/runs?api-version=7.1-preview.1"

$parameters = @{
  Headers = $headers
  Uri = $uri
  Method = "POST"
  ContentType = "application/json"
  Body = $json
}
$response = Invoke-RestMethod @parameters
$response | ConvertTo-Json
```

You can use [service principals & managed identities](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity?view=azure-devops) to queue pipelines.

```powershell
$APP_ID = "<your app id>"
$TENANT_ID = "<your tenant id>"
$PASSWORD = "<your password>"

az login --service-principal --username $APP_ID --password $PASSWORD --tenant $TENANT_ID --allow-no-subscriptions
$accessToken = $(az account get-access-token --scope 499b84ac-1321-427f-aa17-267ca6975798/.default --query accessToken -o tsv)

$organization = "YourOrganizationNameHere"
$project = "YourProjectNameHere"
$pipelineId = 1 # Pipeline id

$headers = @{Authorization = ("Bearer {0}" -f $accessToken) }

$json = ConvertTo-Json  @{
    "templateParameters" = @{
        "myparam1" = "Value from PowerShell 1"
        "myparam2" = "Value from PowerShell 2"
    }
}
$uri = "https://dev.azure.com/$organization/$project/_apis/pipelines/$pipelineId/runs?api-version=7.1-preview.1"

$parameters = @{
    Headers     = $headers
    Uri         = $uri
    Method      = "POST"
    ContentType = "application/json"
    Body        = $json
}
$response = Invoke-RestMethod @parameters
$response | ConvertTo-Json
```

### Mixing Azure CLI and Azure PowerShell

If you encapsulate your deployments to `deploy.ps1` and
use that in your pipelines, you typically use `Azure Pipelines` task.
However, if you need to add additional `az` CLI calls inside that
same context then you need to share the credentials between these two.

Easiest way to achieve that is to use [Azure CLI Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-cli?view=azure-devops). It enables two things:

- You can continue to use PowerShell script in your deployment pipeline
- It provides access to the service principal so that you can use that to login to Azure

Here are two examples how you can use it:

Example: Minimal `deploy.ps1` to show this in action:

```powershell
Write-Host "Here is az cli context:"
az account show -o table
az group list -o table

$clientPassword = ConvertTo-SecureString $env:servicePrincipalKey -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($env:servicePrincipalId, $clientPassword)

Install-Module Az -Scope CurrentUser -Force -AllowClobber -AcceptLicense
Login-AzAccount -Credential $credentials -ServicePrincipal -TenantId $env:tenantId

Write-Host "Here is Az module context:"
Get-AzContext
Get-AzResourceGroup | Format-Table
```

Example: `deploy.ps1` with some basic deployment patterns implemented:

```powershell
Param (
  [Parameter(HelpMessage = "Deployment target resource group")] 
  [string] $ResourceGroupName = "rg-myapp-local",

  [Parameter(HelpMessage = "Deployment target resource group location")] 
  [string] $Location = "North Europe",

  [Parameter(Mandatory = $true, HelpMessage = "Example additional parameter")]
  [string] $AdditionalParameters,

  [string] $Template = "$PSScriptRoot\azuredeploy.json",
  [string] $TemplateParameters = "$PSScriptRoot\azuredeploy.parameters.json"
)

$ErrorActionPreference = "Stop"

$date = (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")
$deploymentName = "Local-$date"

if ([string]::IsNullOrEmpty($env:BUILD_BUILDNUMBER)) {
  Write-Host (@"
Not executing inside Azure DevOps Release Management.
Make sure you have correct contexts set.
"@)
}
else {
  $deploymentName = $env:BUILD_BUILDNUMBER

  # Process Azure PowerShell login
  $clientPassword = ConvertTo-SecureString $env:servicePrincipalKey -AsPlainText -Force
  $credentials = New-Object System.Management.Automation.PSCredential($env:servicePrincipalId, $clientPassword)

  $installedModule = Get-Module -Name Az -ListAvailable
  if ($null -eq $installedModule) {
    Write-Host "Installing Az module..."
    Install-Module Az -Scope CurrentUser -Force -AllowClobber -AcceptLicense
  }
  else {
    Import-Module Az
  }
  Login-AzAccount -Credential $credentials -ServicePrincipal -TenantId $env:tenantId
}

if ($null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue)) {
  Write-Warning "Resource group '$ResourceGroupName' doesn't exist and it will be created."
  New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Verbose
}

# Additional parameters that we pass to the template deployment
$additionalParameters = New-Object -TypeName hashtable
$additionalParameters['additionalParameters'] = $AdditionalParameters

$result = New-AzResourceGroupDeployment `
  -DeploymentName $deploymentName `
  -ResourceGroupName $ResourceGroupName `
  -TemplateFile $Template `
  -TemplateParameterFile $TemplateParameters `
  @additionalParameters `
  -Mode Complete -Force `
  -Verbose

if ($null -eq $result.Outputs.webAppName) {
  Throw "Template deployment didn't return web app information correctly and therefore deployment is cancelled."
}

$result

$webAppName = $result.Outputs.webAppName.value

# Here you can inject 'az' CLI activities:
az webapp show -n $webAppName -g $ResourceGroupName

# Publish variable to the Azure DevOps agents so that they
# can be used in follow-up tasks such as application deployment
Write-Host "##vso[task.setvariable variable=Custom.WebAppName;]$webAppName"
```

Actual step configuration in pipeline would be then:

```yaml
steps:
- task: AzureCLI@2
  displayName: 'Azure deployment'
  inputs:
    azureSubscription: 'AzureSubscription'
    scriptType: pscore
    scriptPath: '$(Pipeline.Workspace)/deploy/deploy.ps1'
    addSpnToEnvironment: true
```

### How do I access network restricted resource from pipeline

If you need to access network restricted resource e.g,
Azure Storage Account or Azure SQL from your pipeline,
then you pretty much have two options:

1. Use Microsoft hosted agent and temporarily change network rules
2. Use Self-hosted agent from network that has access to target resource

If you're interested in option 1. then there are couple of additional
topics to study. Here are examples from Azure DevOps Agent Task library
for [SQL task](https://github.com/microsoft/azure-pipelines-tasks/blob/f65985e174a41c5a694a1c246ee4cae26829f4c8/Tasks/SqlAzureDacpacDeploymentV1/SqlAzureActions.ps1#L397-L436)
and [helper](https://github.com/microsoft/azure-pipelines-tasks/blob/acc64cc7292c98597908325e53af9f898a896189/Tasks/Common/VstsAzureRestHelpers_/VstsAzureRestHelpers_.psm1#L873-L942)
class. 

Similarly, you can implement something similar yourself
using these steps:

1. Pre-deployment task: Add network exception
2. Actual deployment task
3. Post-deployment task: Remove network exception
    - You run this step regardless of the success of step 2

Here's example about creating network exception to storage account:

```powershell
# Grab IP address of self-hosted agent
$ip = Invoke-RestMethod -Uri "https://api.ipify.org/"

# Add temporary access control to the target resource
Add-AzStorageAccountNetworkRule `
  -ResourceGroupName $resourceGroup `
  -AccountName $storageName `
  -IPAddressOrRange $ip

# Publish the IP to agent as variable
Write-Host "##vso[task.setvariable variable=IPADDRESS;isoutput=true]$ip"
```

You can use above in following task:

```yaml
- pwsh: |
    # Grab IP address of self-hosted agent
    $ip = Invoke-RestMethod -Uri "https://api.ipify.org/"
    
    # Add temporary access control to the target resource
    Add-AzStorageAccountNetworkRule `
      -ResourceGroupName $resourceGroup `
      -AccountName $storageName `
      -IPAddressOrRange $ip
    
    # Publish the IP to agent as variable
    Write-Host "##vso[task.setvariable variable=IPADDRESS;isoutput=true]$ip"
  name: AddNetworkRule
```

At the end you can remove the network rule exception:

```powershell
# Remove temporary access
Remove-AzStorageAccountNetworkRule `
  -ResourceGroupName $resourceGroup `
  -AccountName $storageName `
  -IPAddressOrRange $env:ADDNETWORKRULE_IPADDRESS
```

```yaml
- pwsh: |
    # Remove temporary access
    Remove-AzStorageAccountNetworkRule `
      -ResourceGroupName $resourceGroup `
      -AccountName $storageName `
      -IPAddressOrRange $env:ADDNETWORKRULE_IPADDRESS
  name: RemoveNetworkRule
  condition: always()
```

If above is not acceptable from security perspective
or you have many services that would require network
rule change that it's not even practical to do that, then use [Self-hosted agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents#install).

**Note**: You need to have PAT when you register the agent but
further communication will use [tokens in the communication](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents#communication).
