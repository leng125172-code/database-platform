#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' dcfsPostgres)
[[ "$health" == healthy ]] || { echo "dcfsPostgres: $health" >&2; exit 1; }
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" dcfsPostgres psql -h 127.0.0.1 -U postgres -d postgres -Atqc "SELECT version();"
