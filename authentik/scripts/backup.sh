#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_app_env
mode=${1:-full}
[[ "$mode" == "full" || "$mode" == "--files-only" ]] || {
  echo "Usage: $0 [--files-only]" >&2
  exit 2
}
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$AUTHENTIK_DATA_ROOT/backup"
archive="$backup_dir/authentik_files_${stamp}.tar.gz"
tmp_archive="${archive}.tmp"
mkdir -p "$backup_dir"

if [[ "$mode" == "full" ]]; then
  "$repo_root/postgres/scripts/backup.sh"
fi
tar --numeric-owner -C "$AUTHENTIK_DATA_ROOT/data" -czf "$tmp_archive" .
mv "$tmp_archive" "$archive"
find "$backup_dir" -type f -name 'authentik_files_*.tar.gz' -mtime "+$BACKUP_RETENTION_DAYS" -delete
if [[ "$mode" == "full" ]]; then
  echo "Authentik PostgreSQL and file backup completed: $archive"
else
  echo "Authentik file backup completed: $archive"
fi
