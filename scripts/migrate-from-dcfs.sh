#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="$repo_root/.migration-state"
stamp=$(date +%Y%m%d_%H%M%S)
backup_root="/data/DockerData/migration-dcfs-$stamp"

legacy_containers=(
  dcfsPostgres dcfsMariaDb dcfsMongoDb dcfsSqlServer
  dcfsValkey dcfsValkey_7.2 dcfsAuthentikServer dcfsAuthentikWorker
)
new_containers=(
  database-platform-postgres database-platform-mariadb database-platform-mongodb
  database-platform-sqlserver database-platform-valkey database-platform-valkey72
  database-platform-authentik-server database-platform-authentik-worker
)

require_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker inspect --format '{{.State.Status}}' "$1" 2>/dev/null || true)" == running ]]
}

wait_healthy() {
  local name=$1
  local deadline=$((SECONDS + 360))
  while (( SECONDS < deadline )); do
    local state health
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || true)
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || true)
    if [[ "$state" == running && ( "$health" == healthy || "$health" == none ) ]]; then
      return 0
    fi
    sleep 5
  done
  echo "Timed out waiting for $name" >&2
  return 1
}

start_stack() {
  local directory=$1
  "$repo_root/$directory/scripts/start.sh"
}

require_command docker
require_command sha256sum
[[ -r "$repo_root/.env" ]] || { echo "Missing $repo_root/.env" >&2; exit 1; }
[[ -r "$repo_root/.images.env" ]] || { echo "Missing $repo_root/.images.env" >&2; exit 1; }
"$repo_root/scripts/check-env-layout.sh"

if container_running database-platform-postgres && ! container_running dcfsPostgres; then
  echo 'The database-platform stack is already active and the legacy PostgreSQL container is stopped.'
  exit 0
fi

for name in "${legacy_containers[@]}"; do
  container_exists "$name" || { echo "Required legacy container not found: $name" >&2; exit 1; }
  container_running "$name" || { echo "Legacy container is not running: $name" >&2; exit 1; }
done

for name in "${new_containers[@]}"; do
  if container_running "$name"; then
    echo "Refusing migration while new container is already running: $name" >&2
    exit 1
  fi
done

for path in /data /dataNvme; do
  used=$(df -P "$path" | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
  (( used < 85 )) || { echo "$path is ${used}% full; migration requires usage below 85%." >&2; exit 1; }
done

mkdir -p "$backup_root" "$state_dir"
chmod 0700 "$backup_root" "$state_dir"
printf '%s\n' "$backup_root" > "$state_dir/latest-backup"
docker ps --format '{{.Names}}|{{.Image}}|{{.Status}}' > "$backup_root/containers-before.txt"

echo 'Creating migration safety backups...'
docker exec -u postgres dcfsPostgres pg_dumpall > "$backup_root/postgres-all.sql"
docker exec dcfsMariaDb sh -ec 'exec mariadb-dump --all-databases --single-transaction --quick --lock-tables=false -uroot -p"$MARIADB_ROOT_PASSWORD"' \
  > "$backup_root/mariadb-all.sql"
docker exec dcfsMongoDb sh -ec 'exec mongodump --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --archive --gzip' \
  > "$backup_root/mongodb.archive.gz"
sql_backup_query=$(cat <<SQL
DECLARE @name sysname, @path nvarchar(4000), @sql nvarchar(max);
DECLARE databases CURSOR LOCAL FAST_FORWARD FOR
  SELECT name FROM sys.databases WHERE state_desc = N'ONLINE' AND name <> N'tempdb';
OPEN databases; FETCH NEXT FROM databases INTO @name;
WHILE @@FETCH_STATUS = 0 BEGIN
  SET @path = N'/var/opt/mssql/backup/dcfs_migration_' +
    REPLACE(REPLACE(@name, N'/', N'_'), N'\', N'_') + N'_${stamp}.bak';
  SET @sql = N'BACKUP DATABASE ' + QUOTENAME(@name) + N' TO DISK = ' +
    QUOTENAME(@path, '''') + N' WITH COPY_ONLY, INIT, CHECKSUM';
  EXEC sys.sp_executesql @sql;
  FETCH NEXT FROM databases INTO @name;
END
CLOSE databases; DEALLOCATE databases;
SQL
)
docker exec -e MIGRATION_QUERY="$sql_backup_query" dcfsSqlServer sh -ec '
  tool=$(command -v sqlcmd || true)
  [ -n "$tool" ] || tool=/opt/mssql-tools18/bin/sqlcmd
  "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -Q "$MIGRATION_QUERY"
'
mkdir -p "$backup_root/sqlserver"
while IFS= read -r sql_backup; do
  docker cp "dcfsSqlServer:$sql_backup" "$backup_root/sqlserver/" >/dev/null
done < <(docker exec dcfsSqlServer sh -ec "find /var/opt/mssql/backup -maxdepth 1 -type f -name 'dcfs_migration_*_${stamp}.bak' -print")
docker exec dcfsValkey sh -ec 'valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" --rdb /backup/dcfs_migration_valkey.rdb >/dev/null'
docker exec dcfsValkey_7.2 sh -ec 'valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" --rdb /backup/dcfs_migration_valkey72.rdb >/dev/null'
docker exec dcfsAuthentikServer sh -ec "tar -C /data -czf /tmp/authentik-files-$stamp.tar.gz ."
docker cp "dcfsAuthentikServer:/tmp/authentik-files-$stamp.tar.gz" "$backup_root/authentik-files.tar.gz" >/dev/null
docker exec dcfsAuthentikServer rm -f "/tmp/authentik-files-$stamp.tar.gz"
(
  cd "$backup_root"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
  sha256sum --check --quiet SHA256SUMS
)

echo 'Stopping legacy containers while preserving them for rollback...'
docker stop dcfsAuthentikWorker dcfsAuthentikServer
docker stop dcfsValkey_7.2 dcfsValkey dcfsMongoDb dcfsMariaDb dcfsSqlServer dcfsPostgres

rollback_on_error() {
  local exit_code=$?
  if (( exit_code != 0 )); then
    echo 'Migration failed; restoring the legacy stack.' >&2
    "$repo_root/scripts/rollback-to-dcfs.sh" || true
  fi
  exit "$exit_code"
}
trap rollback_on_error ERR

echo 'Starting renamed database-platform stacks...'
start_stack postgres
start_stack mariaDb
start_stack mongoDb
start_stack sqlServer
start_stack valkey
start_stack valkey72
start_stack authentik

for name in "${new_containers[@]}"; do
  wait_healthy "$name"
done

"$repo_root/scripts/check-all.sh"
"$repo_root/bootstrap/bootstrap-whaledeck.sh"
printf '%s\n' "$stamp" > "$state_dir/migrated-at"
trap - ERR

echo "Migration completed. Safety backup: $backup_root"
echo 'Legacy containers remain stopped for rollback. Run finalize-dcfs-migration.sh --confirm only after Whale Deck acceptance.'
