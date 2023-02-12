# Azure API Management

## Automation approach for APIM?

GitHub contains good summary in [Azure API Management DevOps Resource Kit](https://github.com/Azure/azure-api-management-devops-resource-kit).

There is video series about the resource kit in YouTube:

[How to build a CI/CD pipeline for API Management, Part 1](https://youtu.be/2x1CrzdTcL0)

[How to build a CI/CD pipeline for API Management, Part 2](https://youtu.be/PDOXI2E6zYA)

Resource kit contains tooling for extracting templates out from existing APIM.
Git clone the repo (or download it from releases) and then execute:

```powershell
dotnet run extract --extractorConfig extractorparams.json
```

See documentation about [Running the Extractor](https://github.com/Azure/azure-api-management-devops-resource-kit/blob/master/src/APIM_ARMTemplate/README.md#running-the-extractor).

**Note**: For Developer Portal automation refer to this documentation: [Migrate portal between services](https://github.com/Azure/api-management-developer-portal/wiki/Migrate-portal-between-services).
For alternative worklow based on PowerShell checkout this
[example](https://github.com/JanneMattila/329-azure-api-management-developer-portal)
for more details.

Here are other APIM ARM template examples:

- [APIM with 4 different APIs](https://github.com/JanneMattila/329-azure-api-management)
- [APIM and custom domain and sertificate](https://github.com/JanneMattila/329-azure-api-management-custom-domain)
- [APIM with Logic App backend](https://github.com/JanneMattila/329-azure-api-management-logic-app)

## I keep on getting CORS errors despite the CORS Policy. Have I missed something?

Lets assume that you have implemented following CORS Policy in your API at `Product` scope:

```xml
<cors>
    <allowed-origins>
        <origin>http://localhost:3268</origin>
    </allowed-origins>
    <allowed-methods>
        <method>GET</method>
    </allowed-methods>
</cors>
```

Then you have following code in your web app:

```html
<!DOCTYPE html>
<html>
<body>
  <script>
    fetch("https://yourinstancenamehere.azure-api.net/api/coolapi",
      {
        method: "GET",
        headers: {
          "Ocp-Apim-Subscription-Key": "1234567..." // Subscription key
        }
      })
      .then(response => {
        return response.json();
      })
      .then(data => {
        console.log(data);
      })
      .catch(error => {
        console.log(error);
      });
  </script>
</body>
</html>
```

You still get CORS error with following error message with `fetch`:

```bash
Access to fetch at 'https://yourinstancenamehere.azure-api.net/api/coolapi'
from origin 'http://localhost:3268' has been blocked by CORS policy:
Response to preflight request doesn't pass access control check:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
If an opaque response serves your needs, set the request's mode to
'no-cors' to fetch the resource with CORS disabled.
```

Or following error message if your app uses `XMLHttpRequest`:

```bash
Access to XMLHttpRequest at 'https://yourinstancenamehere.azure-api.net/api/coolapi'
from origin 'http://localhost:3268' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

But if you then change that subscription key from header to be at the url it suddenly works:

```js
fetch(api + "?subscription-key=" + key, //  WORKS
  {
    method: "GET",
    headers: {
      "Ocp-Apim-Subscription-Key": key // DOES NOT WORK
    }
  })
```

Underlying reason for this is the fact that browsers won't send custom
headers with CORS preflight request. Preflight request is done as `OPTIONS` request
([Preflight request](https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request)).

Above of course means that CORS Policy cannot work on `Product` scope **if** it's
passed in the header. It doesn't work since browser won't send custom subscription header
and therefore APIM cannot know the target `Product` and thus cannot process CORS policy
from that scope then. No CORS policy from APIM => CORS error at the browser.

Fix is of course pretty simple:

- Put CORS policy to other scope(s) (either `Global`, `API` or `API operation`)

**or**

- Pass subscription key in the url and not in the header

See also [I'm getting a CORS error when using the interactive console](https://aka.ms/apimdocs/portal/cors)
for more information.

## Policies

[Azure API Management Policy Snippets](https://github.com/Azure/api-management-policy-snippets)

## API Design guidelines

[Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)

[Designing APIs for microservices](https://docs.microsoft.com/en-us/azure/architecture/microservices/design/api-design)

[Web API design](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)

## Performance testing

You can use [artillery.io](https://artillery.io/) for your load testing.
Follow the instructions at the website to get it installed and then create your configuration file:

```yaml
config:
  target: "https://yourinstancenamehere.azure-api.net"
  phases:
    - duration: 10
      arrivalRate: 20
  defaults:
    headers:
      Ocp-Apim-Subscription-Key: yourkeyhere
      Content-Type: application/json; charset=utf-8
scenarios:
  - flow:
    - post:
        url: "/api/coolapi"
        json:
          type: "PerfTest"
          content: 
            id: 123
            name: "example data"
```

Above configuration will `POST` following payload to your api:

```json
{
  "type":"PerfTest",
  "content": {
    "id":123,
    "name":"example data"
  }
}
```

Execute the tests:

```bash
artillery run yourfile.yaml
```

## How do I expose my on-premise Web Service based API via APIM?

This is documented in separate repository. You can find it here:

[JanneMattila/325-apim-sb-demo](https://github.com/JanneMattila/325-apim-sb-demo)

In short: This demonstrates the use of Azure Relay and Hybrid Connections for
exposing on-premises Web Service based API.

## How can I limit certain API operations?

Scenario: You have API e.g. `users` which has 3 API Operations `GET`, `POST` and `DELETE`.
Now you want to limit these API Operations to two buckets: 

- `users-read` = `GET`
- `users-write` = `POST` and `DELETE`

**And** you don't want to implement any changes to the backend APIs.
You want to fully manage this in API Management. Backend trusts APIM,
so if API Management forwards request to `DELETE` resource
then it's valid request for the backend.

We can create `product` based on the above name but if we want to use same
method for other APIs as well then we can further use `groups` for these
kind of assignments. If we create groups for the above name we can
further assign these to `product` and `user`.
Using these assignments we can then validate if any of the conditions as true.

Here is example policy for validating if `users-write` is allowed.
This kind of policy you would use in `POST` and `DELETE` operations:

```xml
<policies>
  <inbound>
    <base />
    <!-- 
      Check if current operation is allowed:
      - Is current product "users-write"?
      - Has product group "users-write"?
      - Has user group "users-write"?
      If *any*  of the above is true then this operation is allowed
    -->
    <set-variable name="IsOperationAllowed" value="@(
      (context.Product != null && context.Product.Id =="users-write") ||
      (context.Product != null && context.Product.Groups.FirstOrDefault(g => g.Id =="users-write") != null) ||
      (context.User != null && context.User.Groups.FirstOrDefault(g => g.Id =="users-write") != null))" />
    <trace source="IsOperationAllowed" severity="verbose">
      <message>@(context.Variables.GetValueOrDefault<bool>("IsOperationAllowed").ToString())</message>
    </trace>
    <choose>
      <when condition="@(!context.Variables.GetValueOrDefault<bool>("IsOperationAllowed"))">
        <return-response>
          <set-status code="403" />
        </return-response>
      </when>
    </choose>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

## Securing APIs using Azure AD based auth

Relevant background info:

- [Protect an API in Azure API Management using OAuth 2.0 authorization with Azure Active Directory](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-protect-backend-with-aad)
- [Validate Azure Active Directory token](https://learn.microsoft.com/en-us/azure/api-management/api-management-access-restriction-policies#ValidateAAD)
- [Grant Graph API Permission to Managed Identity Object](https://techcommunity.microsoft.com/t5/integrations-on-azure-blog/grant-graph-api-permission-to-managed-identity-object/ba-p/2792127)

Create simple `mock` API with following policy:

```xml
<policies>
    <inbound>
        <base />
        <mock-response status-code="200" content-type="application/json" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

API does not require `subscription key`, so you can call it directly:

```bash
curl -s https://<your-api-management-instance>.azure-api.net/api/mock
```

Here is example response:

```json
{
  "data": "OK"
}
```

Add [validate-azure-ad-token](https://learn.microsoft.com/en-us/azure/api-management/api-management-access-restriction-policies#ValidateAAD):

```xml
<policies>
  <inbound>
    <validate-azure-ad-token tenant-id="{{aad-tenant-id}}">
      <client-application-ids>
        <application-id>{{aad-client-application-id}}</application-id>
      </client-application-ids>
      <audiences>
        <audience>{{aad-api-management-application-id}}</audience>
      </audiences>
    </validate-azure-ad-token>
    <base />
    <mock-response status-code="200" content-type="application/json" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

Response after adding `validate-azure-ad-token`:

```json
{ "statusCode": 401, "message": "Azure AD JWT not present" }
```

**NOTE**: It's **important** to further configure `client-application-ids`,
`audiences`, `required-claims`, `backend-application-ids` etc. elements to limit the access correctly.

You can now get `$ACCESS_TOKEN` which to use against the published API: 

```bash
# Service principal login example
az login --service-principal --username $APP_ID --password $PASSWORD --tenant $TENANT_ID --allow-no-subscriptions
# Managed identity login example
az login --identity --allow-no-subscriptions

# Target Azure AD App ID URI:
APIM_APP_ID_URI="api://<your-value-here>"

# Fetch access token
ACCESS_TOKEN=$(az account get-access-token --resource $APIM_APP_ID_URI --query accessToken -o tsv)
```

Validate `$ACCESS_TOKEN` in [jwt.ms](https://jwt.ms/) it should have `$APIM_APP_ID_URI` in `"aud"`:

```json
{
  // ...
  // "aud" should match $APIM_APP_ID_URI
  "aud": "api://<your-value-here>",
  // ...
}
```

Now you're ready to call the secured API:

```bash
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "https://<your-api-management-instance>.azure-api.net/api/mock"
```

If `$ACCESS_TOKEN` is still invalid, then you might get this error message:

```json
{ "statusCode": 401, "message": "Invalid Azure AD JWT" }
```

To further narrow down the access e.g., only allow assigned apps or certain scopes
then look this [example](./q&a/aad_app_service_and_s2s.md) for more details.

If you use `advanced` setup, then you might need to assign API permissions
to managed identity object. Here are instructions for that:
[Grant Graph API Permission to Managed Identity Object](https://techcommunity.microsoft.com/t5/integrations-on-azure-blog/grant-graph-api-permission-to-managed-identity-object/ba-p/2792127)

## Securing APIs using Azure AD Groups

Scenario: You want to limit Azure API Management API usage based on Azure AD Groups.

E.g., API operation `GET /clusters` is protected with one Azure AD Group
and `POST /clusters` is protected with another Azure AD Group.

For more details in Rest API usage see this [example](https://github.com/JanneMattila/api-examples/blob/master/azure/azure-ad-and-api-management.http).

You can use `validate-azure-ad-token` policy to protect you APIs.

You can use `required-claims` to validate `groups`, `roles` or both from the token for authorization.

If you want have `groups` claims in your token, you need to
enable that in `Token configuration -> "Add groups claim"` in your Azure AD app registration.

If you want have `roles` claims in your token, you need to
enable that in `App roles -> "Create app role"` in your Azure AD app registration.

Both above configurations require, that you go to `Enterprise applications` and 
set `Properties -> Assignment required: Yes` for your app, and then
add users/groups to the `Users and groups` to enable users to use this app.

Here is example token when you have enabled `roles` and `groups` in your app registration (see setup details [here](https://github.com/JanneMattila/api-examples/blob/master/azure/azure-ad-and-api-management.http)):

```json
{
  "aud": "api://api.jannemattila.com/apps/apim-gateway",
  // clipped
  "groups": [
    "cbad2229-507d-4d04-be80-6e6b66ea8e12"
  ],
  // clipped
  "roles": [
    "Users"
  ]
}
```

Here is example Azure API Management Policy if you want to validate `roles`
enabling access for `GET /clusters` (both roles are allowed to call the API):

```xml
<policies>
  <inbound>
    <validate-azure-ad-token tenant-id="{{aad-tenant-id}}">
      <client-application-ids>
        <application-id>{{aad-client-application-id}}</application-id>
      </client-application-ids>
      <audiences>
        <audience>{{aad-api-management-application-id}}</audience>
      </audiences>
      <required-claims>
        <claim name="roles" match="any">
          <value>Users</value>
          <value>Admins</value>
        </claim>
      </required-claims>
    </validate-azure-ad-token>
    <base />
    <mock-response status-code="200" content-type="application/json" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

Here is example Azure API Management Policy if you want to validate `groups`
enabling access for `GET /clusters` (both groups are allowed to call the API):

```xml
<policies>
  <inbound>
    <validate-azure-ad-token tenant-id="{{aad-tenant-id}}">
      <client-application-ids>
        <application-id>{{aad-client-application-id}}</application-id>
      </client-application-ids>
      <audiences>
        <audience>{{aad-api-management-application-id}}</audience>
      </audiences>
      <required-claims>
        <claim name="groups" match="any">
          <value>{{aad-group-id-users}}</value>
          <value>{{aad-group-id-admins}}</value>
        </claim>
      </required-claims>
    </validate-azure-ad-token>
    <base />
    <mock-response status-code="200" content-type="application/json" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

For matching `POST /clusters` API Operation you would then just remove `users`
from the allowed values list to enable only `admins` to call the API Operation:

```xml
<required-claims>
  <claim name="groups" match="any">
    <value>{{aad-group-id-admins}}</value>
  </claim>
</required-claims>
```

## Links

[A library of useful resources about Azure API Management](https://aka.ms/apimlove)