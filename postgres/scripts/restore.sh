#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 2 && "$2" == --confirm ]] || { echo "Usage: $0 <postgres_all.sql.gz> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/postgres/backup")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
gzip -t "$backup"
gunzip -c "$backup" | docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres \
  psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1
