#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 3 && "$3" == --confirm ]] || { echo "Usage: $0 <database.dump> <new-database-name> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/postgres/backup")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
database=$2
[[ "$database" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Unsafe database name" >&2; exit 2; }
exists=$(docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
  psql -h 127.0.0.1 -U postgres -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname = '$database';")
[[ -z "$exists" ]] || { echo "Target database already exists; restore aborted." >&2; exit 2; }
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
  createdb -h 127.0.0.1 -U postgres "$database"
if ! docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
  pg_restore -h 127.0.0.1 -U postgres -d "$database" --exit-on-error < "$backup"; then
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres \
    dropdb -h 127.0.0.1 -U postgres "$database"
  exit 1
fi
