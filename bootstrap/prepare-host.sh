#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/.env"
[[ -r "$env_file" ]] || { echo "Missing $env_file" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
. "$env_file"
set +a

case "$NVME_DATA_ROOT" in /dataNvme/DockerData) ;; *) echo "Unexpected NVME_DATA_ROOT: $NVME_DATA_ROOT" >&2; exit 1;; esac
case "$HDD_DATA_ROOT" in /data/DockerData) ;; *) echo "Unexpected HDD_DATA_ROOT: $HDD_DATA_ROOT" >&2; exit 1;; esac

docker run --rm \
  -v /data:/hdd \
  -v /dataNvme:/nvme \
  alpine:3.22 \
  sh -euc '
    for name in sqlServer postgres mariaDb mongoDb valkey; do
      mkdir -p "/nvme/DockerData/$name/data" "/nvme/DockerData/$name/logs" "/hdd/DockerData/$name/backup"
    done
    chown -R 10001:0 /nvme/DockerData/sqlServer /hdd/DockerData/sqlServer
    chmod -R 0770 /nvme/DockerData/sqlServer /hdd/DockerData/sqlServer
  '

docker run --rm --privileged --pid=host alpine:3.22 sysctl -w vm.overcommit_memory=1 >/dev/null
echo "Prepared NVMe runtime paths, HDD backup paths, and Valkey kernel tuning."

