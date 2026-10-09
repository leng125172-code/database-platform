#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The operator-owned private environment is the same trusted source used by Compose.
# shellcheck disable=SC1091
source "$repo_root/.env"
: "${WHALEDECK_POSTGRES_PASSWORD:?missing dedicated PostgreSQL credential}"
: "${WHALEDECK_VALKEY_PASSWORD:?missing dedicated Valkey credential}"
: "${VALKEY_PASSWORD:?missing Valkey administration credential}"

role_ok=$(docker exec -e PGPASSWORD="$WHALEDECK_POSTGRES_PASSWORD" database-platform-postgres \
  psql --host=127.0.0.1 --username=whaledeck --dbname=whaledeck --no-psqlrc \
  --set=ON_ERROR_STOP=1 --tuples-only --no-align --command="
    SELECT current_user = 'whaledeck' AND NOT (r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication)
      AND pg_get_userbyid(d.datdba) = 'whaledeck'
    FROM pg_roles r, pg_database d WHERE r.rolname = current_user AND d.datname = current_database();")
[[ $role_ok == t ]] || { echo 'Whale Deck PostgreSQL identity/privilege check failed.' >&2; exit 1; }

# ACL DRYRUN checks permissions only; it never executes the supplied command.
docker exec -e VALKEY_PASSWORD="$VALKEY_PASSWORD" -e WHALEDECK_VALKEY_PASSWORD="$WHALEDECK_VALKEY_PASSWORD" \
  database-platform-valkey sh -ec '
    admin() { valkey-cli --raw --no-auth-warning -a "$VALKEY_PASSWORD" "$@"; }
    test "$(admin PING)" = PONG
    test "$(valkey-cli --raw --no-auth-warning --user whaledeck -a "$WHALEDECK_VALKEY_PASSWORD" PING)" = PONG
    test "$(admin ACL DRYRUN whaledeck SET whaledeck:validation:probe value EX 30)" = OK
    test "$(admin ACL DRYRUN whaledeck GET whaledeck:validation:probe)" = OK
    for verb in FLUSHALL FLUSHDB SHUTDOWN; do
      test "$(admin ACL DRYRUN whaledeck "$verb")" != OK
    done
    test "$(admin ACL DRYRUN whaledeck CONFIG GET maxmemory)" != OK
    test "$(admin ACL DRYRUN whaledeck ACL LIST)" != OK
    test "$(admin ACL DRYRUN whaledeck GET another-application:key)" != OK
    test "$(admin ACL DRYRUN whaledeck SET another-application:key value EX 30)" != OK
  '

echo 'Whale Deck database/cache credentials and restricted privileges passed; no application data was written.'
