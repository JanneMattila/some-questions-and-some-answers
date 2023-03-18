# Azure Kubernetes Service

## Running databases in Kubernetes

[Running Databases on Kubernetes or Nah?](https://twitter.com/i/spaces/1lDxLnVeQNRGm)

[How To Corrupt An SQLite Database File](https://www.sqlite.org/howtocorrupt.html)

> SQLite depends on the underlying **filesystem to do locking** .... But some filesystems contain bugs in their locking logic such that the locks do not always behave as advertised. This is especially true of **network filesystems and NFS in particular**.

[Using NFS with MySQL](https://dev.mysql.com/doc/refman/8.0/en/disk-issues.html)

> MySQL data and log files placed on **NFS volumes becoming locked and unavailable** for use...

[SQL Server in Docker](https://github.com/Microsoft/mssql-docker)

[SQL Server Containers running on container orchestrators](https://learn.microsoft.com/en-US/troubleshoot/sql/general/support-policy-sql-server#sql-server-containers-running-on-container-orchestrators)

 - [Supported file systems](https://learn.microsoft.com/en-US/troubleshoot/sql/general/support-policy-sql-server#supported-file-systems)

 > If you install SQL Server on Linux, the **supported file systems for the volumes** that host database files are **EXT4 and XFS**.

[MongoDB - Operations Checklist](https://www.mongodb.com/docs/manual/administration/production-checklist-operations/)

> **Avoid using NFS drives** for your dbPath. **Using NFS drives can result in degraded and unstable performance**.

[PostgreSQL - Use of Network File Systems](https://www.postgresql.org/docs/9.0/creating-cluster.html)

> PostgreSQL does nothing special for NFS file systems, meaning it assumes NFS behaves exactly like locally-connected drives. If the client or server NFS implementation does not provide standard file system semantics, this can cause reliability problem.
> Specifically, delayed (asynchronous) writes to the **NFS server can cause data corruption problems**.

## DNS

To test `/etc/resolv.conf` configuration, you can use [webapp-network-tester](https://github.com/JanneMattila/webapp-network-tester)
with payload `FILE READ "/etc/resolv.conf"`:

Here is the default configuration:

```
-> Start: FILE READ "/etc/resolv.conf"
nameserver 10.96.0.10
search network-app.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
<- End: FILE READ "/etc/resolv.conf" 102.45ms
```

Notice `ndots` with value `5`.

Related links:

[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

[DNS Lookups in Kubernetes](https://mrkaran.dev/posts/ndots-kubernetes/)

[Kubernetes pods /etc/resolv.conf ndots:5 option and why it may negatively affect your application performances](https://pracucci.com/kubernetes-dns-resolution-ndots-options-and-why-it-may-affect-application-performances.html)

[Help Understanding how DNS works and what ndots is used for.](https://www.reddit.com/r/kubernetes/comments/duj86x/help_understanding_how_dns_works_and_what_ndots/)
