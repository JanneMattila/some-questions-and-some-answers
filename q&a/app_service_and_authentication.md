# Azure App Service

## App Service Authentication and app roles

Scenario:
- You have app in app service and you want to secure it using Azure AD authentication
- You want to assign one or more business roles for each end user
- You want to protect different application views using these business roles
- You want to control as much as possible in Azure (and not in custom code)

Our goal is to enable
[App Service Authentication](https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization)
and leverage Azure AD for these role management tasks.

We do that in following steps:

1. Create Azure AD App Registration
    - Includes Microsoft Graph `User.Read` API permission to enable login using Azure AD
    - Includes definition for each application role that you need
        - In this example only two roles are defined: `Calendar Administrator` and `Calendar User`
2. Create App Service and enable authentication using the newly registered application
3. Assign users to the roles in Azure AD Enterprise Applications

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
  --runtime-version "~1"
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

In order to require user assignment in order to access this application:

- Under *"Enterprise Application"* blade find `authdemo000001`
- Under properties set `User assignment required?` to `Yes`
- Under Users and groups add correct role assignment
    - Add example: `Calendar Administrator` role to yourself

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

## App Service Authentication Headers

App Service authenticatin add headers that you can easily access
in your applications. Here are example of them:

```
X-MS-CLIENT-PRINCIPAL-NAME: john.doe@contoso.com
X-MS-CLIENT-PRINCIPAL-ID: d44dfc56-9d5a-4940-90b7-efe774408c30
X-MS-CLIENT-PRINCIPAL-IDP: aad
X-MS-CLIENT-PRINCIPAL: eyJh..<clip>..n0=
X-MS-TOKEN-AAD-ACCESS-TOKEN: eyJ0..<clip>..nA
X-MS-TOKEN-AAD-EXPIRES-ON: 2021-06-08T15:35:58.9638246Z
X-MS-TOKEN-AAD-ID-TOKEN: eyJ0..<clip>..6Q
```

X-MS-CLIENT-PRINCIPAL is base64 encoded json (my test example was 1984 characters long):

```json
{
	"auth_typ" : "aad",
	"claims" : [{
			"typ" : "aud",
			"val" : "fe42b4d1-fed9-41f2-b923-e0508a570e89"
		}, {
			"typ" : "iss",
			"val" : "https:\/\/login.microsoftonline.com\/884b819a-cecd-470b-ac1b-c746cafa6d7c\/v2.0"
		}, {
			"typ" : "iat",
			"val" : "1623162657"
		}, {
			"typ" : "nbf",
			"val" : "1623162657"
		}, {
			"typ" : "exp",
			"val" : "1623166557"
		}, {
			"typ" : "aio",
			"val" : "AWQAm\/8TAAAAjbik0mvEvN93HX3y1kRcrmBvxCCE8wP5dDYS1\/Hmjbgxq6d6YcQr0z4NOGjvk2EYkrg8fwGnsNZXn\/U8LPNImeuJ7OXnr5QJevoHGGBLqNk++CYojE71z4K69YEJGuTX"
		}, {
			"typ" : "c_hash",
			"val" : "g9aFiYD2j7duJWKoU5Uqpw"
		}, {
			"typ" : "http:\/\/schemas.xmlsoap.org\/ws\/2005\/05\/identity\/claims\/emailaddress",
			"val" : "john.doe@contoso.com"
		}, {
			"typ" : "name",
			"val" : "John Doe"
		}, {
			"typ" : "nonce",
			"val" : "9b6140e205694202b1e7b8f144315539_20210608144053"
		}, {
			"typ" : "http:\/\/schemas.microsoft.com\/identity\/claims\/objectidentifier",
			"val" : "d44dfc56-9d5a-4940-90b7-efe774408c30"
		}, {
			"typ" : "preferred_username",
			"val" : "johndoe@contoso.com"
		}, {
			"typ" : "rh",
			"val" : "0.ARoAv4j5cvGGr0GRqy180BHbR7yZIkRzh9pptY2C97hyC1oaALE."
		}, {
			"typ" : "http:\/\/schemas.xmlsoap.org\/ws\/2005\/05\/identity\/claims\/nameidentifier",
			"val" : "rR6NQYg3olb7a8ym7A1PNUnOMQBY9eLwgqTtq6y2g9E"
		}, {
			"typ" : "http:\/\/schemas.microsoft.com\/identity\/claims\/tenantid",
			"val" : "884b819a-cecd-470b-ac1b-c746cafa6d7c"
		}, {
			"typ" : "uti",
			"val" : "qEX96JcvnkeKZx4HqoXqAA"
		}, {
			"typ" : "ver",
			"val" : "2.0"
		}
	],
	"name_typ" : "http:\/\/schemas.xmlsoap.org\/ws\/2005\/05\/identity\/claims\/emailaddress",
	"role_typ" : "http:\/\/schemas.microsoft.com\/ws\/2008\/06\/identity\/claims\/role"
}
```

X-MS-TOKEN-AAD-ACCESS-TOKEN decoded Microsoft Graph access token (my test example token was 2592 characters long):

