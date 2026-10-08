#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/.env"
example_file="$repo_root/.env.example"

if [[ -e "$env_file" ]]; then
  echo "Refusing to overwrite existing $env_file" >&2
  exit 1
fi

umask 077
cp "$example_file" "$env_file"

sql_password="Aa9!$(openssl rand -hex 24)"
postgres_password=$(openssl rand -hex 32)
mariadb_password=$(openssl rand -hex 32)
mongodb_password=$(openssl rand -hex 32)
valkey_password=$(openssl rand -hex 32)
valkey72_password=$(openssl rand -hex 32)

sed -i \
  -e "s|MSSQL_SA_PASSWORD=<generate-a-strong-password>|MSSQL_SA_PASSWORD=$sql_password|" \
  -e "s|POSTGRES_PASSWORD=<generate-a-strong-password>|POSTGRES_PASSWORD=$postgres_password|" \
  -e "s|MARIADB_ROOT_PASSWORD=<generate-a-strong-password>|MARIADB_ROOT_PASSWORD=$mariadb_password|" \
  -e "s|MONGODB_ROOT_PASSWORD=<generate-a-strong-password>|MONGODB_ROOT_PASSWORD=$mongodb_password|" \
  -e "s|VALKEY_PASSWORD=<generate-a-strong-password>|VALKEY_PASSWORD=$valkey_password|" \
  -e "s|VALKEY72_PASSWORD=<generate-a-strong-password>|VALKEY72_PASSWORD=$valkey72_password|" \
  "$env_file"

chmod 600 "$env_file"
echo "Created $env_file with mode 0600; secrets were not printed."
