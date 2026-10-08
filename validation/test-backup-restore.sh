#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
set -a
# shellcheck disable=SC1091
. "$repo_root/.env"
set +a
stamp=$(date +%Y%m%d_%H%M%S)

sql_query() {
  local query=$1
  docker exec dcfsSqlServer bash -ec '
    tool=$(command -v sqlcmd || true)
    [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
    "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -h -1 -W -Q "$1"
  ' _ "$query"
}

pg_query() {
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres \
    psql -h 127.0.0.1 -U postgres -d "$1" -Atqc "$2"
}

maria_query() {
  docker exec dcfsMariaDb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -Nse "$1"
}

mongo_eval() {
  docker exec dcfsMongoDb mongosh --quiet \
    --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
    --authenticationDatabase admin --eval "$1"
}

cleanup() {
  set +e
  sql_query "IF DB_ID(N'dcfs_restore_test') IS NOT NULL BEGIN ALTER DATABASE [dcfs_restore_test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [dcfs_restore_test]; END" >/dev/null 2>&1
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres dropdb -h 127.0.0.1 -U postgres --if-exists dcfs_restore_test >/dev/null 2>&1
  maria_query "DROP DATABASE IF EXISTS dcfs_restore_test;" >/dev/null 2>&1
  mongo_eval "db.getSiblingDB('dcfs_restore_test').dropDatabase()" >/dev/null 2>&1
  docker exec dcfsValkey valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" DEL dcfs:restore:test >/dev/null 2>&1
  docker rm -f dcfsValkeyRestoreTest >/dev/null 2>&1
}
trap cleanup EXIT
cleanup

echo 'Testing SQL Server backup and restore...'
sql_query "CREATE DATABASE [dcfs_restore_test];" >/dev/null
sql_query "CREATE TABLE [dcfs_restore_test].dbo.probe (value int NOT NULL); INSERT INTO [dcfs_restore_test].dbo.probe VALUES (42);" >/dev/null
"$repo_root/sqlServer/scripts/backup.sh" >/dev/null
sql_backups=("$HDD_DATA_ROOT"/sqlServer/backup/dcfs_restore_test_*.bak)
sql_backup=${sql_backups[-1]}
sql_query "ALTER DATABASE [dcfs_restore_test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [dcfs_restore_test];" >/dev/null
"$repo_root/sqlServer/scripts/restore.sh" "$sql_backup" dcfs_restore_test --confirm >/dev/null
[[ $(sql_query "SET NOCOUNT ON; SELECT value FROM [dcfs_restore_test].dbo.probe;" | tr -d '[:space:]') == 42 ]]

echo 'Testing PostgreSQL backup and isolated restore...'
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres createdb -h 127.0.0.1 -U postgres dcfs_restore_test
pg_query dcfs_restore_test "CREATE TABLE probe(value integer NOT NULL); INSERT INTO probe VALUES (42);"
"$repo_root/postgres/scripts/backup.sh" >/dev/null
pg_backups=("$HDD_DATA_ROOT"/postgres/backup/db_dcfs_restore_test_*.dump)
pg_backup=${pg_backups[-1]}
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres dropdb -h 127.0.0.1 -U postgres dcfs_restore_test
"$repo_root/postgres/scripts/restore.sh" "$pg_backup" dcfs_restore_test --confirm >/dev/null
[[ $(pg_query dcfs_restore_test 'SELECT value FROM probe;') == 42 ]]

echo 'Testing MariaDB backup and restore...'
maria_query "CREATE DATABASE dcfs_restore_test; CREATE TABLE dcfs_restore_test.probe(value INT NOT NULL); INSERT INTO dcfs_restore_test.probe VALUES (42);"
"$repo_root/mariaDb/scripts/backup.sh" >/dev/null
maria_backups=("$HDD_DATA_ROOT"/mariaDb/backup/mariadb_all_*.sql.gz)
maria_backup=${maria_backups[-1]}
maria_query "DROP DATABASE dcfs_restore_test;"
"$repo_root/mariaDb/scripts/restore.sh" "$maria_backup" --confirm >/dev/null
[[ $(maria_query 'SELECT value FROM dcfs_restore_test.probe;') == 42 ]]

echo 'Testing MongoDB backup and isolated restore...'
mongo_eval "db.getSiblingDB('dcfs_restore_test').probe.insertOne({value: 42})" >/dev/null
"$repo_root/mongoDb/scripts/backup.sh" >/dev/null
mongo_restore_name="mongodb_restore_test_${stamp}.archive.gz"
docker exec dcfsMongoDb mongodump \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --db dcfs_restore_test --archive="/backup/$mongo_restore_name" --gzip >/dev/null
mongo_eval "db.getSiblingDB('dcfs_restore_test').dropDatabase()" >/dev/null
docker exec dcfsMongoDb mongorestore \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --archive="/backup/$mongo_restore_name" --gzip >/dev/null
[[ $(mongo_eval "db.getSiblingDB('dcfs_restore_test').probe.findOne().value") == 42 ]]

echo 'Testing Valkey snapshot in an isolated container...'
docker exec dcfsValkey valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" SET dcfs:restore:test 42 >/dev/null
"$repo_root/valkey/scripts/backup.sh" >/dev/null
valkey_backups=("$HDD_DATA_ROOT"/valkey/backup/valkey_*.rdb)
valkey_backup=${valkey_backups[-1]}
docker run --rm -d --name dcfsValkeyRestoreTest \
  --entrypoint valkey-server \
  -v "$valkey_backup:/data/dump.rdb:ro" \
  "$VALKEY_IMAGE" --appendonly no --save '' --protected-mode no >/dev/null
for _ in {1..20}; do
  if docker exec dcfsValkeyRestoreTest valkey-cli ping >/dev/null 2>&1; then break; fi
  sleep 1
done
[[ $(docker exec dcfsValkeyRestoreTest valkey-cli GET dcfs:restore:test) == 42 ]]

echo 'All five backup/restore validation scenarios passed.'

