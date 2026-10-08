#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[[ $# -eq 2 && "$2" == "--confirm" ]] || {
  echo "Usage: $0 <authentik_files_TIMESTAMP.tar.gz> --confirm" >&2
  echo "Restore the matching PostgreSQL dump separately before starting Authentik." >&2
  exit 2
}

archive=$(realpath "$1")
load_app_env
[[ "$AUTHENTIK_DATA_ROOT" == "/data/DockerData/authentik" ]] \
  || { echo "Unexpected AUTHENTIK_DATA_ROOT: $AUTHENTIK_DATA_ROOT" >&2; exit 1; }
backup_root=$(realpath "$AUTHENTIK_DATA_ROOT/backup")
[[ "$archive" == "$backup_root"/* ]] || { echo "Archive must be under $backup_root" >&2; exit 1; }
[[ -f "$archive" ]] || { echo "Archive not found: $archive" >&2; exit 1; }
tar -tzf "$archive" >/dev/null

compose down
stamp=$(date +%Y%m%d_%H%M%S)
current="$AUTHENTIK_DATA_ROOT/data"
rollback="$AUTHENTIK_DATA_ROOT/data.pre-restore-$stamp"
mv "$current" "$rollback"
mkdir -p "$current"
if ! tar --numeric-owner -xzf "$archive" -C "$current"; then
  failed="$AUTHENTIK_DATA_ROOT/data.failed-restore-$stamp"
  mv "$current" "$failed"
  mv "$rollback" "$current"
  echo "File restore failed; the previous data directory was restored and failed output remains at $failed." >&2
  exit 1
fi
echo "File restore completed. Previous files remain at $rollback. Restore the matching PostgreSQL dump, then run start.sh."
