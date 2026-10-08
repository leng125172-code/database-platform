#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 3 && "$3" == --confirm ]] || { echo "Usage: $0 <backup.bak> <original-database-name> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/sqlServer/backup")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
database=$2
[[ "$database" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Unsafe database name" >&2; exit 2; }
container_backup="/var/opt/mssql/backup/$(basename "$backup")"

docker exec -i database-platform-sqlserver bash -ec '
  tool=$(command -v sqlcmd || true)
  [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
  "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b
' <<SQL
RESTORE VERIFYONLY FROM DISK = N'${container_backup}' WITH CHECKSUM;
IF DB_ID(N'${database}') IS NOT NULL
  THROW 50001, 'Target database already exists; restore aborted.', 1;
RESTORE DATABASE [${database}] FROM DISK = N'${container_backup}' WITH CHECKSUM, RECOVERY;
SQL

