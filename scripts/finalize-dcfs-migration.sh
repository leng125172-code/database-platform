#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ "${1:-}" == --confirm ]] || {
  echo 'Usage: finalize-dcfs-migration.sh --confirm' >&2
  echo 'This removes stopped legacy container objects and unused legacy networks, never bind-mounted data.' >&2
  exit 2
}

"$repo_root/scripts/check-all.sh"
legacy_containers=(
  dcfsAuthentikWorker dcfsAuthentikServer dcfsValkey_7.2 dcfsValkey
  dcfsMongoDb dcfsMariaDb dcfsSqlServer dcfsPostgres
)

for name in "${legacy_containers[@]}"; do
  if docker inspect "$name" >/dev/null 2>&1; then
    state=$(docker inspect --format '{{.State.Status}}' "$name")
    [[ "$state" != running ]] || { echo "Refusing to remove running legacy container: $name" >&2; exit 1; }
  fi
done

for name in "${legacy_containers[@]}"; do
  docker rm "$name" >/dev/null 2>&1 || true
done

legacy_networks=(dcfsAppAuthentik dcfsCacheGeneral dcfsCacheValkey72 dcfsDbMariaDb dcfsDbMongoDb dcfsDbPostgres dcfsDbSqlServer)
for network in "${legacy_networks[@]}"; do
  docker network rm "$network" >/dev/null 2>&1 || true
done

echo 'Legacy container objects and unused networks removed. Runtime and backup bind-mounted data were preserved.'
