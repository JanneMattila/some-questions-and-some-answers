# Azure CLI

## How can I troubleshoot my commands?

Easiest way to troubleshoot your command is to add `--debug` to the end:

```bash
az group create -l $location -n $resourceGroupName -o table --debug
```

To log debug output to file, you can add this to your Azure CLI configuration file
(`$HOME/.azure` on Linux or WSL or macOS, `%USERPROFILE%\.azure` on Windows):

```bash
[logging]
enable_log_file = yes
log_dir = /path/to/put/logs
```

You can then open `/path/to/put/logs/az.log` to see debug output of all the commands you have executed.

Start by searching these:

- `Request URL: ` to find HTTP requests
- `Response status: ` to find HTTP responses
- `ERROR : ` to find errors
- `WARNING : ` to find warnings (contains quite much noise)

See more details about [configuration options](https://docs.microsoft.com/en-us/cli/azure/azure-cli-configuration) of CLI.
