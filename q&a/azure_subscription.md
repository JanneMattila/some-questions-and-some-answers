# Azure Subscription

## Subscription created activity log entry

```json
{
  "authorization": {},
  "channels": "Operation",
  "claims": {
    "principalOid": "Service:StateAndNameUpdate",
    "principalPuid": ""
  },
  "correlationId": "73cee831-aaad-45e4-87e5-ad65391a0944",
  "description": "",
  "eventDataId": "56f8652c-99fb-44cf-94e3-a805c37f1ec1",
  "eventName": {
    "value": "Create",
    "localizedValue": "Create"
  },
  "category": {
    "value": "Administrative",
    "localizedValue": "Administrative"
  },
  "eventTimestamp": "2022-09-16T08:08:11.1822217Z",
  "id": "/providers/Microsoft.Management/managementGroups/{tenant_id}/events/56f8652c-99fb-44cf-94e3-a805c37f1ec1/ticks/637989124911822217",
  "level": "Informational",
  "operationId": "98f4d352-5490-488d-b052-65ad3d76016d",
  "operationName": {
    "value": "Microsoft.Management",
    "localizedValue": "Microsoft.Management"
  },
  "resourceGroupName": "",
  "resourceProviderName": {
    "value": "Microsoft.Management",
    "localizedValue": "Microsoft.Management"
  },
  "resourceType": {
    "value": "Microsoft.Management/managementGroups",
    "localizedValue": "Microsoft.Management/managementGroups"
  },
  "resourceId": "/providers/Microsoft.Management/managementGroups/{tenant_id}",
  "status": {
    "value": "Succeeded",
    "localizedValue": "Succeeded"
  },
  "subStatus": {
      "value": "",
      "localizedValue": ""
  },
  "submissionTimestamp": "2022-09-16T08:09:48.0846742Z",
  "subscriptionId": "",
  "tenantId": "{tenant_id}",
  "properties": {
    "entity": "{tenant_id}",
    "message": "Entity {subscription_id} is created with parent entity {tenant_id}",
    "hierarchy": "{tenant_id}"
  },
  "relatedEvents": []
}
```