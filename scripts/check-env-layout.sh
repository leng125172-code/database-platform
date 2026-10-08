#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
images_env="$repo_root/.images.env"
cluster_env="$repo_root/.env"
authentik_env="$repo_root/authentik/.env"

for file in "$images_env" "$cluster_env" "$authentik_env"; do
  [[ -r "$file" ]] || { echo "Missing $file" >&2; exit 1; }
done

if [[ -e "$repo_root/.authentik.env" ]]; then
  echo "Legacy $repo_root/.authentik.env must be merged into authentik/.env and removed." >&2
  exit 1
fi

for file in "$cluster_env" "$authentik_env"; do
  if grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*_IMAGE[[:space:]]*=' "$file"; then
    echo "Image variables are allowed only in $images_env; found one in $file" >&2
    exit 1
  fi
done

required_images=(
  MSSQL_IMAGE
  POSTGRES_IMAGE
  MARIADB_IMAGE
  MONGODB_IMAGE
  VALKEY_IMAGE
  VALKEY72_IMAGE
  AUTHENTIK_IMAGE
)
for variable in "${required_images[@]}"; do
  grep -Eq "^[[:space:]]*${variable}[[:space:]]*=" "$images_env" \
    || { echo "Missing $variable in $images_env" >&2; exit 1; }
done

required_authentik=(
  AUTHENTIK_SECRET_KEY
  AUTHENTIK_POSTGRESQL__HOST
  AUTHENTIK_POSTGRESQL__PORT
  AUTHENTIK_POSTGRESQL__NAME
  AUTHENTIK_POSTGRESQL__USER
  AUTHENTIK_POSTGRESQL__PASSWORD
  AUTHENTIK_POSTGRESQL__SSLMODE
)
for variable in "${required_authentik[@]}"; do
  grep -Eq "^[[:space:]]*${variable}[[:space:]]*=" "$authentik_env" \
    || { echo "Missing $variable in $authentik_env" >&2; exit 1; }
done

echo 'Environment layout is valid: images are centralized and Authentik uses one runtime file.'
