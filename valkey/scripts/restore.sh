#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
[[ $# -eq 2 && "$2" == --confirm ]] || { echo "Usage: $0 <valkey.rdb> --confirm" >&2; exit 2; }
backup=$(realpath "$1")
backup_root=$(realpath "$HDD_DATA_ROOT/valkey/backup")
data_root=$(realpath "$NVME_DATA_ROOT/valkey/data")
[[ "$backup" == "$backup_root"/* && -f "$backup" ]] || { echo "Backup must be a file under $backup_root" >&2; exit 2; }
[[ "$data_root" == /dataNvme/DockerData/valkey/data ]] || { echo "Unexpected data path: $data_root" >&2; exit 2; }

docker exec dcfsValkey valkey-check-rdb "/backup/$(basename "$backup")" >/dev/null
compose down
stamp=$(date +%Y%m%d_%H%M%S)
docker run --rm --user 0 \
  --entrypoint /bin/sh \
  -v "$data_root:/data" \
  -v "$backup_root:/backup" \
  "$VALKEY_IMAGE" -euc "
    mkdir -p /backup/pre-restore-$stamp
    if [ -f /data/dump.rdb ]; then mv /data/dump.rdb /backup/pre-restore-$stamp/; fi
    if [ -d /data/appendonlydir ]; then mv /data/appendonlydir /backup/pre-restore-$stamp/; fi
    cp '/backup/$(basename "$backup")' /data/dump.rdb
    chown -R valkey:valkey /data
  "
compose up -d --wait

