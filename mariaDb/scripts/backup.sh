#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/mariaDb/backup"
backup_file="$backup_dir/mariadb_all_${stamp}.sql.gz"
temporary="$backup_file.partial"
mkdir -p "$backup_dir"
trap 'rm -f -- "$temporary"' EXIT
docker exec database-platform-mariadb mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" \
  --all-databases --single-transaction --routines --events --triggers --hex-blob | gzip -9 > "$temporary"
gzip -t "$temporary"
mv -- "$temporary" "$backup_file"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
trap - EXIT
echo "MariaDB backup completed: $backup_file"
