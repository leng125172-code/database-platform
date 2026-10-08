#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 2 && "$2" == --confirm ]] || { echo "Usage: $0 <mongodb.archive.gz> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/mongoDb/backup")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
docker exec dcfsMongoDb mongorestore \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --archive="/backup/$(basename "$backup")" --gzip --drop

