# Application Insights & Telemetry

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
