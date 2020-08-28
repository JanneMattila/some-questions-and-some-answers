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
