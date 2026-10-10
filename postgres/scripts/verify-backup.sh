#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
backup_dir="$HDD_DATA_ROOT/postgres/backup"
latest=$(find "$backup_dir" -maxdepth 1 -type f -name 'globals_*.sql' -printf '%f\n' | sed -nE 's/globals_([0-9]{8}_[0-9]{6})\.sql/\1/p' | sort -r | head -n 1)
[[ -n "$latest" && -s "$backup_dir/globals_${latest}.sql" ]] || { echo 'No complete PostgreSQL backup generation found.' >&2; exit 1; }
mapfile -t dumps < <(find "$backup_dir" -maxdepth 1 -type f -name "db_*_${latest}.dump" -printf '%f\n' | sort)
(( ${#dumps[@]} > 0 )) || { echo 'The PostgreSQL backup generation has no database archives.' >&2; exit 1; }
for dump in "${dumps[@]}"; do
  docker exec database-platform-postgres pg_restore --list "/backup/$dump" >/dev/null
done
echo "PostgreSQL backup verified: $latest (${#dumps[@]} databases)"
