#!/usr/bin/env bash
set -euo pipefail

instance_dir=$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)
repo_root=$(cd "$instance_dir/.." && pwd)
app_env="$instance_dir/.env"
database_env="$repo_root/.authentik.env"
compose_file="$instance_dir/compose.yml"

require_env() {
  [[ -r "$app_env" ]] || { echo "Missing $app_env" >&2; exit 1; }
  [[ -r "$database_env" ]] || { echo "Missing $database_env" >&2; exit 1; }
}

load_app_env() {
  require_env
  set -a
  # shellcheck disable=SC1090
  . "$app_env"
  set +a
}

compose() {
  require_env
  docker compose --env-file "$app_env" -f "$compose_file" "$@"
}
