# Azure Pipelines

## How do I queue build in Azure Pipelines using Az CLI

Here are the steps that you can use to queue build named `AbsolutelyEmpty-CI`:

```bash
# Install extension to Az CLI if you haven't done it yet
az extension add --name azure-devops

# Set defaults
az devops configure --defaults organization=https://dev.azure.com/YourOrganizationNameHere/
az devops configure --defaults project=YourProjectNameHere

# Queue build
az pipelines build queue --definition-name AbsolutelyEmpty-CI
```
