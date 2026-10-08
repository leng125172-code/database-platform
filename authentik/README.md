# Authentik

This stack runs Authentik 2026.8.3 as the internal identity provider. It reuses the existing PostgreSQL 18.6 service through `dcfsDbPostgres`; Authentik gets its own `authentik` database and non-superuser `authentik` role. Current Authentik releases use PostgreSQL for application data, sessions, and background task coordination, so this deployment does not use Valkey.

## Network boundary

- The server listens only on HTTP port `9000` inside `dcfsAppAuthentik`.
- HTTP is the only network-accessible listener. Authentik 2026.8.3 rejects its documented empty HTTPS-listener value, so the unused TLS listener is restricted to `127.0.0.1` inside the container and is neither exposed nor published.
- No `ports` mapping exists, so the workstation and office LAN cannot connect directly.
- The future Dashboard or reverse proxy must join `dcfsAppAuthentik` and use `http://authentik:9000` with HTTP/1.1/WebSocket support.
- `dcfsAppAuthentik` is an internal Docker network. Authentik currently has no direct internet egress.
- Only the Authentik server and worker join `dcfsDbPostgres`; the future Dashboard must not join the database network.

## Secrets and storage

- `/.images.env` stores the Authentik image alongside every other deployed image reference.
- `authentik/.env` stores the Authentik secret key, runtime settings, and its dedicated PostgreSQL connection credentials.
- The real Authentik environment file is generated on the workstation with mode `0600` and is ignored by Git.
- PostgreSQL data stays on NVMe through the existing database stack.
- Authentik files and their archives use `/data/DockerData/authentik/{data,backup}` on HDD.
- Container logs use five compressed 10 MiB local-driver segments per container.

The worker intentionally does not mount `/var/run/docker.sock`. Automatic outpost deployment is therefore disabled; add outposts as separately managed containers if LDAP, RADIUS, RAC, or a standalone proxy outpost is needed later.

## Operations

```bash
/data/GitRepos/database-platform/authentik/scripts/start.sh
/data/GitRepos/database-platform/authentik/scripts/check.sh
/data/GitRepos/database-platform/authentik/scripts/backup.sh
/data/GitRepos/database-platform/authentik/scripts/stop.sh
```

The daily schedule runs `backup.sh --files-only` at 03:10 because PostgreSQL is already backed up at 01:30. Running `backup.sh` without that option performs both a fresh PostgreSQL backup set and an Authentik file archive for an on-demand coordinated recovery point.

Initial setup remains reachable only after the Dashboard/reverse proxy joins `dcfsAppAuthentik`. Use `http://<dashboard-host>/if/flow/initial-setup/`; do not temporarily publish port 9000 from the Authentik container.

The file restore script restores only `/data`. Database recovery must use the matching PostgreSQL dump as a coordinated operation before Authentik is started.
