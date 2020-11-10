# KQL

## Logic App

Find different metrics you have in your workspace:

```sql
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| distinct MetricName
```

If you further want to analyze e.g. `ActionLatency`:

```sql
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where MetricName == "ActionLatency"
| take 10
```

Your results contains multiple columns but here are most interesting ones for this scenario:

| MetricName    | Count | Maximum | Minimum | Average     | TimeGrain |
|---------------|-------|---------|---------|-------------|-----------|
| ActionLatency | 12    | 3.875   | 0.062   | 2.224916667 | PT1M      |

Then you can further analyze the data:

```sql
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where MetricName == "ActionLatency"
| project MetricName, Count, Maximum, Minimum, TimeGenerated
| summarize max(Maximum), min(Minimum) by bin(TimeGenerated, 1m), MetricName
```

Example output:

| TimeGenerated        | MetricName    | max_Maximum | min_Minimum |
|----------------------|---------------|-------------|-------------|
| 2020-08-28T06:44:00Z | ActionLatency | 3.875       | 0.062       |
| 2020-08-28T07:00:00Z | ActionLatency | 1.421       | 0.015       |
| 2020-08-28T07:01:00Z | ActionLatency | 2.937       | 2.828       |

You can then use use different charting capabilites to visualize the data:

```sql
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where MetricName == "ActionLatency"
| project MetricName, Maximum, TimeGenerated
| summarize max(Maximum) by bin(TimeGenerated, 1m), MetricName
| project Max=max_Maximum, TimeGenerated
| render timechart
```

Combining multiple metrics to single chart can be done in following manner:

```sql
let MaxLatency=
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where MetricName == "ActionLatency"
| project Maximum, TimeGenerated, MetricName=strcat("Max ", MetricName)
| summarize max(Maximum) by bin(TimeGenerated, 1m), MetricName
| project Value=max_Maximum, TimeGenerated, MetricName;
let MinLatency=
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where MetricName == "ActionLatency"
| project Minimum, TimeGenerated, MetricName=strcat("Min ", MetricName)
| summarize min(Minimum) by bin(TimeGenerated, 1m), MetricName
| project Value=min_Minimum, TimeGenerated, MetricName;
union MinLatency, MaxLatency
| render timechart
```

You can also combine metrics with different timespans.
Notice that `| where TimeGenerated > ago(14d)` filter has been added:

```sql
let MaxLatency=
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where TimeGenerated > ago(14d)
| where MetricName == "ActionLatency"
| project Maximum, TimeGenerated, MetricName=strcat("Max ", MetricName)
| summarize max(Maximum) by bin(TimeGenerated, 1m), MetricName
| project Value=max_Maximum, TimeGenerated, MetricName;
let MinLatency=
AzureMetrics 
| where ResourceProvider == "MICROSOFT.LOGIC"
| where TimeGenerated > ago(7d)
| where MetricName == "ActionLatency"
| project Minimum, TimeGenerated, MetricName=strcat("Min ", MetricName)
| summarize min(Minimum) by bin(TimeGenerated, 1m), MetricName
| project Value=min_Minimum, TimeGenerated, MetricName;
union MinLatency, MaxLatency
| render timechart
```

## External data

You can also query external data using KQL [externaldata](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/externaldata-operator) operator.

Let's use this on following CSV file:

```csv
ID,Name,Description
1,Car,This is description of car
2,Bicycle,It has two wheels
3,House,It's large building
```

Here's example query for that data:

```sql
let CSV = externaldata(ID:int, Name:string, Description:string)
[
  h@"https://raw.githubusercontent.com/JanneMattila/329-azure-api-management-functions/master/doc/data.csv"
]
with(format="csv");
CSV
| where ID < 4
```

Here's the output in Azure Portal:

![example csv query output](https://user-images.githubusercontent.com/2357647/94178181-6f616680-fea3-11ea-98d2-3587c59a3a45.png)


Following [data formats](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/externaldata-operator) are supported.

You can of course...

- Use multiple files in the array
- Host the files in storage account and just append the url with SAS token
- Use `multijson` to analyze e.g. App Insights export files

## Cosmos DB

Plot chart about Cosmos DB service availability:

```sql
AzureMetrics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where MetricName == "ServiceAvailability"
| where Resource == "<your account name>"
| project TimeGenerated, Minimum, MetricName
| render timechart
```
