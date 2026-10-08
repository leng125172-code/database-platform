#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' dcfsMariaDb)
[[ "$health" == healthy ]] || { echo "dcfsMariaDb: $health" >&2; exit 1; }
docker exec dcfsMariaDb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -Nse "SELECT VERSION();"

