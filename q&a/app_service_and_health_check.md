# App Service and Health check

[Health check](https://docs.microsoft.com/en-us/azure/app-service/monitor-instances-health-check)
is app service feature for checking your app health by
pinging each instance your app runs on.
Instances that are unhealthy are removed from receiving
traffic and given time to recover back to healthy state.

```powershell
$appServiceName = "healthcheck000001"
$appServicePlanName = "healthcheckPlan"
$resourceGroup = "rg-health-check"
$location = "westeurope"
$image = "jannemattila/k8s-probe-demo:1.0.10"

# Login to Azure
az login

# *Explicitly* select your working context
az account set --subscription <YourSubscription>

# # Show current context
az account show -o table

# # Create new resource group
az group create --name $resourceGroup --location $location -o table

# # Create App Service Plan
az appservice plan create --name $appServicePlanName --resource-group $resourceGroup --is-linux --number-of-workers 3 --sku B1 -o table

# Create App Service
az webapp create --name $appServiceName --plan $appServicePlanName --resource-group $resourceGroup -i $image -o table
```

Optinally you can enable [diagnostics logs](https://docs.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs#send-logs-to-azure-monitor-preview)
for analysing `AppServicePlatformLogs` later on.
