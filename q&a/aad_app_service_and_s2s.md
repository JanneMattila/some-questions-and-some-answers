# App Service authentication and service-to-service integration

Scenario:
- You have backend API in app service and you want to secure it using Azure AD authentication
- You have one or more daemon services using that backend API
- Developers creating the actual backend code can run their implementation
  locally without authentication setup
- You want to separate the responsibilities between
  developers and admins who grant access between
  these two different services
- You want to introduce authentication when deploying
  the application to Azure (not before)

We can implement above scenario using following steps:

1. Register backend application: `CloudBackend`
    - Application ID URI: `api://cloudbackend`
2. Add application role to `CloudBackend` (which we can later assign to our client application)
    - Display name: `Writers`
    - Allower member types: either `Applications` or `Both (Users/Groups + Applications)`
    - Value: `Task.Write`
    - Description: `Task.Write description text`
3. Require user assignment to this application
    - Under *"Enterprise Application"* blade find `CloudBackend`
    - Under properties set `User assignment required?` to `Yes`
4. Register client application: `CloudBackend Client`
5. Configure API permissions for `CloudBackend Client`
    - Add `CloudBackend` -> `Task.Write`
6. API permission is `Type: Application` and therefore admin consent is required
    - You can delegate the consent management to users
      in Azure AD built-in role [Cloud Application Administrator](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#cloud-application-administrator) (or role with similar permissions)
7. Use `CloudBackend` in app service authentication settings
    - Client ID = `CloudBackend` application (client) ID
    - Issuer Url = `https://sts.windows.net/{{tenant}}/`
    - Allowed Token Audiences = `CloudBackend` application ID URI (`api://cloudbackend`)

Lets see how this works in action. Here are the variables:

- `clientID` = `CloudBackend Client` application (client) ID
- `clientSecret` = `CloudBackend Client`  client secret
- `resourceAppIdURI` = `CloudBackend` application ID URI (`api://cloudbackend`)
- `tenant` = Azure AD tenant identifier

`CloudBackend Client` requests access token from Azure AD:

```HTTP
POST https://login.microsoftonline.com/{{tenant}}/oauth2/v2.0/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded

client_id={{clientID}}
&client_secret={{clientSecret}}
&scope={{resourceAppIdURI}}/.default
&grant_type=client_credentials
```

You might get following error message:

```json
{
 "error": "invalid_grant",
  "error_description": "AADSTS501051: Application '{{clientID}}'
  (CloudBackend Client) is not assigned to a role for the application 'api://cloudbackend'(CloudBackend).\r\n
  Trace ID: f255b072-3a51-4deb-a6b6-996fcebb8101\r\n
  Correlation ID: f319b6c3-16a4-46dd-bf90-ac85c936cb72\r\n
  Timestamp: 2021-03-24 08:06:01Z",
   "error_codes": [
     501051
   ],
   "timestamp": "2021-03-24 08:06:01Z",
   "trace_id": "f255b072-3a51-4deb-a6b6-996fcebb8101",
   "correlation_id": "f319b6c3-16a4-46dd-bf90-ac85c936cb72",
   "error_uri": "https://login.microsoftonline.com/error?code=501051"
 }
```

Above means that you might not have assigned role correctly or then consent is missing.

This should be the correct response:

```json
{
 "token_type": "Bearer",
 "expires_in": 3599,
 "ext_expires_in": 3599,
 "access_token": "eyJ0eXAi...sZgqIbn7g"
}
```

If you grab `access_token` from above and put it to [jwt.ms](https://jwt.ms/)
to analyze the content of the token:

```json
{
  "aud": "api://cloudbackend",
  "iss": "https://sts.windows.net/{{tenant}}/",
  "iat": 1616585328,
  "nbf": 1616585328,
  "exp": 1616589228,
  "aio": "E2ZgYJhTGP4iKuZ/BOPUo4943+zKBwA=",
  "appid": "{{clientID}}",
  "appidacr": "1",
  "idp": "https://sts.windows.net/{{tenant}}/",
  "oid": "c18eb113-8ede-4317-b986-93c54ce20991",
  "rh": "0.AQwAFaLG6jeSrUCB7sptVBQGkZZ_xDYzLIlDhK7DWMj_xvMMAAA.",
  "roles": [
    "Task.Write"
  ],
  "sub": "c18eb113-8ede-4317-b986-93c54ce20991",
  "tid": "{{tenant}}",
  "uti": "YEDcVJttIUKUL7GfmGK5AA",
  "ver": "1.0"
}
```

Important part is this:

```json
{
...
  "roles": [
    "Task.Write"
  ],
...
}
```

`CloudBackend Client` can now use above token for accessing `CloudBackend`:

```HTTP
GET https://<yourbackendapi>.azurewebsites.net/api/tasks
Authorization: Bearer eyJ0eXAi...sZgqIbn7g
```

It's important to understand how [authentication and authorization in Azure App Service and Azure Functions](https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization) works.

If you expose multiple APIs from the same backend application, and your want to
limit API usage per API specific role(s), then you need validate the claims
inside the APIs:

[Access user claims](https://docs.microsoft.com/en-us/azure/app-service/app-service-authentication-how-to#access-user-claims)

[User/Application claims](https://docs.microsoft.com/en-us/azure/app-service/overview-authentication-authorization#userapplication-claims)

Here is example Azure Functions code snippet for illustration purposes:

```csharp
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

public static IActionResult Run(HttpRequest req, ClaimsPrincipal principal)
{
  if (principal.HasClaim("roles", "Task.Write"))
  {
    return new OkResult();
  }
  return new UnauthorizedResult();
}
```

This enables you to do following mapping for roles and permissions:

`/api/sales` => `Sales.Read`

`/api/products` => `Products.Read`

This lets you do very fine-grained authorization.

### Links

[Daemon client application (service-to-service calls)](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad#daemon-client-application-service-to-service-calls)

[Admin-restricted permissions](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent?WT.mc_id=Portal-Microsoft_AAD_RegisteredApps#admin-restricted-permissions)

[Validating tokens](https://docs.microsoft.com/en-us/azure/active-directory/develop/access-tokens#validating-tokens)
