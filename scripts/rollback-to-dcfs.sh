#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
new_directories=(authentik valkey72 valkey mongoDb mariaDb sqlServer postgres)
legacy_data=(dcfsPostgres dcfsMariaDb dcfsMongoDb dcfsSqlServer dcfsValkey dcfsValkey_7.2)

echo 'Stopping database-platform containers...'
for directory in "${new_directories[@]}"; do
  if [[ -x "$repo_root/$directory/scripts/stop.sh" ]]; then
    "$repo_root/$directory/scripts/stop.sh" || true
  fi
done

for name in database-platform-postgres database-platform-mariadb database-platform-mongodb database-platform-sqlserver database-platform-valkey database-platform-valkey72 database-platform-authentik-server database-platform-authentik-worker; do
  if [[ $(docker inspect --format '{{.State.Running}}' "$name" 2>/dev/null || true) == true ]]; then
    echo "Rollback refused: $name is still running; do not start the old container on the same data mount." >&2
    exit 1
  fi
done

for name in "${legacy_data[@]}"; do
  docker inspect "$name" >/dev/null 2>&1 || { echo "Legacy rollback container missing: $name" >&2; exit 1; }
done

echo 'Starting legacy data services...'
docker start dcfsPostgres dcfsMariaDb dcfsMongoDb dcfsSqlServer dcfsValkey dcfsValkey_7.2 >/dev/null
for name in "${legacy_data[@]}"; do
  deadline=$((SECONDS + 360))
  while (( SECONDS < deadline )); do
    state=$(docker inspect --format '{{.State.Status}}' "$name")
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name")
    [[ "$state" == running && ( "$health" == healthy || "$health" == none ) ]] && break
    sleep 5
  done
  [[ "$state" == running && ( "$health" == healthy || "$health" == none ) ]] \
    || { echo "Legacy container failed to recover: $name" >&2; exit 1; }
done

docker start dcfsAuthentikServer dcfsAuthentikWorker >/dev/null
echo 'Legacy dcfs stack restored. The new database-platform containers remain stopped.'
