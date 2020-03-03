# Azure deployment entry point

## Main in programming languages

`Main` method is the entry point used in many programming languages.
Examples below are from Go, Java and C# but many other programming
languages have the same idea of _known entrypoint_ for the application.

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello world!")
}
```

```java
class App {
    public static void main(String[] args) {
        System.out.println("Hello World!");
    }
}
```

```csharp
class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("Hello World!");
    }
}
```

## Why don't we have similar concept when talking about Azure deployments then?

We can have it. My recommendation is `deploy.ps1` as deployment entry point.

This idea is not new. I have already written about this in
[here](https://docs.microsoft.com/en-us/archive/blogs/jannemattila/simple-web-app-application-lifecycle-management-with-vsts-and-azure)
and [here](https://docs.microsoft.com/en-us/archive/blogs/jannemattila/enhance-arm-deployments-with-powershell)
(blog posts from year 2016 😊).

However, I want to still emphasize that I highly recommend using `deploy.ps1`
as your Azure deployment entry point no matter what your
_Infrastructure-as-Code_ solution is (but you can always read my take on it [here](http://bit.ly/WhyJanneLikesARMTemplates)).

This gives you _so_ much benefits. To just name a few:

- New developers joining to the team can easily deploy
the environment without too much knowledge about the underlying infrastructure components.
This is exactly the reason why programming languages have known entry points. You know where
it all starts.

- You can also implement additional logic inside the `deploy.ps1` as part of you deployment in `PowerShell` or `az` CLI (e.g. [enable static hosting for storage account](https://github.com/JanneMattila/amazerrr/blob/master/deploy/deploy.ps1#L69) or change any other deployment detail based on whatever you like)

- Use exactly the same code in your pipelines and when you're working locally
with your infrastructure (Yes, again I refer to my 2016 [posts](https://docs.microsoft.com/en-us/archive/blogs/jannemattila/enhance-arm-deployments-with-powershell)). Only difference is the identity: when working locally it's developers identity and in your pipelines you use [service principal](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure?view=azure-devops).
