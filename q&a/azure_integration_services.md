# Azure Integration Services

## Introduction

- [Gartner Glossary: Integration Platform as a Service (iPaaS)](https://www.gartner.com/en/information-technology/glossary/information-platform-as-a-service-ipaas)
- [Azure Integration Services](https://azure.microsoft.com/en-us/products/category/integration/)

## Discussion topics

- Centralized vs. De-centralized
  - Centralized at company level or Business Unit or Service Line level
  - Specialized integration teams vs. cloud developers
- RACI
  - Are some integrations, e.g., most critical ones, outsourced or self-managed? 
- 24x7 or 8x5 categorization
- Business critical vs. Standard integrations
- Cloud only, hybrid vs. On-premises
  - Do you use same integration solution for all integration scenarios?
  - Even if you have existing on-premises infrastructure?
    - Are you going to migrate these over to new solution?
- Functional & Non-functional requirements
- Networking requirements
  - Private endpoint vs. public endpoints
- Security requirements
  - Can you use service specific keys?
  - Do you require use of e.g., managed identities?
- Batch vs. Near real-time integrations
- Integration catalogue and documentation management
- Development process & agility
- Developer skills: 🔨vs. 🪚
- How to choose correct tool for the job?
- How many environments?
- High initial total cost of ownership (TCO) vs. Consumption based pricing

## Azure structure

- Do you you management groups?
- Have you plan the policy usage?
- Privileged Identity Management (PIM) vs. Standing access?
- How much manual development vs. automated deployments?
- What kind of permissions for developers?
- How do you build your Azure structure

E.g.,

```bash
├── integrations-nonprod-sub
│   ├── rg-apim
│   └── rg-repair-sales
│       ├── integration1-to-xxx
│       ├── integration2-to-xxx
│       └── integration3-to-xxx
└── integrations-prod-sub
    ├── rg-apim
    └── rg-repair-sales
```

## Technologies

### API Management

- [Azure API Management landing zone accelerator](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/app-platform/api-management/landing-zone-accelerator)
- [Azure API Management DevOps Resource Kit](https://github.com/Azure/azure-api-management-devops-resource-kit)
- [Azure API Management Policy Snippets](https://github.com/Azure/api-management-policy-snippets)
- [API Design](https://github.com/JanneMattila/api-design)

### Logic Apps

- [Deployments](https://github.com/Azure/logicapps)
  - Infra
  - Workflows
- [Example Workbook](https://github.com/scautomation/LogicApps-AzureMonitor-Workbook)
- Connectors
  - File based integrations and connector limits
  - Private endpoint vs. public endpoints
- Consumption vs. Standard
  - [Cost difference in deployment models](https://azure.microsoft.com/en-us/pricing/details/logic-apps/)
  - Infrastructure as Code is different per deployment model

- How do you group Standard workflows?
- How do you document integrations?
  - Do you use wiki?
