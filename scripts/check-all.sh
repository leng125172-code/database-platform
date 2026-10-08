#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failed=0
echo '== storage =='
df -h /dataNvme /data
for path in /dataNvme /data; do
  used=$(df -P "$path" | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
  if (( used >= 85 )); then
    echo "CRITICAL: $path is ${used}% full" >&2
    failed=1
  fi
done
for name in sqlServer postgres mariaDb mongoDb valkey valkey72; do
  echo "== $name =="
  if ! "$repo_root/$name/scripts/check.sh"; then
    failed=1
  fi
done
if [[ -x "$repo_root/authentik/scripts/check.sh" ]]; then
  echo '== authentik =='
  if ! "$repo_root/authentik/scripts/check.sh"; then
    failed=1
  fi
fi
exit "$failed"
