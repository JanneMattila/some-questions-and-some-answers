# Azure Databases

## Overview

When connecting to databases you must understand two important concepts:

1. Client redirection
2. Connection pooling

Client redirection means that you connect directly to the node hosting the database
from your application and bypass the proxy gateway completely.
This can result to lower latency and improved throughput.

This requires support from client side, so depending on your
database, database deployment scenario, database drivers and used programming language, you might
need to verify that indeed you have support for client redirection or no.

More detailed explanations can be found here:

[Azure SQL Managed Instance connection types](https://docs.microsoft.com/en-us/azure/azure-sql/managed-instance/connection-types-overview)

[Azure SQL Database and Azure Synapse Analytics connectivity architecture](https://docs.microsoft.com/en-us/azure/azure-sql/database/connectivity-architecture)

[Connect to Azure Database for MariaDB with redirection](https://docs.microsoft.com/en-us/azure/mariadb/howto-redirection)

[Connect to Azure Database for MySQL with redirection](https://docs.microsoft.com/en-us/azure/mysql/howto-redirection)

[Connect to Azure SQL Database V12 via Redirection](https://techcommunity.microsoft.com/t5/datacat/connect-to-azure-sql-database-v12-via-redirection/ba-p/305362)

Article summary:
- Use SQL Server driver version that supports TDS 7.4 or above (ADO.Net 4.5, JDBC 4.2 ([latest](https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server)), ODBC 11, or above)
- Make outbound TCP ports open on the application instance: 1433, 11000-11999 and 14000-14999

[High availability in Azure Database for PostgreSQL – Single Server](https://docs.microsoft.com/en-us/azure/postgresql/concepts-high-availability)

[Connection pooling](https://stackoverflow.blog/2020/10/14/improve-database-performance-with-connection-pooling/) enables you
to avoid expensive connection creation cost. Depending on your programming language and database drivers,
you might have direct support for that or then you can leverage some form of connection pooling proxy such as PgBouncer (more detailed scenario below)
or [ProxySQL](https://techcommunity.microsoft.com/t5/azure-database-for-mysql/deploy-proxysql-as-a-service-on-kubernetes-using-azure-database/ba-p/1105959).

## Azure Databases for PostgreSQL

### My app seems to have some latency when accessing PostgreSQL. How can I optimize it?

**TL;DR** Make sure that you have _at least_ these things set:

1. Create resources to same region
2. Use [accelerated networking](https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli) in your VMs
3. Use [PgBouncer](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/steps-to-install-and-setup-pgbouncer-connection-pooling-proxy/ba-p/730555) (or similar connection pooling proxy) to manage connections to the PostgreSQL

You can do simple test for the latency using these commands.
Replace `<user>` and `<instance>` with correct ones and
then connect to the local `pgbouncer` endpoint:

```bash
psql -h 127.0.0.1 -p 5432 -U <user>@<instance>.postgres.database.azure.com -d postgres
```

Get timing from `SELECT` statement:

```sql
\timing
SELECT;
\watch 1
```

**Note**: If you're using **Azure App Service** then please see this demo application for more details: [JanneMattila/328-webapp-pgbouncer](https://github.com/JanneMattila/328-webapp-pgbouncer).

**Note**: If you're using **Azure Kubernetes Service** then there is ready made [Pgbouncer Sidecar](https://hub.docker.com/_/microsoft-azure-oss-db-tools-pgbouncer-sidecar) for that.

### Links

Longer and much more detailed information can be found from these links:

[Azure Database for PostgreSQL - Checklist for Performance](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/azure-database-for-postgresql-checklist-for-performance/ba-p/1113378)

[Performance best practices for using Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/blog/performance-best-practices-for-using-azure-database-for-postgresql/)

[Performance troubleshooting using new Azure Database for PostgreSQL features](https://azure.microsoft.com/en-us/blog/performance-troubleshooting-using-new-azure-database-for-postgresql-features/)

[Performance updates and tuning best practices for using Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/blog/performance-updates-and-tuning-best-practices-for-using-azure-database-for-postgresql/)

[Performance best practices for using Azure Database for PostgreSQL – Connection Pooling](https://azure.microsoft.com/en-us/blog/performance-best-practices-for-using-azure-database-for-postgresql-connection-pooling/)

[Steps to install and setup PgBouncer connection pooling proxy with Azure DB for PostgreSQL](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/steps-to-install-and-setup-pgbouncer-connection-pooling-proxy/ba-p/730555)

[Taking Postgres's temperature with these 4 system metrics](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/taking-postgres-s-temperature-with-these-4-system-metrics/ba-p/1187969)
