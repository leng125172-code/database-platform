#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/postgres/backup"
mkdir -p "$backup_dir"
globals_file="$backup_dir/globals_${stamp}.sql"
globals_temporary="$globals_file.partial"
trap 'rm -f -- "$globals_temporary" "$backup_dir"/*_"$stamp".dump.partial' EXIT
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
  pg_dumpall -h 127.0.0.1 -U postgres --globals-only > "$globals_temporary"
test -s "$globals_temporary"
mv -- "$globals_temporary" "$globals_file"

mapfile -t databases < <(docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
  psql -h 127.0.0.1 -U postgres -d postgres -Atqc \
  "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname;")
for database in "${databases[@]}"; do
  safe_name=$(printf '%s' "$database" | tr -c 'A-Za-z0-9_.-' '_')
  backup_file="$backup_dir/db_${safe_name}_${stamp}.dump"
  temporary="$backup_file.partial"
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
    pg_dump -h 127.0.0.1 -U postgres -d "$database" --format=custom > "$temporary"
  pg_magic=$(head -c 5 "$temporary")
  [[ "$pg_magic" == PGDMP ]] || { echo "Invalid pg_dump archive: $temporary" >&2; exit 1; }
  mv -- "$temporary" "$backup_file"
done
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
trap - EXIT
echo "PostgreSQL per-database backup set completed: $stamp"
