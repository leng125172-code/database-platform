#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
load_env
health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' dcfsSqlServer)
[[ "$health" == healthy ]] || { echo "dcfsSqlServer: $health" >&2; exit 1; }
docker exec dcfsSqlServer bash -ec '
  tool=$(command -v sqlcmd || true)
  [[ -n "$tool" ]] || tool=/opt/mssql-tools18/bin/sqlcmd
  "$tool" -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "SET NOCOUNT ON; SELECT @@VERSION;" -W -b
'
