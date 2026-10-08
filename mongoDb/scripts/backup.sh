#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/mongoDb/backup"
backup_name="mongodb_all_${stamp}.archive.gz"
mkdir -p "$backup_dir"
docker exec dcfsMongoDb mongodump \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --archive="/backup/$backup_name" --gzip
test -s "$backup_dir/$backup_name"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "MongoDB backup completed: $backup_dir/$backup_name"

