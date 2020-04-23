# Application Insights & Telemetry

## Rest API

You can study Application Insights [Bond schemas](https://microsoft.github.io/bond/)
for more
[details](https://github.com/microsoft/ApplicationInsights-Home/tree/master/EndpointSpecs/Schemas/Bond)
and
[endpoint protocol](https://github.com/microsoft/ApplicationInsights-Home/blob/master/EndpointSpecs/ENDPOINT-PROTOCOL.md)
but below are some examples that make it more concrete.

**Note**: Get yourself [Visual Studio Code](https://code.visualstudio.com/)
and [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension and save
below snippet to e.g. `AppInsights.http`. Then you can more easily
test those APIs by pressing "Send Request":

![Send Request in rest client](https://user-images.githubusercontent.com/2357647/80068327-17b37d80-8548-11ea-8995-832c9e830c53.png)

```rest
@endpoint = https://dc.services.visualstudio.com/v2/track
@ikey = your_intrumentation_key_from_azure_portal
@roleInstance = myserver
@sdk = mydemo:1.0.0

### Post single event:
# Matching .NET code:
#   var client = new TelemetryClient
#   {
#     InstrumentationKey = "key"
#   };
#   client.TrackEvent("PageView");
POST {{endpoint}} HTTP/1.1
Content-Type: application/json

{
  "name": "Event",
  "time": "{{$datetime iso8601}}",
  "iKey": "{{ikey}}",
  "tags": {
    "ai.cloud.roleInstance": "{{roleInstance}}",
    "ai.internal.sdkVersion": "{{sdk}}"
  },
  "data": {
    "baseType": "EventData",
    "baseData": {
      "ver":2,
      "name": "PageView"
    }
  }
}

### Post single event with additional properties:
# Matching .NET code:
#   client.TrackEvent("PageView",
#     new Dictionary<string, string>()
#     {
#       { "Server", "ABC123" },
#       { "Service", "SVC12345" }
#     });
POST {{endpoint}} HTTP/1.1
Content-Type: application/json

{
  "name": "Event",
  "time": "{{$datetime iso8601}}",
  "iKey": "{{ikey}}",
  "tags": {
    "ai.cloud.roleInstance": "{{roleInstance}}",
    "ai.internal.sdkVersion": "{{sdk}}"
  },
  "data": {
    "baseType": "EventData",
    "baseData": {
      "ver":2,
      "name": "PageView",
      "properties": {
        "Server": "ABC123",
        "Service": "SVC12345"
      }
    }
  }
}

### Post single event with additional properties and metrics:
# Matching .NET code:
#   client.TrackEvent("PageView",
#     new Dictionary<string, string>()
#     {
#       { "Server", "ABC123" },
#       { "Service", "SVC12345" }
#     },
#     new Dictionary<string, double>()
#     {
#       { "Level", level }
#     });
POST {{endpoint}} HTTP/1.1
Content-Type: application/json

{
  "name": "Event",
  "time": "{{$datetime iso8601}}",
  "iKey": "{{ikey}}",
  "tags": {
    "ai.cloud.roleInstance": "{{roleInstance}}",
    "ai.internal.sdkVersion": "{{sdk}}"
  },
  "data": {
    "baseType": "EventData",
    "baseData": {
      "ver":2,
      "name": "PageView",
      "properties": {
        "Server": "ABC123",
        "Service": "SVC12345"
      },
      "measurements": {
        "Level": 62.49
      }
    }
  }
}

### Post single exception with properties:
# Matching .NET code:
#   var ex = new ContosoRetailBackendException(
#    "Retail SBT Backend is not responding. " +
#    "Please follow these instructions next: " +
#    "https://bit.ly/ContosoITRetailSBTBackend");
#   client.TrackException(ex, new Dictionary<string, string>()
#   {
#     { "DataKey", "ABCDEF" },
#     { "NodeKey", "1234567890" }
#   });
POST {{endpoint}} HTTP/1.1
Content-Type: application/json

{
  "name": "Exception",
  "time": "{{$datetime iso8601}}",
  "iKey": "{{ikey}}",
  "tags": {
    "ai.cloud.roleInstance": "{{roleInstance}}",
    "ai.internal.sdkVersion": "{{sdk}}"
  },
  "data": {
    "baseType": "ExceptionData",
    "baseData": {
      "ver":2,
      "exceptions":
      [
        {
          "id": 9799115,
          "outerId":0,
          "typeName": "ContosoRetailBackendException",
          "message": "Retail SBT Backend is not responding. Please follow these instructions next: https://bit.ly/ContosoITRetailSBTBackend",
          "hasFullStack": true
        }
      ],
      "properties": {
        "DataKey": "ABCDEF",
        "NodeKey": "1234567890"
      }
    }
  }
}

### Post multiple events using line-delimited json:
# Matching .NET code:
#   client.TrackEvent("PageView");
#   client.TrackEvent("PageView");
#   client.TrackEvent("PageView");
#   client.Flush();
POST {{endpoint}} HTTP/1.1
Content-Type: x-json-stream

{"name":"Event","time":"{{$datetime iso8601}}","iKey":"{{ikey}}","tags":{"ai.cloud.roleInstance":"{{roleInstance}}","ai.internal.sdkVersion":"{{sdk}}"},"data":{"baseType":"EventData","baseData":{"ver":2,"name":"PageView"}}}
{"name":"Event","time":"{{$datetime iso8601}}","iKey":"{{ikey}}","tags":{"ai.cloud.roleInstance":"{{roleInstance}}","ai.internal.sdkVersion":"{{sdk}}"},"data":{"baseType":"EventData","baseData":{"ver":2,"name":"PageView"}}}
{"name":"Event","time":"{{$datetime iso8601}}","iKey":"{{ikey}}","tags":{"ai.cloud.roleInstance":"{{roleInstance}}","ai.internal.sdkVersion":"{{sdk}}"},"data":{"baseType":"EventData","baseData":{"ver":2,"name":"PageView"}}}
```

## How can I pass additional information to Ops or Support teams in case of failure?

Scenario: In your application code you have hard dependency
to some other 3rd party service. If that fails you want to pass as much
additional information to the Ops or Support teams as you can so that they can
act accordingly (or similar scenario when you want to pass some guidance forward).

Here is one example solution. It has following parts:

1. Custom exception for this scenario.
2. Use `TelemetryClient` for reporting this exception with additional instructions
3. Use `KQL` in Azure to find exception
4. Create necessary alerts based on selected queries

### Step 1: Custom exception

Here simple custom exception `ContosoRetailBackendException`:

```csharp
using System;
using System.Runtime.Serialization;

[Serializable]
public class ContosoRetailBackendException : Exception
{
    public ContosoRetailBackendException() { }
    public ContosoRetailBackendException(string message) : base(message) { }
    public ContosoRetailBackendException(
        string message, Exception inner) : base(message, inner) { }
    protected ContosoRetailBackendException(
        SerializationInfo info,
        StreamingContext context) : base(info, context) { }
}
```

### Step 2: Use custom exception with TelemetryClient

You can add as much additional information to the custom
exceptions as you like but one possible information
piece is link to additional instruction available for them
(of course your link can be internal SharePoint or anything like that.
It doesn't have to be public document):

```csharp
var ex = new ContosoRetailBackendException(
  "Retail SBT Backend is not responding. " +
  "Please follow these instructions next: " +
  "https://bit.ly/ContosoITRetailSBTBackend");

var client = new TelemetryClient();
client.TrackException(exception, new Dictionary<string, string>()
{
  { "DataKey", "ABCDEF" },
  { "NodeKey", "1234567890" }
});

client.Flush();
```

### Step 3: Find this data in App Insights

You can now find above exception using this query:

```sql
exceptions
| where type == "ContosoRetailBackendException"
```

You can directly see from data that all the additional data elements are part of the
log content **including the link**:
![ContosoRetailBackendException in log data](https://user-images.githubusercontent.com/2357647/76893966-e8995480-6895-11ea-8652-b8674eaa6fe3.png)

### Step 4: Create alerts

**TO BE ADDED** Step-by-step instructions.

In your alert email you'll also have the same data elements visible:

![alert email](https://user-images.githubusercontent.com/2357647/76894274-87be4c00-6896-11ea-94c8-0d5244294380.png)

This makes it easy for people to find correct troubleshooting
documents right from the alert notification.

**TO BE ADDED** User identity mapping, Exceptions with links, etc.
