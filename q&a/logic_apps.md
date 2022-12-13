# Logic Apps

## Sharing API Connections between Logic Apps (Standard)

Scenario: You want to share API Connections between different Logic Apps

Background articles:

- [Set up DevOps deployment for Standard logic app workflows in single-tenant Azure Logic Apps](https://learn.microsoft.com/en-us/azure/logic-apps/set-up-devops-deployment-single-tenant-azure-logic-apps)
  - [API connection resources and access policies](https://learn.microsoft.com/en-us/azure/logic-apps/set-up-devops-deployment-single-tenant-azure-logic-apps?tabs=github#api-connection-resources-and-access-policies)
- [API connection resources and access policies](https://learn.microsoft.com/en-us/azure/logic-apps/set-up-devops-deployment-single-tenant-azure-logic-apps?tabs=github#api-connection-resources-and-access-policies)
- [Built-in connectors in Consumption versus Standard](https://learn.microsoft.com/en-us/azure/connectors/built-in#built-in-connectors-in-consumption-versus-standard)
- [Authorize OAuth connections](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-deploy-azure-resource-manager-templates#authorize-oauth-connections)
- [Azure DevOps sample for Logic Apps (Single-tenant)](https://github.com/Azure/logicapps/tree/master/azure-devops-sample)
- [GitHub sample for Logic Apps (Single-tenant)](https://github.com/Azure/logicapps/tree/master/github-sample)

### Built-in connectors

Built-in connectors and their configuration live inside Logic App (Standard),
so it does not have "Azure Resources" visible in the resource group.

If you want to share these configuration, then here's what you can do:

- Use Key vault for storing connection related information
- Use [Key Vault references](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references?tabs=azure-cli) to
  pull secrets to Logic App (Standard)
  [App Settings](https://learn.microsoft.com/en-us/azure/logic-apps/edit-app-settings-host-settings?tabs=azure-portal#app-settings-parameters-and-deployment)
- Use app setting in your `connections.json` file

Example `connections.json` file that retrieves table storage endpoint from app settings:

```json
{
  "serviceProviderConnections": {
    "azureTables": {
      "parameterValues": {
        "tableStorageEndpoint": "@appsetting('azureTables_tableStorageEndpoint')",
        "authProvider": {
          "Type": "ManagedServiceIdentity"
        }
      },
      "serviceProvider": {
        "id": "/serviceProviders/azureTables"
      },
      "displayName": "table"
    }
  }
}
```

Using above method you can share connection related information for
built-in connectors in same Key Vault.

### Managed API Connectors

Managed API Connectors are represented as Azure resources in resource groups.

Important note about sharing API Connections from [here](https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-deploy-azure-resource-manager-templates#authorize-oauth-connections):

> If you're considering sharing API connections, make sure that your solution can handle
> **potential throttling problems**. Throttling happens at the connection level, 
> so reusing the same connection across multiple logic apps might increase
> the potential for throttling problems.

[Handle throttling problems (429 - "Too many requests" errors) in Azure Logic Apps](https://learn.microsoft.com/en-us/azure/logic-apps/handle-throttling-problems-429-errors)

---

Here is example walk-through, how you can setup sharing of Key vault API Connection from
another resource group (or subscription) and share it between Logic App (Standard) applications.

Resource groups in this walk-through:

- `rg-logic-apps`
  - `App Service plan` infrastructure resource for Logic App (Standard)
  - Logic App (Standard) resource for the integration
    - Uses API Connection from `rg-integration-shared`
    - System assigned managed identity is enabled
- `rg-integration-shared`
  - Key vault resource
    - Has `secret1` named secret created
  - `keyvault` API Connection resource

Create Key vault to the `rg-integration-shared` resource group and then create
Key vault API Connection using example ARM template
(replace `<INSERT_LOCATION_HERE>`, `<INSERT_KEY_VAULT_NAME_HERE>` and `<INSERT_SUBSCRIPTION_ID_HERE>` with your own values):

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Web/connections",
      "apiVersion": "2016-06-01",
      "name": "keyvault-shared",
      "location": "<INSERT_LOCATION_HERE>",
      "kind": "V2",
      "properties": {
        "displayName": "keyvault-shared",
        "statuses": [
          {
              "status": "Ready"
          }
        ],
        "customParameterValues": {},
        "alternativeParameterValues": {
          "vaultName": "<INSERT_KEY_VAULT_NAME_HERE>"
        },
        "parameterValueType": "Alternative",
        "createdTime": "2022-12-12T07:57:12.2824593Z",
        "changedTime": "2022-12-12T07:57:12.2824593Z",
        "api": {
          "name": "keyvault",
          "displayName": "Azure Key Vault",
          "description": "Azure Key Vault is a service to securely store and access secrets.",
          "iconUri": "https://connectoricons-prod.azureedge.net/releases/v1.0.1597/1.0.1597.3005/keyvault/icon.png",
          "brandColor": "#0079d6",
          "id": "/subscriptions/<INSERT_SUBSCRIPTION_ID_HERE>/providers/Microsoft.Web/locations/westcentralus/managedApis/keyvault",
          "type": "Microsoft.Web/locations/managedApis"
        },
        "testLinks": []
      }
    }
  ]
}
```

Add your Logic App (Standard) application to the API Connection Access Policies:

![API Connection access policy for Logic App resource](https://user-images.githubusercontent.com/2357647/207281403-0f52b77b-e9db-43c2-9822-d8a5790ef8ba.png)

In your Logic App (Standard) you need to update 2 places to use Key Vault via above API Connection:

1. Update `connections.json` to use API Connection fron another resource group (or subscription):

```json
{
  "serviceProviderConnections": {
    // ...
  },
  "managedApiConnections": {
    "keyvault": {
      "api": {
        "id": "/subscriptions/<INSERT_SUBSCRIPTION_ID_HERE>/providers/Microsoft.Web/locations/<INSERT_LOCATION_HERE>/managedApis/keyvault"
      },
      "connection": {
        "id": "/subscriptions/<INSERT_SUBSCRIPTION_ID_HERE>/resourceGroups/rg-integration-shared/providers/Microsoft.Web/connections/keyvault-shared"
      },
      "connectionRuntimeUrl": "<INSERT_YOUR_API_CONNECTION_RUNTIME_URL_HERE>",
      "connectionProperties": {
        "authentication": {
          "audience": "https://vault.azure.net",
          "type": "ManagedServiceIdentity"
        }
      },
      "authentication": {
        "type": "ManagedServiceIdentity"
      }
    }
  }
}
```

2. Update your Logic App workflow to use correct connection by updating `referenceName`:

```json
{
  // ...
  // "Get secret" action in workflow connecting to Key vault:
  "Get_secret": {
      "inputs": {
          "host": {
              "connection": {
                  "referenceName": "keyvault"
              }
          },
          "method": "get",
          "path": "/secrets/@{encodeURIComponent('secret1')}/value"
      },
      "runAfter": {},
      "type": "ApiConnection"
  },
  // ...
}
```

Note: You need to use code view to update that connection name.

Important note: If you don't have access rights to that target subscription
for accessing API Connection, then you cannot edit that workflow in portal,
because it will fail for following error:

> **Failed to save workflow.**
> Some of the connections are not authorized yet. 
> If you just created a workflow from a template,
> please add the authorized connections to your workflow before saving.
