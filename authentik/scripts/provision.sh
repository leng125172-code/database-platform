#!/usr/bin/env bash
set -euo pipefail

instance_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_root=$(cd "$instance_dir/.." && pwd)
app_env="$instance_dir/.env"
database_env="$repo_root/.authentik.env"
cluster_env="$repo_root/.env"

[[ -r "$cluster_env" ]] || { echo "Missing $cluster_env" >&2; exit 1; }
[[ -r "$instance_dir/.env.example" ]] || { echo "Missing Authentik environment template" >&2; exit 1; }
[[ -r "$repo_root/.authentik.env.example" ]] || { echo "Missing Authentik database template" >&2; exit 1; }

umask 077
if [[ ! -e "$app_env" ]]; then
  cp "$instance_dir/.env.example" "$app_env"
  secret_key=$(openssl rand -hex 48)
  sed -i "s|<generate-a-long-random-secret>|$secret_key|" "$app_env"
  echo "Created $app_env with mode 0600; the secret was not printed."
fi

if [[ ! -e "$database_env" ]]; then
  cp "$repo_root/.authentik.env.example" "$database_env"
  database_password=$(openssl rand -hex 32)
  sed -i "s|<generate-a-strong-password>|$database_password|" "$database_env"
  echo "Created $database_env with mode 0600; the password was not printed."
fi
chmod 600 "$app_env" "$database_env"

set -a
# shellcheck disable=SC1090
. "$cluster_env"
# shellcheck disable=SC1090
. "$database_env"
set +a

[[ "${AUTHENTIK_POSTGRESQL__HOST}" == "postgres" ]] || { echo "Unexpected PostgreSQL host" >&2; exit 1; }
[[ "${AUTHENTIK_POSTGRESQL__NAME}" == "authentik" ]] || { echo "Unexpected PostgreSQL database" >&2; exit 1; }
[[ "${AUTHENTIK_POSTGRESQL__USER}" == "authentik" ]] || { echo "Unexpected PostgreSQL role" >&2; exit 1; }

docker inspect dcfsPostgres >/dev/null 2>&1 || { echo "dcfsPostgres is not available" >&2; exit 1; }
docker exec -i \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  dcfsPostgres \
  psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -v app_password="$AUTHENTIK_POSTGRESQL__PASSWORD" <<'SQL'
SELECT format('CREATE ROLE authentik LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authentik') \gexec
ALTER ROLE authentik WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'app_password';
SELECT 'CREATE DATABASE authentik OWNER authentik'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'authentik') \gexec
ALTER DATABASE authentik OWNER TO authentik;
REVOKE ALL ON DATABASE authentik FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE authentik TO authentik;
SQL

docker exec -i \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  dcfsPostgres \
  psql -h 127.0.0.1 -U postgres -d authentik -v ON_ERROR_STOP=1 <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO authentik;
SQL

echo "Authentik PostgreSQL database and restricted application role are ready."
