#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
backup_dir="$HDD_DATA_ROOT/sqlServer/backup"
latest_stamp=$(find "$backup_dir" -maxdepth 1 -type f -name 'db_*.bak' -printf '%f\n' | sed -nE 's/.*_([0-9]{8}_[0-9]{6})\.bak/\1/p' | sort -r | head -n 1)
[[ -n "$latest_stamp" ]] || { echo 'No complete SQL Server backup generation found.' >&2; exit 1; }
mapfile -t backups < <(find "$backup_dir" -maxdepth 1 -type f -name "db_*_${latest_stamp}.bak" -printf '%f\n' | sort)
(( ${#backups[@]} > 0 )) || { echo 'The SQL Server backup generation has no archives.' >&2; exit 1; }
for backup in "${backups[@]}"; do
  docker exec database-platform-sqlserver bash -ec '
    tool=$(command -v sqlcmd || true)
    [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
    exec "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -Q "$1"
  ' -- "RESTORE VERIFYONLY FROM DISK = N'/var/opt/mssql/backup/$backup' WITH CHECKSUM;" >/dev/null
done
echo "SQL Server backup verified: $latest_stamp (${#backups[@]} databases)"
