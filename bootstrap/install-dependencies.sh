#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
for tool in docker jq openssl; do command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }; done
docker compose version >/dev/null
running_containers=$(docker ps -q)

# A foreign container using one of our data directories must be handled by the
# separate migration workflow. Never start a second database on those mounts.
while IFS= read -r container; do
  [[ -n $container ]] || continue
  foreign=$(docker inspect "$container" | jq -r '.[0] | select((.Name | startswith("/database-platform-")) | not) |
    select(any(.Mounts[]?; .Source | startswith("/dataNvme/DockerData/"))) | .Name')
  if [[ -n $foreign ]]; then
    echo "Migration required before installation: $foreign owns a runtime data directory. Use scripts/migrate-from-dcfs.sh." >&2
    exit 1
  fi
done <<< "$running_containers"

if [[ ! -f $repo_root/.env && ! -f $repo_root/.images.env ]]; then
  "$repo_root/bootstrap/generate-env.sh"
elif [[ ! -f $repo_root/.env || ! -f $repo_root/.images.env ]]; then
  echo 'Incomplete environment layout; restore the missing private file before continuing.' >&2
  exit 1
fi

# Upgrade old environment layouts without changing existing credentials.
for key in WHALEDECK_POSTGRES_PASSWORD WHALEDECK_VALKEY_PASSWORD; do
  if ! grep -q "^${key}=" "$repo_root/.env"; then
    printf '%s=%s\n' "$key" "$(openssl rand -hex 32)" >> "$repo_root/.env"
  fi
done
chmod 0600 "$repo_root/.env"

# Fresh SQL Server directories need its unprivileged UID before the first boot.
# Do not recursively change the ownership of pre-existing database files.
for name in sqlServer postgres mariaDb mongoDb valkey valkey72; do
  mkdir -p "/dataNvme/DockerData/$name/data" "/data/DockerData/$name/backup"
done
mkdir -p /dataNvme/DockerData/sqlServer/logs
chown 10001:0 /dataNvme/DockerData/sqlServer/data /dataNvme/DockerData/sqlServer/logs /data/DockerData/sqlServer/backup
chmod 0770 /dataNvme/DockerData/sqlServer/data /dataNvme/DockerData/sqlServer/logs /data/DockerData/sqlServer/backup

for stack in postgres mariaDb mongoDb sqlServer valkey valkey72; do
  docker compose --env-file "$repo_root/.images.env" --env-file "$repo_root/.env" \
    -f "$repo_root/$stack/compose.yml" config --quiet
  "$repo_root/$stack/scripts/start.sh"
done
"$repo_root/authentik/scripts/start.sh"
chown --reference="$repo_root" "$repo_root/.env" "$repo_root/.images.env" "$repo_root/authentik/.env"
"$repo_root/bootstrap/bootstrap-whaledeck.sh"
"$repo_root/scripts/check-all.sh"
echo 'All database-platform-* dependencies are healthy.'
