# Azure App Service

## App Service Authentication and app roles

Scenario:
- You have app in app service and you want to secure it using Azure AD authentication
- You have one or more roles set for each end users
- You want to control as much as possible in Azure (and not in custom code)

Our goal is to enable
[App Service Authentication](https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization).

We do that in following steps:

1. Create Azure AD App Registration
    - Includes Microsoft Graph `User.Read` API permission to enable login using Azure AD
    - Includes definition for each application role that you need
        - In this example only roles are defined: `Calendar Administrator` and `Calendar User`
2. Create App Service and enable authentication using the newly registered application
3. Assign users to the role in Azure AD Enterprise Applications

Example `app_service_and_authentication-appRoles.json` for our demo roles:

```json
[
  {
    "allowedMemberTypes": [
      "User"
    ],
    "id": "03c0d74b-c5c0-44e4-9838-7df3aeb0e844",
    "displayName": "Calendar Administrator",
    "description": "Have full access to all calendars",
    "isEnabled": true,
    "value": "Calendars.ReadWrite.All"
  },
  {
    "allowedMemberTypes": [
      "User"
    ],
    "id": "597bc035-e239-442d-abc0-4a234d7fce47",
    "displayName": "Calendar User",
    "description": "Read calendars",
    "isEnabled": true,
    "value": "Calendars.Read"
  }
]
```

Example `app_service_and_authentication-requiredResourceAccess.json` for defining the required
API accesses:

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

Here's example script how you can automate the above:

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

Interesting urls to test after deployment:

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

In order to require user assignment to this application
    - Under *"Enterprise Application"* blade find `authdemo000001`
    - Under properties set `User assignment required?` to `Yes`
    - Under Users and groups add correct role assignment

Now you can test the login again and you should see claim in your token:

```json
...
  "roles": [
    "Calendars.ReadWrite"
  ],
...
```

After testing you can remove all the created resources:

```powershell
# Wipe out the resources
az group delete --name $resourceGroup -y
az ad app delete --id $appid
```

### Links

[Restrict your Azure AD app to a set of users in an Azure AD tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-restrict-your-app-to-a-set-of-users)

[Add app roles to your application and receive them in the token](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
