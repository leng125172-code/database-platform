#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' database-platform-postgres)
[[ "$health" == healthy ]] || { echo "database-platform-postgres: $health" >&2; exit 1; }
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" database-platform-postgres psql -h 127.0.0.1 -U postgres -d postgres -Atqc "SELECT version();"
