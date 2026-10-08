#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/mariaDb/backup"
backup_file="$backup_dir/mariadb_all_${stamp}.sql.gz"
mkdir -p "$backup_dir"
docker exec dcfsMariaDb mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" \
  --all-databases --single-transaction --routines --events --triggers --hex-blob | gzip -9 > "$backup_file"
gzip -t "$backup_file"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "MariaDB backup completed: $backup_file"

