# Azure App Service

## App Service Authentication and app roles

[App Service Authentication](https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization)

Example `app_service_and_authentication-appRoles.json`:

```json
[
  {
    "allowedMemberTypes": [
      "User"
    ],
    "id": "03c0d74b-c5c0-44e4-9838-7df3aeb0e844",
    "displayName": "Calendars.ReadWrite",
    "description": "Have full access to user calendars",
    "isEnabled": true,
    "value": "Calendars.ReadWrite"
  },
  {
    "allowedMemberTypes": [
      "User"
    ],
    "id": "597bc035-e239-442d-abc0-4a234d7fce47",
    "displayName": "Calendars.Read",
    "description": "Read user calendars",
    "isEnabled": true,
    "value": "Calendars.Read"
  }
]
```

Example `app_service_and_authentication-requiredResourceAccess.json`:

```json
[
  {
    "resourceAppId": "00000003-0000-0000-c000-000000000000",
    "resourceAccess": [
      {
        "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
        "type": "Scope"
      }
    ]
  }
]
```

Above definition is for Microsoft Graph and `User.Read` API permission,
which enables `Sign in and read user profile` access. 

```powershell
$appServiceName="authdemo000001"
$appServicePlanName="authPlan"
$resourceGroup="auth-demo-rg"
$location="westeurope"
$image="jannemattila/echo"
$appUrl="https://$appServiceName.azurewebsites.net"
$replyUrl="$appUrl/.auth/login/aad/callback"

# Login to Azure
az login

# List subscriptions
az account list -o table

# *Explicitly* select your working context
az account set --subscription YourSubscriptionNameHere

# Show current context
az account show -o table

# Store tenant id
$tenantId=(az account show --query tenantId -o TSV)
$tenantId

$appid=(az ad app create `
  --display-name $appServiceName `
  --identifier-uris $appUrl `
  --reply-urls $replyUrl `
  --app-roles .\app_service_and_authentication-appRoles.json `
  --required-resource-accesses .\app_service_and_authentication-requiredResourceAccess.json `
  --query appId -o TSV)
$appid

# Create new resource group
az group create --name $resourceGroup --location $location -o table

# Create App Service Plan
az appservice plan create --name $appServicePlanName --resource-group $resourceGroup --is-linux --number-of-workers 1 --sku Free -o table

# Create App Service
az webapp create --name $appServiceName --plan $appServicePlanName --resource-group $resourceGroup -i $image -o table

# Enable App Service Authentication
az webapp auth update --name $appServiceName --resource-group $resourceGroup `
  --enabled true `
  --action LoginWithAzureActiveDirectory `
  --aad-allowed-token-audiences $replyUrl `
  --aad-token-issuer-url https://sts.windows.net/$tenantId/ `
  --aad-client-id $appid `
  --token-store true `
  --runtime-version "~2"
```

Interesting urls to test:

```powershell
https://$appServiceName.azurewebsites.net/.auth/me
https://$appServiceName.azurewebsites.net/pages/echo
```

First one shows [how to access the tokens](https://docs.microsoft.com/en-us/azure/app-service/app-service-authentication-how-to#retrieve-tokens-in-app-code).

Another one echoes the HTTP Headers set by App Service to you:

```http
X-MS-CLIENT-PRINCIPAL-NAME: your.username@contoso.com
X-MS-CLIENT-PRINCIPAL-ID: 5dfd0b56-2d57-4b02-be8f-5257dd44c158
X-MS-CLIENT-PRINCIPAL-IDP: aad
X-MS-CLIENT-PRINCIPAL: eyJhdXR...oX3R5cCI6ImFh
```

```powershell
# Wipe out the resources
az group delete --name $resourceGroup -y
az ad app delete --id $appid
```

[Restrict your Azure AD app to a set of users in an Azure AD tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-restrict-your-app-to-a-set-of-users)

[Add app roles to your application and receive them in the token](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
