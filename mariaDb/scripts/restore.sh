#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 2 && "$2" == --confirm ]] || { echo "Usage: $0 <mariadb_all.sql.gz> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/mariaDb/backup")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
gzip -t "$backup"
gunzip -c "$backup" | docker exec -i database-platform-mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"

