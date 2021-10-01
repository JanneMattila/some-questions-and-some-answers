# Azure Cosmos DB

## Region endpoints

When you create Cosmos DB account, it will create you endpoint like this `<account>.documents.azure.com`.
It's based on that region that you've deployed your account.
To verify you can use tools like `nslookup`, [Azure Datacenter IP Or No](https://github.com/JanneMattila/AzureDatacenterIPOrNo)
and [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/en-us/download/details.aspx?id=56519).

You should find correct IP block from the Azure IP Ranges and Service Tags file (here account is deployed to `North Europe`):

```json
  {
    "name": "AzureCosmosDB.NorthEurope",
    "id": "AzureCosmosDB.NorthEurope",
    "properties": {
      "changeNumber": 4,
      "region": "northeurope",
      "regionId": 17,
      "platform": "Azure",
      "systemService": "AzureCosmosDB",
      "addressPrefixes": [
        "13.69.226.0/25",
```

If you then enable multiple write locations for your account, then you need to take
additional steps in your app to take those into use. You technically will get additional
endpoints based on this naming: `<account>-<region>.documents.azure.com`.

Again if you do above lookups, you should find matching IP block (above account is enabled also to `West Europe`):

```json
  {
    "name": "AzureCosmosDB.WestEurope",
    "id": "AzureCosmosDB.WestEurope",
    "properties": {
      "changeNumber": 4,
      "region": "westeurope",
      "regionId": 18,
      "platform": "Azure",
      "systemService": "AzureCosmosDB",
      "addressPrefixes": [
        "13.69.66.0/25",
```

This is explained in more detailed in [here](https://docs.microsoft.com/en-us/azure/cosmos-db/graph/use-regional-endpoints#traffic-routing).

Few things to highlight from above documentation:

> Cosmos DB does not route traffic based on geographic proximity of the caller. It is up to each application to select the right region according to unique application needs.

> Cosmos DB Graph engine can accept write operation in read region by proxying traffic to write region. It is not recommended to send writes into read-only region as it increases traversal latency and is subject to restrictions in the future.

> Global database account CNAME always points to a valid write region. During server-side failover of write region, Cosmos DB updates global database account CNAME to point to new region. If application can't handle traffic rerouting after failover, it should use global database account DNS CNAME.

Cosmos DB SDKs have support for settting up application region. Here's C# example:

```csharp
var cosmosClient = new CosmosClient(
      "<your-account-connnection-string>",
      new CosmosClientOptions()
      {
          ApplicationRegion = Regions.EastUS2,
      });
```
