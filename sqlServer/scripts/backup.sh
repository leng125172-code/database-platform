#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
stamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HDD_DATA_ROOT/sqlServer/backup"
mkdir -p "$backup_dir"

docker exec -i database-platform-sqlserver bash -ec '
  tool=$(command -v sqlcmd || true)
  [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
  "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b
' <<SQL
SET NOCOUNT ON;
DECLARE @name sysname, @sql nvarchar(max), @file nvarchar(4000);
DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
  SELECT name FROM sys.databases WHERE database_id > 4 AND state_desc = 'ONLINE';
OPEN dbs;
FETCH NEXT FROM dbs INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @file = N'/var/opt/mssql/backup/' + @name + N'_${stamp}.bak';
  SET @sql = N'BACKUP DATABASE ' + QUOTENAME(@name) +
             N' TO DISK = N''' + REPLACE(@file, '''', '''''') +
             N''' WITH INIT, COMPRESSION, CHECKSUM, STATS = 10';
  EXEC sys.sp_executesql @sql;
  FETCH NEXT FROM dbs INTO @name;
END
CLOSE dbs;
DEALLOCATE dbs;
SQL

docker exec -i database-platform-sqlserver bash -ec '
  tool=$(command -v sqlcmd || true)
  [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
  "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "EXEC sys.sp_cycle_errorlog;" -b -o /dev/null
'

prune_old_backups "$backup_dir" "$BACKUP_RETENTION_DAYS"
echo "SQL Server user-database backup completed: $stamp"
