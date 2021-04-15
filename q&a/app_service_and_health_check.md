# App Service and Health check

[Health check](https://docs.microsoft.com/en-us/azure/app-service/monitor-instances-health-check)
is app service feature for checking your app health by
pinging each instance your app runs on.
Instances that are unhealthy are removed from receiving
traffic and given time to recover back to healthy state.

Here are some instructions how you can study further
how it works. 

First lets create App Service which uses [k8s-probe-demo](https://hub.docker.com/r/jannemattila/k8s-probe-demo)
image (code available [here](https://github.com/JanneMattila/KubernetesProbeDemo)):

```powershell
$appServiceName = "healthcheck000001"
$appServicePlanName = "healthcheckPlan"
$resourceGroup = "rg-health-check"
$location = "westeurope"
$image = "jannemattila/k8s-probe-demo:1.0.10"

# Login to Azure
az login

# *Explicitly* select your working context
az account set --subscription <YourSubscription>

# # Show current context
az account show -o table

# # Create new resource group
az group create --name $resourceGroup --location $location -o table

# # Create App Service Plan
az appservice plan create --name $appServicePlanName --resource-group $resourceGroup --is-linux --number-of-workers 3 --sku B1 -o table

# Create App Service
az webapp create --name $appServiceName --plan $appServicePlanName --resource-group $resourceGroup -i $image -o table
```

Optinally you can enable [diagnostics logs](https://docs.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs#send-logs-to-azure-monitor-preview)
for analyzing `AppServicePlatformLogs` later on.

`k8s-probe-demo` image contains functionality which can be used
for testing `liveness` and `readiness` inside Kubernetes cluster
but similarly it can be used for testing app service health check as well.

In app service settings enable health check to this path:

`/api/HealthCheck/Liveness` and "Load Balancing" setting to be 2 minutes
(description of the setting: "Configure the time that an unhealthy instance remains in the load balancer before it is removed.").

You can now use `app_service_and_health_check.ps1` script
for testing that which instances are responding to traffic,
even if you use the app itself for changing the return values
of probes or delaying the actual response for certain period of time
from the health check endpoint.

We can then kick-off our testing with following command:

```powershell
.\app_service_and_health_check.ps1 | Tee-Object -FilePath log.txt
```

If you start the script, you should see following output:

```bash
https://healthcheck000001.azurewebsites.net
Health check target server: 4e6e602ffcfc
Started new round: delay 50 seconds
Not target server: 4e6e602ffcfc (was d52cc322e0dd)
Not target server: 4e6e602ffcfc (was e2568d694e6d)
Not target server: 4e6e602ffcfc (was d52cc322e0dd)
Not target server: 4e6e602ffcfc (was e2568d694e6d)
Health check delay changed to 50
1 200 4e6e602ffcfc {"4e6e602ffcfc":1}
2 145 d52cc322e0dd {"d52cc322e0dd":1,"4e6e602ffcfc":1}
4 198 e2568d694e6d {"e2568d694e6d":1,"d52cc322e0dd":1,"4e6e602ffcfc":1}
5 171 4e6e602ffcfc {"e2568d694e6d":1,"d52cc322e0dd":1,"4e6e602ffcfc":2}
6 216 e2568d694e6d {"e2568d694e6d":2,"d52cc322e0dd":1,"4e6e602ffcfc":2}
7 207 d52cc322e0dd {"e2568d694e6d":2,"d52cc322e0dd":2,"4e6e602ffcfc":2}
9 233 4e6e602ffcfc {"e2568d694e6d":2,"d52cc322e0dd":2,"4e6e602ffcfc":3}
10 209 e2568d694e6d {"e2568d694e6d":3,"d52cc322e0dd":2,"4e6e602ffcfc":3}
11 219 d52cc322e0dd {"e2568d694e6d":3,"d52cc322e0dd":3,"4e6e602ffcfc":3}
12 237 d52cc322e0dd {"e2568d694e6d":3,"d52cc322e0dd":4,"4e6e602ffcfc":3}
13 237 e2568d694e6d {"e2568d694e6d":4,"d52cc322e0dd":4,"4e6e602ffcfc":3}
15 243 4e6e602ffcfc {"e2568d694e6d":4,"d52cc322e0dd":4,"4e6e602ffcfc":4}
16 151 d52cc322e0dd {"e2568d694e6d":4,"d52cc322e0dd":5,"4e6e602ffcfc":4}
17 222 e2568d694e6d {"e2568d694e6d":5,"d52cc322e0dd":5,"4e6e602ffcfc":4}
18 210 4e6e602ffcfc {"e2568d694e6d":5,"d52cc322e0dd":5,"4e6e602ffcfc":5}
20 219 4e6e602ffcfc {"e2568d694e6d":5,"d52cc322e0dd":5,"4e6e602ffcfc":6}
```

It first prints out the target test url and then prints the target
instance `4e6e602ffcfc` which we'll control later in the test.

Now test script will gradually change this `4e6e602ffcfc` instances
health check return value to be delayed later and later.

Here is snapshot from the output:

```bash
567 215 4e6e602ffcfc {"e2568d694e6d":151,"d52cc322e0dd":155,"4e6e602ffcfc":150}
568 215 e2568d694e6d {"e2568d694e6d":152,"d52cc322e0dd":155,"4e6e602ffcfc":150}
569 254 e2568d694e6d {"e2568d694e6d":153,"d52cc322e0dd":155,"4e6e602ffcfc":150}
570 231 d52cc322e0dd {"e2568d694e6d":153,"d52cc322e0dd":156,"4e6e602ffcfc":150}
572 202 d52cc322e0dd {"e2568d694e6d":153,"d52cc322e0dd":157,"4e6e602ffcfc":150}
```

First column e.g., `567` is the time in seconds from the iteration start.

Second column e.g., `215` is the time in milliseconds how long the request took.

Third column e.g., `4e6e602ffcfc` is the instance which responded to this request.

Fourth column is json which contains map of instance name and how many requests
particular instance has processed. From above snapshots it's clear that
there are 3 instances and load is distributed very evenly between the instances.

Script runs 10 minutes per iteration and after each iteration it makes
rest call to target instance and delays the health check response by 15 seconds.
This means that now you can analyze that in which phases the server is dropped
out from rotation and it does not anymore receive traffic from the load balancer.

Now if we let the test run for while we should see this:

```bash
# ...
606 154 d52cc322e0dd {"e2568d694e6d":157,"d52cc322e0dd":159,"4e6e602ffcfc":161}
Started new round: delay 110 seconds
Not target server: 4e6e602ffcfc (was e2568d694e6d)
Not target server: 4e6e602ffcfc (was d52cc322e0dd)
Health check delay changed to 110
1 211 4e6e602ffcfc {"4e6e602ffcfc":1}
2 236 4e6e602ffcfc {"4e6e602ffcfc":2}
3 256 e2568d694e6d {"4e6e602ffcfc":2,"e2568d694e6d":1}
5 207 d52cc322e0dd {"e2568d694e6d":1,"d52cc322e0dd":1,"4e6e602ffcfc":2}
6 160 e2568d694e6d {"e2568d694e6d":2,"d52cc322e0dd":1,"4e6e602ffcfc":2}
7 217 4e6e602ffcfc {"e2568d694e6d":2,"d52cc322e0dd":1,"4e6e602ffcfc":3}
8 221 e2568d694e6d {"e2568d694e6d":3,"d52cc322e0dd":1,"4e6e602ffcfc":3}
9 227 d52cc322e0dd {"e2568d694e6d":3,"d52cc322e0dd":2,"4e6e602ffcfc":3}
# ...
```

Above means that delay has been now set to 110 seconds.

If we let the test run for still a bit more, we notice new instance to pop up `3e9b788fd2e9`:

```bash
# ...
366 215 d52cc322e0dd {"e2568d694e6d":95,"d52cc322e0dd":102,"4e6e602ffcfc":99}
367 261 e2568d694e6d {"e2568d694e6d":96,"d52cc322e0dd":102,"4e6e602ffcfc":99}
368 256 e2568d694e6d {"e2568d694e6d":97,"d52cc322e0dd":102,"4e6e602ffcfc":99}
370 205 e2568d694e6d {"e2568d694e6d":98,"d52cc322e0dd":102,"4e6e602ffcfc":99}
374 3739 3e9b788fd2e9 {"3e9b788fd2e9":1,"e2568d694e6d":98,"d52cc322e0dd":102,"4e6e602ffcfc":99}
376 161 e2568d694e6d {"3e9b788fd2e9":1,"e2568d694e6d":99,"d52cc322e0dd":102,"4e6e602ffcfc":99}
377 215 3e9b788fd2e9 {"3e9b788fd2e9":2,"e2568d694e6d":99,"d52cc322e0dd":102,"4e6e602ffcfc":99}
378 224 3e9b788fd2e9 {"3e9b788fd2e9":3,"e2568d694e6d":99,"d52cc322e0dd":102,"4e6e602ffcfc":99}
379 153 d52cc322e0dd {"3e9b788fd2e9":3,"e2568d694e6d":99,"d52cc322e0dd":103,"4e6e602ffcfc":99}
380 203 d52cc322e0dd {"3e9b788fd2e9":3,"e2568d694e6d":99,"d52cc322e0dd":104,"4e6e602ffcfc":99}
# ...
```

Similarly, we can see that `4e6e602ffcfc` does not anymore receive traffic
and has been taken out for the instance pool.

If you enabled diagnostic logs, then you can use following query
to find relevant entry in the logs:

```sql
AppServicePlatformLogs 
| where Level == "Warning"
```

Output of the query:

```
OperationName: ContainerLogs
Level: Warning
Message: Container for healthcheckgoeswild_0_1921a084 site healthcheckgoeswild is unhealthy, recycling site.
ContainerId: 4e6e602ffcfc60bcb5c28c547adfb6b4b228869f1feda3c54daaea5bbd78e8d7
Host: lw1sdlwk0000E0
SourceSystem: Azure
Type: AppServicePlatformLogs
```
