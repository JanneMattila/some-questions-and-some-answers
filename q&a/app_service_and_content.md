# Azure App Service

## How do download my app service content to local filesystem?

Here is PowerShell example how to leverage [Kudu Rest APIs](https://github.com/projectkudu/kudu/wiki/REST-API)
for downloading the content underneath the `site/wwwroot` folder as zip file:

```powershell
$appService="<your app name>"
$resourceGroup="<your rg name>"

$publishProfile = [xml] (Get-AzWebAppPublishingProfile `
  -Name $appService `
  -ResourceGroupName $resourceGroup `
  -OutputFile deploy.publishProfile `
  -Format WebDeploy)

$username = $publishProfile.publishData.publishProfile[0].userName
$password = $publishProfile.publishData.publishProfile[0].userPWD

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))

Invoke-WebRequest `
  -Uri "https://$appService.scm.azurewebsites.net/api/zip/site/wwwroot/" `
  -Headers @{Authorization=("Basic {0}" -f $auth)} `
  -OutFile .\$appService.zip
```
