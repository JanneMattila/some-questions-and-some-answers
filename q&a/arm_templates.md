# Azure Resource Manager templates

## Getting started

Few links to get you started in ARM templates:

- [ARM template documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/)
- [ARM template reference documentation](https://docs.microsoft.com/en-us/azure/templates/)
- [GitHub Azure Quickstart templates](https://github.com/Azure/azure-quickstart-templates)
- [Visual Studio Code](https://code.visualstudio.com/) and [ARM Tools extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools) ([Quickstart instructions](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/quickstart-create-templates-use-visual-studio-code?tabs=CLI))
- [Export template in portal](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/export-template-portal)
- [resources.azure.com](https://resources.azure.com)

## Advanced scenario

In case you're working on implementing something in ARM templates
and you don't know exactly how those properties should be,
then you can take a reverse engineering approach.

In case you're working on `Cdn` automation and you try to create
redirect rule to move all the traffic to https to specific address.
When implementing this in ARM template you find good example which
almost does what you want:

[201-cdn-with-ruleseengine-rewriteandredirect](https://github.com/Azure/azure-quickstart-templates/blob/master/201-cdn-with-ruleseengine-rewriteandredirect/azuredeploy.json#L127-L136)

You then try to modify that example to forward the traffic to correct address by
introducing another property `destinationHostname` based on guess from example
property `destinationProtocol`. But when you deploy that template you get following
error message:

```powershell
New-AzResourceGroupDeployment: C:\GitHub\amazerrr\deploy\deploy.ps1:51
Line |
  51 |  $result = New-AzResourceGroupDeployment `
     |            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | 11:36:07 AM - Resource Microsoft.Cdn/profiles/endpoints 'amazerrrcdn-abcdef/amazerrr-local' failed with
     | message '{ "error": { "code": "InvalidResource", "message": "The property 'destinationHostname' does not
     | exist on type 'Microsoft.Azure.Cdn.Models.DeliveryRuleUrlRedirectActionParameters'.
     | Make sure to only use property names that are defined by the type." } }'
```

Above of course means that our guess was incorrect. Based on the error message our
property did not map correctly to expected properties in specific model.
Error message shows the model name to be:
`Microsoft.Azure.Cdn.Models.DeliveryRuleUrlRedirectActionParameters`.

Now we can take a closer look of the models that are then available in PowerShell modules.
Find `Az` module and `Az.Cdn` underneath it:

![Az.Cdn PowerShell module](https://user-images.githubusercontent.com/2357647/77831602-d8586380-7138-11ea-8087-cb8afe3c2127.png)

Next get yourself [ILSpy](https://github.com/icsharpcode/ILSpy) and
open up those dlls with it:

![Cdn models from dlls](https://user-images.githubusercontent.com/2357647/77843398-9fa2a380-71a5-11ea-9309-d4e1cbb7a074.png)

Using functionaly of ILSpy you can easily navigate between different models and
find what you're looking for:

![UrlRedirectActionParameters class in Cdn models](https://user-images.githubusercontent.com/2357647/77843428-d4165f80-71a5-11ea-92c1-2dc14eacb47c.png)

![OData data type of the found class](https://user-images.githubusercontent.com/2357647/77843450-02943a80-71a6-11ea-9073-695b694c2690.png)

Then you can look for the properties and find again you target property:

![customHostname property](https://user-images.githubusercontent.com/2357647/77843462-18096480-71a6-11ea-9814-d2b148aafcde.png)

Here is the same property in action in ARM template:

[customHostname in ARM template](https://github.com/JanneMattila/amazerrr/blob/cca5b454308e86418eca4a74459f343ac182631a/deploy/azuredeploy.json#L174-L184)
