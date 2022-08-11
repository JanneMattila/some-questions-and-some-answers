# Azure Front Door

## gRPC and HTTP/2

If you have gRPC implementation like [WPF goes gRPC](https://github.com/JanneMattila/wpf-goes-grpc)
which relies on [HTTP/2](https://docs.microsoft.com/en-us/aspnet/core/grpc/comparison?view=aspnetcore-6.0)
and you planning to use [Azure Front Door](https://docs.microsoft.com/en-us/azure/frontdoor/front-door-overview) 
between Client and Backend, then please note following limitation about
[HTTP/2 support in Azure Front Door](https://docs.microsoft.com/en-us/azure/frontdoor/front-door-http2):

> HTTP/2 protocol support is available only for requests from clients to Front Door.
> The communication from **Front Door to back ends in the back-end pool happens over HTTP/1.1**.

For alternative solutions look for 
[Compare gRPC services with HTTP APIs](https://docs.microsoft.com/en-us/aspnet/core/grpc/comparison?view=aspnetcore-6.0).
