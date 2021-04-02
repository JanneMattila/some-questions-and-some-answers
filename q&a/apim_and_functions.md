# Azure API Management and Functions

## Timeouts ands APIs

```
        /------\     /-------\
Client  | API  |     | AZURE |
  =>    | MGMT |  => | FUNC  |
        \------/     \-------/
```

In above scenario you might have timeouts in following steps:

- Client request timeout against the API Management
- API Management request timeout againts backend API

For demonstration purposes lets use following Function implementation:

```csharp
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;

static public class WaiterFunction
{
  [FunctionName("WaiterFunction")]
  static public IActionResult Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "waiter/{timeout}")]
    HttpRequest req,
    ILogger log,
    int timeout)
  {
    log.LogInformation("C# HTTP trigger function processed a request.");
    var start = DateTime.UtcNow;
    var end = DateTime.UtcNow.AddSeconds(timeout);
    while (DateTime.UtcNow < end &&
          !req.HttpContext.RequestAborted.IsCancellationRequested)
    {
      Thread.SpinWait(1_000_000);
    }
    
    log.LogInformation($"OK: {timeout} - {(DateTime.UtcNow - start).TotalSeconds} - {req.HttpContext.RequestAborted.IsCancellationRequested}");
    return new OkObjectResult($"OK: {timeout} - {(DateTime.UtcNow - start).TotalSeconds} - {req.HttpContext.RequestAborted.IsCancellationRequested}");
  }
}
```

It just waits in `SpinWait` for the duration that has been requested from it. 
It also returns waited time and if [request has been aborted](https://docs.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.http.httpcontext.requestaborted) (client has disconnected).

Then we expose this Function using Azure API Management and set following [forward-request](https://docs.microsoft.com/en-us/azure/api-management/api-management-advanced-policies#ForwardRequest) policy to it:

```xml
<policies>
  <inbound>
    <base />
  </inbound>
  <backend>
    <forward-request timeout="10" />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

Above policy sets timeout for 10 seconds for the backend requests.

Now we can simulate our client using simple PowerShell command where we can
control client request timeout and functions processing time:

```powershell
Invoke-RestMethod -DisableKeepAlive -Uri "https://<yourapim>.azure-api.net/backend/waiter/3" -TimeoutSec 6
```

Let's define variables:

- <code>T<sub>Client</sub></code> = Client request timeout
- <code>T<sub>APIM</sub></code> = API Management `forward-request` timeout
- <code>T<sub>Func</sub></code> = Functions processing time

If you test this setup with different variable values, you'll see following:

| Scenario                                                                                                                          | Outcome                           |
| --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| <code>T<sub>Client</sub></code> < others timeouts | Client request timeouts, APIM logs `ClientConnectionFailure: at forward-request`, and func processes the request to the end  |
| <code>T<sub>APIM</sub></code> < <code>T<sub>Func</sub></code> < <code>T<sub>Client</sub> | APIM returns status code 500 to the client and logs `Timeout: at forward-request` and func processes the request to the end  |
| <code>T<sub>Func</sub></code> < <code>T<sub>APIM</sub></code> < <code>T<sub>Client</sub> | Client receives data successfully  |

In the client you'll get following message if you hit the <code>T<sub>Client</sub></code> limit:

```powershell
Invoke-RestMethod: The request was canceled due to the configured HttpClient.Timeout of 8 seconds elapsing.
```

In the client you'll get following message if you hit the <code>T<sub>APIM</sub></code> limit:

```powershell
Invoke-RestMethod: { "statusCode": 500, "message": "Internal server error", "activityId": "87aeb87f-192c-424c-84d1-32d5bbfec437" }
```

Application Insights shows this as exception when you hit the <code>T<sub>Client</sub></code> limit:

```
Exception Properties
  Event time	4/1/2021, 8:35:07 PM (Local time)	
  Message	The operation was canceled.	
  Exception type	ClientConnectionFailure	
  Failed method	forward-request	
Custom Properties
  Service Type	API Management	
  Service Name	<yourapiminstance>.azure-api.net	
  Region	North Europe
```

Callstack of exception:

```
ClientConnectionFailure:
  at forward-request
```

Application Insights shows this as exception when you hit the <code>T<sub>APIM</sub></code> limit:

```
Exception Properties
  Event time	4/1/2021, 9:13:06 PM (Local time)
  Message	Request to the backend service timed out
  Exception type	Timeout	
  Failed method	forward-request	
Custom Properties
  Service Type	API Management	
  Service Name	<yourapiminstance>.azure-api.net	
  Region	North Europe
```

Callstack of exception:

```
Timeout:
  at forward-request
```

Here are few screenshots from Applicaiton Insights:

- when process ran successfully

![Process ran successfully in 6 seconds](https://user-images.githubusercontent.com/2357647/113421052-1551d880-93d3-11eb-8d4e-14339f437810.png)

- when client has disconnected

![ClientConnectionFailure](https://user-images.githubusercontent.com/2357647/113419924-12ee7f00-93d1-11eb-98b2-396484a81a0b.png)

- when `forward-request` timeout limit has been hit

![Azure Functions continues to run the process to the end](https://user-images.githubusercontent.com/2357647/113420604-47af0600-93d2-11eb-8049-08edcda32dda.png)

Note: If you locally test Azure Functions and try out the customer disconnect
scenario then you'll notice that `req.HttpContext.RequestAborted.IsCancellationRequested`
is set. However, if you deploy this to App Service then that request is not cancelled.
Therefore, even if APIM disconnects from backend, it does not stop the processing of the 
Azure Functions.
