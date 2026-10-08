#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

"$instance_dir/scripts/provision.sh"
load_app_env
mkdir -p "$AUTHENTIK_DATA_ROOT/data" "$AUTHENTIK_DATA_ROOT/backup"
chmod 0750 "$AUTHENTIK_DATA_ROOT/data" "$AUTHENTIK_DATA_ROOT/backup"
compose config --quiet
compose pull
compose up -d --wait --wait-timeout 300
"$instance_dir/scripts/check.sh"
