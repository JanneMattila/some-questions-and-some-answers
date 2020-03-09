# Azure Databases for PostgreSQL

## My app seems to have some latency when accessing PostgreSQL. How can I optimize it?

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

## Links

Longer and much more detailed information can be found from these links:

[Azure Database for PostgreSQL - Checklist for Performance](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/azure-database-for-postgresql-checklist-for-performance/ba-p/1113378)

[Performance best practices for using Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/blog/performance-best-practices-for-using-azure-database-for-postgresql/)

[Performance troubleshooting using new Azure Database for PostgreSQL features](https://azure.microsoft.com/en-us/blog/performance-troubleshooting-using-new-azure-database-for-postgresql-features/)

[Performance updates and tuning best practices for using Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/blog/performance-updates-and-tuning-best-practices-for-using-azure-database-for-postgresql/)

[Performance best practices for using Azure Database for PostgreSQL – Connection Pooling](https://azure.microsoft.com/en-us/blog/performance-best-practices-for-using-azure-database-for-postgresql-connection-pooling/)

[Steps to install and setup PgBouncer connection pooling proxy with Azure DB for PostgreSQL](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/steps-to-install-and-setup-pgbouncer-connection-pooling-proxy/ba-p/730555)

[Taking Postgres's temperature with these 4 system metrics](https://techcommunity.microsoft.com/t5/azure-database-for-postgresql/taking-postgres-s-temperature-with-these-4-system-metrics/ba-p/1187969)
