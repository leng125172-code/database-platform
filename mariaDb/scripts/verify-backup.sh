#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
backup_dir="$HDD_DATA_ROOT/mariaDb/backup"
latest=$(find "$backup_dir" -maxdepth 1 -type f -name 'mariadb_all_*.sql.gz' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
[[ -n "$latest" && -s "$latest" ]] || { echo 'No complete MariaDB backup found.' >&2; exit 1; }
gzip -t "$latest"
echo "MariaDB backup verified: $(basename "$latest")"
