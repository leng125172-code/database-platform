#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/valkey72/backup"
backup_name="valkey72_${stamp}.rdb"
mkdir -p "$backup_dir"
docker exec 'database-platform-valkey72' valkey-cli --no-auth-warning -a "$VALKEY72_PASSWORD" --rdb "/backup/$backup_name" >/dev/null
docker exec 'database-platform-valkey72' valkey-check-rdb "/backup/$backup_name" >/dev/null
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "Valkey 7.2 backup completed: $backup_dir/$backup_name"
