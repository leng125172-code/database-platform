#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/valkey/backup"
backup_name="valkey_${stamp}.rdb"
mkdir -p "$backup_dir"
docker exec database-platform-valkey valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" --rdb "/backup/$backup_name" >/dev/null
docker exec database-platform-valkey valkey-check-rdb "/backup/$backup_name" >/dev/null
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "Valkey backup completed: $backup_dir/$backup_name"

