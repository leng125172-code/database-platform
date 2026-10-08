#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/postgres/backup"
backup_file="$backup_dir/postgres_all_${stamp}.sql.gz"
mkdir -p "$backup_dir"
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres \
  pg_dumpall -U postgres --clean --if-exists | gzip -9 > "$backup_file"
gzip -t "$backup_file"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "PostgreSQL backup completed: $backup_file"

