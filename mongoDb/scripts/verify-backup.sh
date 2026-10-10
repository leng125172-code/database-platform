#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
backup_dir="$HDD_DATA_ROOT/mongoDb/backup"
latest=$(find "$backup_dir" -maxdepth 1 -type f -name 'mongodb_all_*.archive.gz' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
[[ -n "$latest" && -s "$latest" ]] || { echo 'No complete MongoDB backup found.' >&2; exit 1; }
gzip -t "$latest"
echo "MongoDB backup verified: $(basename "$latest")"
