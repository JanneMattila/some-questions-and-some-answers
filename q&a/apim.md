# Azure API Management

## Automation approach for APIM?

GitHub contains good summary in [Azure API Management DevOps Resource Kit](https://github.com/Azure/azure-api-management-devops-resource-kit).

There is video series about the resource kit in YouTube:

[How to build a CI/CD pipeline for API Management, Part 1](https://youtu.be/2x1CrzdTcL0)

[How to build a CI/CD pipeline for API Management, Part 2](https://youtu.be/PDOXI2E6zYA)

**Note**: For Developer Portal automation refer to this documentation: [Migrate portal between services](https://github.com/Azure/api-management-developer-portal/wiki/Migrate-portal-between-services).

## I keep on getting CORS issues. Have I missed something?

Lets assume that you have enabled following CORS Policy in your API at `Product` scope:

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

Above of course means that CORS Policy cannot work on `Product` scope if it's
passed in the header. And since browser won't send custom headers
APIM cannot know what is that `Product` and cannot process that CORS policy.

Fix of course is pretty simple: Either put policy to other scopes
(Global, API or API operation) **or** then pass it in the url instead of the header.

## Policies

[Azure API Management Policy Snippets](https://github.com/Azure/api-management-policy-snippets)

## API Design guidelines

[Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)

[Designing APIs for microservices](https://docs.microsoft.com/en-us/azure/architecture/microservices/design/api-design)

[Web API design](https://docs.microsoft.com/en-us/azure/architecture/best-practices/api-design)

## Links

[A library of useful resources about Azure API Management](https://aka.ms/apimlove)

## How do I expose my on-premise Web Service based API via APIM?

This is documented in separate repository. You can find it here:

[JanneMattila/325-apim-sb-demo](https://github.com/JanneMattila/325-apim-sb-demo)

In short: This demonstrates the use of Azure Relay and Hybrid Connections for
exposing on-premises Web Service based API.
