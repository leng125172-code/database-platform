#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
backup_dir="$HDD_DATA_ROOT/valkey/backup"
latest=$(find "$backup_dir" -maxdepth 1 -type f -name 'valkey_*.rdb' -printf '%T@ %f\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
[[ -n "$latest" && -s "$backup_dir/$latest" ]] || { echo 'No complete Valkey backup found.' >&2; exit 1; }
docker exec database-platform-valkey valkey-check-rdb "/backup/$latest" >/dev/null
echo "Valkey backup verified: $latest"
