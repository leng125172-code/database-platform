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
}
