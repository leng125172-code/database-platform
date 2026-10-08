#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' database-platform-mongodb)
[[ "$health" == healthy ]] || { echo "database-platform-mongodb: $health" >&2; exit 1; }
docker exec database-platform-mongodb mongosh --quiet \
  --username "$MONGODB_ROOT_USERNAME" --password "$MONGODB_ROOT_PASSWORD" \
  --authenticationDatabase admin --eval 'db.version()'

