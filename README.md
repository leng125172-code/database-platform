# Database Platform

This repository deploys six independent database/cache stacks and the internal Authentik identity stack on the remote workstation:

| Stack | Version | Container endpoint | NVMe runtime data | HDD backup |
| --- | --- | --- | --- | --- |
| SQL Server | 2025 CU9 | `sqlserver:1433` on `database-platform-db-sqlserver` | `/dataNvme/DockerData/sqlServer` | `/data/DockerData/sqlServer/backup` |
| PostgreSQL | 18.6 | `postgres:5432` on `database-platform-db-postgres` | `/dataNvme/DockerData/postgres` | `/data/DockerData/postgres/backup` |
| MariaDB | 11.8.9 LTS | `mariadb:3306` on `database-platform-db-mariadb` | `/dataNvme/DockerData/mariaDb` | `/data/DockerData/mariaDb/backup` |
| MongoDB | 7.0.41 | `mongodb:27017` on `database-platform-db-mongodb` | `/dataNvme/DockerData/mongoDb` | `/data/DockerData/mongoDb/backup` |
| Valkey | 9.1.2 | `valkey:6379` on `database-platform-cache-general` | `/dataNvme/DockerData/valkey` | `/data/DockerData/valkey/backup` |
| Valkey compatibility | 7.2.14 | `valkey72:6379` on `database-platform-cache-valkey72` | `/dataNvme/DockerData/valkey72` | `/data/DockerData/valkey72/backup` |

All image references are centralized in the repository-root `.images.env` and include an immutable digest. SQL Server uses the workstation's existing MCR accelerator while retaining Microsoft's original manifest digest; Docker Official Images use the daemon's configured Docker Hub mirror. The root `.env` contains database/cache runtime settings and secrets, while `authentik/.env` contains all Authentik runtime settings and its dedicated PostgreSQL credentials. Real environment files are ignored by Git. Each stack has its own network, health check, resource limit, start/stop/check/backup/restore scripts, and explicit bind mounts. No anonymous volume contains production data. Valkey 9 remains the default general-purpose instance; Valkey 7.2 is an isolated compatibility instance for applications whose supported matrix has not reached the current major release.

`bootstrap/bootstrap-whaledeck.sh` idempotently creates the least-privilege `whaledeck` PostgreSQL role/database and the Valkey 9 `whaledeck` ACL user. Generated credentials remain only in the root private `.env` (mode `0600`); the cache identity is restricted to `whaledeck:*` keys and cannot call configuration, ACL, or shutdown commands.

Authentik 2026.8.3 reuses PostgreSQL 18.6 with a dedicated database and least-privilege role. Its HTTP endpoint is available only as `http://authentik:9000` on the internal `database-platform-app-authentik` network. The unused TLS listener is restricted to container loopback, and no host port is published. The future Dashboard/reverse proxy can join this network without gaining access to the PostgreSQL network.

## Environment files

| File | Responsibility |
| --- | --- |
| `/.images.env` | Every deployed container image tag and immutable digest, including Authentik |
| `/.env` | Shared paths plus database/cache credentials and resource limits |
| `/authentik/.env` | Authentik secret, storage/resource settings, and its dedicated PostgreSQL credentials |

Do not put image variables in either runtime `.env`. Compose wrappers always load `.images.env` first and the relevant runtime file second.
`scripts/check-env-layout.sh` enforces this separation and rejects the retired root `.authentik.env` layout.

Container output uses Docker's `local` logging driver with five 20 MiB segments per container and compression. SQL Server error logs are cycled daily, MariaDB slow/general logs are off by default, MariaDB binlogs expire after three days, and `check-all.sh` fails when either storage tier reaches 85% usage.

## Important license note

The example uses `MSSQL_PID=Developer`, which is licensed only for development and testing. This workstation's private `.env` contains the supplied enterprise product key, and the running instance has been verified as Enterprise Edition; the key is not stored in Git or documentation.

## Operations

For installation or resuming a partially completed installation, run `sudo ./bootstrap/install-dependencies.sh`. It preserves private environment files, creates missing Whale Deck credentials, checks for foreign containers holding the same data mounts, then starts every dependency. Legacy migrations remain an explicit separate workflow. The Whale Deck repository's `install.sh` calls this entry point after checking packages and Docker.

Run commands from any directory:

```bash
/data/GitRepos/database-platform/scripts/check-all.sh
/data/GitRepos/database-platform/postgres/scripts/backup.sh
/data/GitRepos/database-platform/sqlServer/scripts/restore.sh /data/DockerData/sqlServer/backup/example.bak restored_database
```

Daily logical backups are installed in the `user` crontab. Local HDD backups are a recovery copy, not a disaster-recovery copy; add encrypted off-host replication before treating the service as production-ready.

The workstation installs normal operating-system package upgrades every Sunday at 20:00 through `database-platform-workstation-update.timer`. The job is persistent (a missed run executes after the next boot), writes to the bounded system journal, and never reboots the workstation automatically. Inspect it with:

```bash
systemctl list-timers database-platform-workstation-update.timer
journalctl -u database-platform-workstation-update.service
```

### One-time migration from legacy `dcfs*` runtime names

The migration keeps the old containers stopped for rollback and reuses the existing bind-mounted data. It never runs old and new database containers against the same data directory at the same time.

```bash
./scripts/migrate-from-dcfs.sh
sudo ./bootstrap/install-workstation-update-systemd.sh
./scripts/check-all.sh
```

If validation fails, run `./scripts/rollback-to-dcfs.sh`. Only after Whale Deck acceptance, remove the stopped legacy container objects with `./scripts/finalize-dcfs-migration.sh --confirm`; bind-mounted NVMe/HDD data is not removed.

## Network boundary

Database ports are not published to the workstation. Every database network is marked `internal`, and only application containers explicitly attached to the matching network can connect. Do not add host port mappings for convenience.

Authentik follows the same boundary: no host port is published. Its dedicated application network is also internal, ready for a future unified Dashboard/reverse proxy.
