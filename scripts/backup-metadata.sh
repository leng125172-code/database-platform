#!/usr/bin/env bash
set -euo pipefail

engine=${1:-}
case "$engine" in
  postgres|mariaDb|mongoDb|sqlServer|valkey|valkey72) ;;
  *) echo 'Unsupported backup engine.' >&2; exit 2 ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/.env"
images_env="$repo_root/.images.env"
[[ -r "$images_env" ]] || { echo "Missing $images_env" >&2; exit 1; }
[[ -r "$env_file" ]] || { echo "Missing $env_file" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
. "$images_env"
# shellcheck disable=SC1090
. "$env_file"
set +a
backup_dir="$HDD_DATA_ROOT/$engine/backup"
latest_generation=$(
  find "$backup_dir" -maxdepth 1 -type f ! -name '*.partial*' -printf '%f\n' |
    sed -nE 's/.*_([0-9]{8}_[0-9]{6})\..*/\1/p' |
    sort -r -u |
    head -n 1
)
[[ -n "$latest_generation" ]] || { echo 'No completed backup generation found.' >&2; exit 1; }
mapfile -t files < <(
  find "$backup_dir" -maxdepth 1 -type f -name "*_${latest_generation}.*" ! -name '*.partial*' -printf '%f\n' |
    sort
)
(( ${#files[@]} > 0 )) || { echo 'The latest backup generation is empty.' >&2; exit 1; }

items_file=$(mktemp)
checksums_file=$(mktemp)
trap 'rm -f -- "$items_file" "$checksums_file"' EXIT
total_size=0
for name in "${files[@]}"; do
  path="$backup_dir/$name"
  size=$(stat -c %s "$path")
  checksum=$(sha256sum "$path" | awk '{print $1}')
  total_size=$((total_size + size))
  printf '%s  %s\n' "$checksum" "$name" >> "$checksums_file"
  jq -cn \
    --arg path "$engine/backup/$name" \
    --argjson sizeBytes "$size" \
    --arg sha256 "$checksum" \
    '{path:$path,sizeBytes:$sizeBytes,sha256:$sha256}' >> "$items_file"
done
manifest_checksum=$(sha256sum "$checksums_file" | awk '{print $1}')
files_json=$(jq -sc '.' "$items_file")
verified=${BACKUP_VERIFIED:-false}
[[ "$verified" == true || "$verified" == false ]] || verified=false
jq -cn \
  --arg generation "$latest_generation" \
  --arg primaryRelativePath "$engine/backup/${files[0]}" \
  --argjson totalSizeBytes "$total_size" \
  --arg checksumAlgorithm SHA256 \
  --arg checksum "$manifest_checksum" \
  --argjson verified "$verified" \
  --argjson files "$files_json" \
  '{generation:$generation,primaryRelativePath:$primaryRelativePath,totalSizeBytes:$totalSizeBytes,checksumAlgorithm:$checksumAlgorithm,checksum:$checksum,verified:$verified,files:$files}'
