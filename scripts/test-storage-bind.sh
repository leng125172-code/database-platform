#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
scratch=$(mktemp -d /tmp/database-platform-bind.XXXXXXXX)
project="dbp-bind-$(openssl rand -hex 8)"
export VALIDATION_IMAGE
VALIDATION_IMAGE=$(docker inspect --format '{{.Image}}' database-platform-mariadb)
[[ $VALIDATION_IMAGE =~ ^sha256:[a-f0-9]{64}$ ]] || exit 1
cp "$repo_root/tests/fixtures/missing-config/compose.yml" "$scratch/compose.yml"
cleanup() {
  docker compose -p "$project" -f "$scratch/compose.yml" down >/dev/null 2>&1 || return 1
  rm -f -- "$scratch/compose.yml" "$scratch/error"
  [[ ! -d $scratch/config ]] || rmdir -- "$scratch/config"
  rmdir -- "$scratch"
}
trap cleanup EXIT
if docker compose -p "$project" -f "$scratch/compose.yml" create --no-build --pull never >"$scratch/error" 2>&1; then
  echo 'Missing configuration unexpectedly created a container.' >&2; exit 1
fi
grep -q 'bind source path does not exist' "$scratch/error" || { echo 'Missing-bind validation failed for an unrelated reason.' >&2; exit 1; }
[[ ! -e $scratch/config/missing.cnf ]] || { echo 'Missing bind source was created.' >&2; exit 1; }
[[ -z $(docker compose -p "$project" -f "$scratch/compose.yml" ps -aq) ]] || { echo 'A synthetic container was unexpectedly retained.' >&2; exit 1; }
echo 'Native missing-file bind rejection passed; no container started, no source directory created.'
