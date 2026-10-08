# DCFS database platform

This repository deploys six independent Docker Compose stacks on the remote workstation:

| Stack | Version | Container endpoint | NVMe runtime data | HDD backup |
| --- | --- | --- | --- | --- |
| SQL Server | 2025 CU9 | `sqlserver:1433` on `dcfsDbSqlServer` | `/dataNvme/DockerData/sqlServer` | `/data/DockerData/sqlServer/backup` |
| PostgreSQL | 18.6 | `postgres:5432` on `dcfsDbPostgres` | `/dataNvme/DockerData/postgres` | `/data/DockerData/postgres/backup` |
| MariaDB | 11.8.9 LTS | `mariadb:3306` on `dcfsDbMariaDb` | `/dataNvme/DockerData/mariaDb` | `/data/DockerData/mariaDb/backup` |
| MongoDB | 7.0.41 | `mongodb:27017` on `dcfsDbMongoDb` | `/dataNvme/DockerData/mongoDb` | `/data/DockerData/mongoDb/backup` |
| Valkey | 9.0.6 | `valkey:6379` on `dcfsCacheGeneral` | `/dataNvme/DockerData/valkey` | `/data/DockerData/valkey/backup` |
| Valkey compatibility | 7.2.14 | `valkey72:6379` on `dcfsCacheValkey72` | `/dataNvme/DockerData/valkey72` | `/data/DockerData/valkey72/backup` |

All image references include an immutable digest. SQL Server uses the workstation's existing MCR accelerator while retaining Microsoft's original manifest digest; Docker Official Images use the daemon's configured Docker Hub mirror. Runtime secrets live only in the root `.env`, mode `0600`, and are ignored by Git. Each stack has its own network, health check, resource limit, start/stop/check/backup/restore scripts, and explicit bind mounts. No anonymous volume contains production data. Valkey 9 remains the default general-purpose instance; Valkey 7.2 is an isolated compatibility instance for applications whose supported matrix has not reached the current major release.

Container output uses Docker's `local` logging driver with five 20 MiB segments per container and compression. SQL Server error logs are cycled daily, MariaDB slow/general logs are off by default, MariaDB binlogs expire after three days, and `check-all.sh` fails when either storage tier reaches 85% usage.

## Important license note

The example uses `MSSQL_PID=Developer`, which is licensed only for development and testing. This workstation's private `.env` contains the supplied enterprise product key, and the running instance has been verified as Enterprise Edition; the key is not stored in Git or documentation.

## Operations

Run commands from any directory:

```bash
/data/GitRepos/DCFS/scripts/check-all.sh
/data/GitRepos/DCFS/postgres/scripts/backup.sh
/data/GitRepos/DCFS/sqlServer/scripts/restore.sh /data/DockerData/sqlServer/backup/example.bak restored_database
```

Daily logical backups are installed in the `user` crontab. Local HDD backups are a recovery copy, not a disaster-recovery copy; add encrypted off-host replication before treating the service as production-ready.

The workstation installs normal operating-system package upgrades every Sunday at 20:00 through `dcfs-workstation-update.timer`. The job is persistent (a missed run executes after the next boot), writes to the bounded system journal, and never reboots the workstation automatically. Inspect it with:

```bash
systemctl list-timers dcfs-workstation-update.timer
journalctl -u dcfs-workstation-update.service
```

## Network boundary

Database ports are not published to the workstation. Every database network is marked `internal`, and only application containers explicitly attached to the matching network can connect. Do not add host port mappings for convenience.
