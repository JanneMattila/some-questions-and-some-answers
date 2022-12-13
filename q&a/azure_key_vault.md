# Azure Key Vault

## Recommendations

[Best practices for using Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
lists reasons [why we recommend separate key vaults](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices#why-we-recommend-separate-key-vaults)
for different applications per environment.

Same recommendation can be found in [Best Practices for individual keys, secrets, and certificates role assignments](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide?tabs=azure-cli#best-practices-for-individual-keys-secrets-and-certificates-role-assignments).

Additional background discussion can be also found [here](https://github.com/MicrosoftDocs/azure-docs/issues/81482)
and [here](https://github.com/MicrosoftDocs/azure-docs/issues/61545).

To summarize, you need to think various topics if you plan to share Key Vaults between different applications and services:

- Throttling
- Outage
- Administration
- Security
- Network changes
