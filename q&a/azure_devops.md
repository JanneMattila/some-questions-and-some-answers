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
