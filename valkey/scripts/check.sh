#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' dcfsValkey)
[[ "$health" == healthy ]] || { echo "dcfsValkey: $health" >&2; exit 1; }
docker exec dcfsValkey valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" INFO server | awk -F: '/^valkey_version:/ {gsub(/\r/, "", $2); print "Valkey " $2}'