```json
{
  "aud": "00000003-0000-0000-c000-000000000000",
  "iss": "https://sts.windows.net/884b819a-cecd-470b-ac1b-c746cafa6d7c/",
  "iat": 1623162659,
  "nbf": 1623162659,
  "exp": 1623166559,
  "acct": 0,
  "acr": "1",
  "acrs": [
    "urn:user:registersecurityinfo",
    "urn:microsoft:req2",
    "urn:microsoft:req3",
    "c1",
    "c2",
    "c3",
    "c4",
    "c5",
    "c6",
    "c7",
    "c8",
    "c9",
    "c10",
    "c11",
    "c12",
    "c13",
    "c14",
    "c15",
    "c16",
    "c17",
    "c18",
    "c19",
    "c20",
    "c21",
    "c22",
    "c23",
    "c24",
    "c25"
  ],
  "aio": "AUQAu/8TAAAAcJ0+EgGawjYawWHvdrAoKBSwBscnO3N8GyN3X0AkCgNIO9KsUOP/dsP+qqe6YXc9QsEjrTkjzn3Rs8Cw37UIXg==",
  "amr": [
    "rsa",
    "mfa"
  ],
  "app_displayname": "Excellent App Service Demo App",
  "appid": "fe42b4d1-fed9-41f2-b923-e0508a570e89",
  "appidacr": "1",
  "controls": [
    "app_res"
  ],
  "controls_auds": [
    "ac872796-248d-446c-984c-4777859de3d9"
  ],
  "deviceid": "ddb31514-6b9f-4e17-ae7f-a60660f2eb33",
  "family_name": "Doe",
  "given_name": "John",
  "idtyp": "user",
  "ipaddr": "85.76.83.171",
  "name": "John Doe",
  "oid": "d44dfc56-9d5a-4940-90b7-efe774408c30",
  "onprem_sid": "S-1-5-21-2467881721-353676-5367672231-95799",
  "platf": "3",
  "puid": "10037FFE801AD9B7",
  "rh": "0.ARoAv4j5cvGGr0GRqy180BHbR7yZIkRzh9pptY2C97hyC1oaALE.",
  "scp": "email openid profile",
  "signin_state": [
    "dvc_mngd",
    "dvc_cmp",
    "kmsi"
  ],
  "sub": "EunQqutvDbRgIArZQNzj4SeHgXiwLDJ1Fz6Qej_-t5Q",
  "tenant_region_scope": "WW",
  "tid": "884b819a-cecd-470b-ac1b-c746cafa6d7c",
  "unique_name": "johndoe@contoso.com",
  "upn": "johndoe@contoso.com",
  "uti": "eRsDc-ds8kuNZ7LLVR4GAQ",
  "ver": "1.0",
  "wids": [
    "b79fbf4d-3ef9-4689-8143-76b194e85509"
  ],
  "xms_st": {
    "sub": "rR6NQYg3olb7a8ym7A1PNUnOMQBY9eLwgqTtq6y2g9E"
  },
  "xms_tcdt": 1289241547
}
```

X-MS-TOKEN-AAD-ID-TOKEN decoded token (my test example token was 1420 characters long):

```json
{
  "aud": "fe42b4d1-fed9-41f2-b923-e0508a570e89",
  "iss": "https://login.microsoftonline.com/884b819a-cecd-470b-ac1b-c746cafa6d7c/v2.0",
  "iat": 1623162659,
  "nbf": 1623162659,
  "exp": 1623166559,
  "aio": "AWQAm/8TAAAAvkC3oXiX3/CuA6AyrFs5DmzaW+tFwwGoGyAwiMv7ykRnhN/UuBRRpzvuGNPdDgcWi2ZVMCVpdQhXZUELytlMuxP3Ex4ya9Iv2BAFo6wwYzdVqtcFGaM3Sr+oUrDrLlp",
  "email": "john.doe@contoso.com",
  "name": "John Doe",
  "nonce": "9b6140e205694202b1e7b8f144315539_20210608144053",
  "oid": "d44dfc56-9d5a-4940-90b7-efe774408c30",
  "preferred_username": "johndoe@contoso.com",
  "rh": "0.ARoAv4j5cvGGr0GRqy180BHbR7yZIkRzh9pptY2C97hyC1oaALE.",
  "sub": "rR5NQYg2olb7a7ym7A1PNUnOMQBY9eLwgqRtq6y2g9E",
  "tid": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "uti": "eRsDc-ds8kuNZ7LLVR4GAQ",
  "ver": "2.0"
}
```

In above request example the App Service authentication headers were 6292 characters.

In case you run into HTTP status 431 `Request Header Fields Too Large` see more details in below links
about using `WEBSITE_AUTH_DISABLE_IDENTITY_FLOW` = `true` app setting for removing .NET specific header
from the request:

[Advanced Application Settings](https://github.com/cgillum/easyauth/wiki/Advanced-Application-Settings)

[HTTP 431 Request Header Fields Too Large - on Azure App Services - Linux](https://azureossd.github.io/2020/07/25/HTTP-431s-on-Azure-App-Services-Linux/)

[Azure Web App + Node.js + Azure AD = Error 431](https://stackoverflow.com/questions/61059648/azure-web-app-node-js-azure-ad-error-431)

[Configure Node.js server](https://docs.microsoft.com/en-us/azure/app-service/configure-language-nodejs?pivots=platform-linux#configure-nodejs-server)

### Links

[Restrict your Azure AD app to a set of users in an Azure AD tenant](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-restrict-your-app-to-a-set-of-users)

[Add app roles to your application and receive them in the token](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
