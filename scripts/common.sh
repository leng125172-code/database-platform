#!/usr/bin/env bash
set -euo pipefail

instance_dir=$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)
repo_root=$(cd "$instance_dir/.." && pwd)
env_file="$repo_root/.env"
images_env="$repo_root/.images.env"
compose_file="$instance_dir/compose.yml"

require_env() {
  [[ -r "$images_env" ]] || { echo "Missing $images_env" >&2; exit 1; }
  [[ -r "$env_file" ]] || { echo "Missing $env_file" >&2; exit 1; }
}

compose() {
  require_env
  docker compose --env-file "$images_env" --env-file "$env_file" -f "$compose_file" "$@"
}

load_env() {
  require_env
  set -a
  # shellcheck disable=SC1090
  . "$images_env"
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
}

prune_old_backups() {
  local backup_dir=$1
  local retention_days=$2
  find "$backup_dir" -type f -mtime "+$retention_days" -delete
  find "$backup_dir" -depth -mindepth 1 -type d -empty -mtime "+$retention_days" -delete

  local retention_count=${BACKUP_RETENTION_COUNT:-0}
  [[ "$retention_count" =~ ^[0-9]+$ ]] || { echo 'BACKUP_RETENTION_COUNT must be an integer.' >&2; return 2; }
  (( retention_count > 0 )) || return 0
  mapfile -t generations < <(
    find "$backup_dir" -maxdepth 1 -type f ! -name '*.partial*' -printf '%f\n' |
      sed -nE 's/.*_([0-9]{8}_[0-9]{6})\..*/\1/p' |
      sort -r -u
  )
  local generation
  for generation in "${generations[@]:retention_count}"; do
    find "$backup_dir" -maxdepth 1 -type f -name "*_${generation}.*" -delete
  done
}
