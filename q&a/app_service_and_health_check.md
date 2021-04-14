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
for testing that which instances actually are responding to traffic,
even if you use the app itself for changing the return values
of probes or delaying the actual response for certain period of time
from the health check endpoint.

We can then kick-off our testing with following command:

```powershell
.\app_service_and_health_check.ps1 | Tee-Object -FilePath log.txt
```

If you start the script you should see following output:

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
instance `4e6e602ffcfc` which we'll control later on in the test.

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

First column e.g. `567` is the time in seconds from the iteration start.

Second column e.g. `215` is the time in milliseconds how long the request took.

Third column e.g. `4e6e602ffcfc` is the instance which responded to this request.

Fourth column is json which contains map of instance name and how many request
particular instance has responded. From above snapthos it's clear that
there are 3 instances and load is distributed very evenly between the instances.

Script runs 10 minutes per iteration and after each iteration is makes
rest call to target instance and delays the health check response by 15 seconds.
This means that now you can analyze that in which phases the server is dropped
out from rotation and it does not anymore receive traffic from the load balancer.
