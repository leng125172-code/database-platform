# DCFS database platform

This repository deploys five independent Docker Compose stacks on the remote workstation:

| Stack | Version | Host endpoint | NVMe runtime data | HDD backup |
| --- | --- | --- | --- | --- |
| SQL Server | 2025 CU9 | `192.168.100.13:1433` | `/dataNvme/DockerData/sqlServer` | `/data/DockerData/sqlServer/backup` |
| PostgreSQL | 18.6 | `192.168.100.13:5432` | `/dataNvme/DockerData/postgres` | `/data/DockerData/postgres/backup` |
| MariaDB | 11.8.9 LTS | `192.168.100.13:3306` | `/dataNvme/DockerData/mariaDb` | `/data/DockerData/mariaDb/backup` |
| MongoDB | 9.0.2 | `192.168.100.13:27017` | `/dataNvme/DockerData/mongoDb` | `/data/DockerData/mongoDb/backup` |
| Valkey | 9.0.6 | `192.168.100.13:6379` | `/dataNvme/DockerData/valkey` | `/data/DockerData/valkey/backup` |

All image references include an immutable digest. SQL Server uses the workstation's existing MCR accelerator while retaining Microsoft's original manifest digest; Docker Official Images use the daemon's configured Docker Hub mirror. Runtime secrets live only in the root `.env`, mode `0600`, and are ignored by Git. Each stack has its own network, health check, resource limit, start/stop/check/backup/restore scripts, and explicit bind mounts. No anonymous volume contains production data.

Container output uses Docker's `local` logging driver with five 20 MiB segments per container and compression. SQL Server error logs are cycled daily, MariaDB slow/general logs are off by default, MariaDB binlogs expire after three days, and `check-all.sh` fails when either storage tier reaches 85% usage.

## Important license note

SQL Server uses `MSSQL_PID=Developer` by default. Developer edition is licensed only for development and testing. Before production use, set `MSSQL_PID` to `Express` or to a valid licensed edition/product key and review Microsoft's container support policy.

## Operations

Run commands from any directory:

```bash
/data/GitRepos/DCFS/scripts/check-all.sh
/data/GitRepos/DCFS/postgres/scripts/backup.sh
/data/GitRepos/DCFS/sqlServer/scripts/restore.sh /data/DockerData/sqlServer/backup/example.bak restored_database
```

Daily logical backups are installed in the `user` crontab. Local HDD backups are a recovery copy, not a disaster-recovery copy; add encrypted off-host replication before treating the service as production-ready.

## Network boundary

Database ports bind to the workstation LAN address, never all interfaces. Credentials are mandatory. TLS is not enabled in this baseline, so clients should connect only over the trusted LAN/VPN. Add managed certificates before crossing an untrusted network.
