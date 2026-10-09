#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/.env"
[[ -r "$env_file" ]] || { echo "Missing $env_file" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

: "${WHALEDECK_POSTGRES_PASSWORD:?WHALEDECK_POSTGRES_PASSWORD is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${WHALEDECK_VALKEY_PASSWORD:?WHALEDECK_VALKEY_PASSWORD is required}"
: "${VALKEY_PASSWORD:?VALKEY_PASSWORD is required}"

docker exec -i -u postgres \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  -e WHALEDECK_POSTGRES_PASSWORD="$WHALEDECK_POSTGRES_PASSWORD" \
  database-platform-postgres psql --username postgres --dbname postgres \
  --set=ON_ERROR_STOP=1 >/dev/null <<'SQL'
\getenv whaledeck_password WHALEDECK_POSTGRES_PASSWORD
SELECT format('CREATE ROLE whaledeck LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION', :'whaledeck_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'whaledeck') \gexec
SELECT format('ALTER ROLE whaledeck PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION', :'whaledeck_password') \gexec
SELECT 'CREATE DATABASE whaledeck OWNER whaledeck ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'whaledeck') \gexec
REVOKE ALL ON DATABASE whaledeck FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE whaledeck TO whaledeck;
SQL

docker exec \
  -e VALKEY_PASSWORD="$VALKEY_PASSWORD" \
  -e WHALEDECK_VALKEY_PASSWORD="$WHALEDECK_VALKEY_PASSWORD" \
  database-platform-valkey sh -ec '
    valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" ACL SETUSER whaledeck \
      on ">${WHALEDECK_VALKEY_PASSWORD}" resetkeys "~whaledeck:*" \
      +@read +@write +@connection +@scripting -config -shutdown -acl >/dev/null
    valkey-cli --no-auth-warning -a "$VALKEY_PASSWORD" ACL SAVE >/dev/null
  '

echo 'Whale Deck PostgreSQL database/role and Valkey ACL user are ready; no secret was printed.'
