# Using gRPC in Azure

## I want to expose gRPC endpoint from my backend. What Azure options do I have?

App Service is one of the first services you look when you start thinking about
creating web apps or web backends. However, as of now (9th of February, 2020)
App Service does not yet support gRPC. Read more about it
[here](https://docs.microsoft.com/en-us/aspnet/core/tutorials/grpc/grpc-start?view=aspnetcore-3.1&tabs=visual-studio#grpc-not-supported-on-azure-app-service).

**TO BE ADDED** Azure Container Instances (ACI), Azure Kubernetes Service (AKS), Virtual Machines, etc.
