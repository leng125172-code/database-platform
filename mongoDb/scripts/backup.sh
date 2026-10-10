#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/mongoDb/backup"
backup_name="mongodb_all_${stamp}.archive.gz"
temporary_name="$backup_name.partial"
mkdir -p "$backup_dir"
trap 'docker exec database-platform-mongodb rm -f -- "/backup/$temporary_name" >/dev/null 2>&1 || true' EXIT
docker exec database-platform-mongodb mongodump \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --archive="/backup/$temporary_name" --gzip
test -s "$backup_dir/$temporary_name"
docker exec database-platform-mongodb mv -- "/backup/$temporary_name" "/backup/$backup_name"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
trap - EXIT
echo "MongoDB backup completed: $backup_dir/$backup_name"
