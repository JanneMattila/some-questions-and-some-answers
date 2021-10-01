# Maintain Enterprise application user assignments automatically

Scenario:
- You have Azure AD Enterprise Application `Target App`
- You have  set `User assignment required?` to `Yes`
- You want to maintain the list of user assignments elsewhere
- You synchronize the user assignments to this Enterprise Application

We can implement above scenario using following steps:

1. Register application: `Maintainer App`
- Add following `Application` permissions: `Application.ReadWrite.OwnedBy` and `Directory.Read.All`
- [Application.ReadWrite.OwnedBy](aad_automations.md#applicationreadwriteownedby-permission) is
required for managing applications that this applications owns
- [Directory.Read.All]() is required because this application has to find users
and groups from the directory

2. Grant admin consent for above permissions

3. Add `Maintainer App` to be one of the owners of `Target App`
- As of now, there isn't user interface for this in Azure Portal. There is example below in Rest API.

4. Now `Maintainer App` can maintain users in the synchronization process

## Walkthrough

Here's is step-by-step walkthrough using VS Code Rest Client extension format.

First acquire token for your `Maintainer App`:

```
@clientID = <Maintainer App - AppId>
@clientSecret = <Maintainer App - Client Secret>
@tenant = <Your Tenant ID>
@endpoint = https://graph.microsoft.com/beta

### Get token
# @name tokenResponse
POST https://login.microsoftonline.com/{{tenant}}/oauth2/v2.0/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded

client_id={{clientID}}
&client_secret={{clientSecret}}
&scope=https://graph.microsoft.com/.default
&grant_type=client_credentials
```

Grab received token and verify that you have correct roles. Use [jwt.ms](https://jwt.ms/).
You should see these `roles`:

```json
{
  // ...
  "roles": [
    "Application.ReadWrite.OwnedBy",
    "Directory.Read.All"
  ],
  //  ...
}
```

Find `Target App` and assign user to it:

```
### Search "Target App" servicePrincipal
# @name targetServicePrincipalList
GET {{endpoint}}/servicePrincipals?$filter=displayName eq 'Target App' HTTP/1.1
Content-type: application/json
Authorization: Bearer {{tokenResponse.response.body.access_token}}

### Add new user to "Target App"
POST {{endpoint}}/servicePrincipals/{{targetServicePrincipalList.response.body.value[0].id}}/appRoleAssignedTo HTTP/1.1
Content-type: application/json
Authorization: Bearer {{tokenResponse.response.body.access_token}}

{
  "principalId": "<this should be user object id or group object id>",
  "resourceId": "{{targetServicePrincipalList.response.body.value[0].id}}",
  "appRoleId": "00000000-0000-0000-0000-000000000000"
}
```

If you get following error:

```json
{
"error": {
  "code": "Authorization_RequestDenied",
  "message": "Insufficient privileges to complete the operation.",
  "innerError": {
    "date": "2021-10-01T15:29:50",
    "request-id": "15f1fe47-c5c5-40fb-abe5-3718678337b6",
    "client-request-id": "b17ec1c0-5bae-4786-b33c-fec70cf15281"
  }
}
```

Then please verify that `Maintainer App` is owner of `Target App` in the Azure AD
Enterprise Applications view.

You can do the owner assignment using these steps:

1. Login using account that has permissions to edit `Target App`
2. Grab token using Azure CLI

```bash
az account get-access-token --resource https://graph.microsoft.com/ --query accessToken -o tsv
```

```
### Search "Maintainer App" servicePrincipal
# @name maintainerServicePrincipalList
GET {{endpoint}}/servicePrincipals?$filter=displayName eq 'Target App' HTTP/1.1
Content-type: application/json
Authorization: Bearer {{tokenResponse.response.body.access_token}}

### Add "Maintainer App" to be owner of "Target App"
POST {{endpoint}}/servicePrincipals/{{targetServicePrincipalList.response.body.value[0].id}}/owners/$ref
Content-type: application/json
Authorization: Bearer <Your-Token-From-Azure-CLI>

{
  "@odata.id": "{{maintainerServicePrincipalList.response.body.value[0].@odata.id}}"
}
```

Note: VS Code Rest Client extension does not like variable names with `@` or `.`. 
Example value for the above `@data.id` is:

```
https://graph.microsoft.com/v2/<YourTenantID/directoryObjects/<YourServicePrincilaObjectId>/Microsoft.DirectoryServices.ServicePrincipal
```
