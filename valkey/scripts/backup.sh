#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/valkey/backup"
backup_name="valkey_${stamp}.rdb"
temporary_name="$backup_name.partial"
mkdir -p "$backup_dir"
trap 'docker exec database-platform-valkey rm -f -- "/backup/$temporary_name" >/dev/null 2>&1 || true' EXIT
docker exec database-platform-valkey valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" --rdb "/backup/$temporary_name" >/dev/null
docker exec database-platform-valkey valkey-check-rdb "/backup/$temporary_name" >/dev/null
docker exec database-platform-valkey mv -- "/backup/$temporary_name" "/backup/$backup_name"
prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
trap - EXIT
echo "Valkey backup completed: $backup_dir/$backup_name"
