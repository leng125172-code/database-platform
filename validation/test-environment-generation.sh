#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
cleanup() {
  # Remove only the known files created by this test, without recursive deletion.
  rm -f "$temporary/.env" "$temporary/.images.env" "$temporary/.env.example" "$temporary/.images.env.example" "$temporary/bootstrap/generate-env.sh"
  rmdir "$temporary/bootstrap" "$temporary"
}
trap cleanup EXIT
mkdir "$temporary/bootstrap"
cp "$root/.env.example" "$root/.images.env.example" "$temporary/"
cp "$root/bootstrap/generate-env.sh" "$temporary/bootstrap/"
bash "$temporary/bootstrap/generate-env.sh" >/dev/null
value() { sed -n "s/^${1}=//p" "$temporary/.env"; }
pg=$(value POSTGRES_PASSWORD)
wd_pg=$(value WHALEDECK_POSTGRES_PASSWORD)
cache=$(value VALKEY_PASSWORD)
wd_cache=$(value WHALEDECK_VALKEY_PASSWORD)
[[ ${#pg} -eq 64 && ${#wd_pg} -eq 64 && $pg != "$wd_pg" ]]
[[ ${#cache} -eq 64 && ${#wd_cache} -eq 64 && $cache != "$wd_cache" ]]
before=$(sha256sum "$temporary/.env")
if bash "$temporary/bootstrap/generate-env.sh" >/dev/null 2>&1; then
  echo 'FAIL: existing private file overwritten' >&2; exit 1
fi
[[ $(sha256sum "$temporary/.env") == "$before" ]]
echo 'Environment generation: dedicated credentials and overwrite protection passed.'
