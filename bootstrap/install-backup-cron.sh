#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
begin='# BEGIN DATABASE PLATFORM BACKUPS'
end='# END DATABASE PLATFORM BACKUPS'
current=$(crontab -l 2>/dev/null || true)
clean=$(printf '%s\n' "$current" | awk -v begin="$begin" -v end="$end" '
  $0 == begin {skip=1; next}
  $0 == end {skip=0; next}
  !skip {print}
')

{
  printf '%s\n' "$clean"
  printf '%s\n' "$begin"
  printf "10 1 * * * /bin/bash -o pipefail -c '%s/sqlServer/scripts/backup.sh 2>&1 | logger -t database-platform-backup-sqlserver'\n" "$repo_root"
  printf "30 1 * * * /bin/bash -o pipefail -c '%s/postgres/scripts/backup.sh 2>&1 | logger -t database-platform-backup-postgres'\n" "$repo_root"
  printf "50 1 * * * /bin/bash -o pipefail -c '%s/mariaDb/scripts/backup.sh 2>&1 | logger -t database-platform-backup-mariadb'\n" "$repo_root"
  printf "10 2 * * * /bin/bash -o pipefail -c '%s/mongoDb/scripts/backup.sh 2>&1 | logger -t database-platform-backup-mongodb'\n" "$repo_root"
  printf "30 2 * * * /bin/bash -o pipefail -c '%s/valkey/scripts/backup.sh 2>&1 | logger -t database-platform-backup-valkey'\n" "$repo_root"
  printf "50 2 * * * /bin/bash -o pipefail -c '%s/valkey72/scripts/backup.sh 2>&1 | logger -t database-platform-backup-valkey72'\n" "$repo_root"
  printf "10 3 * * * /bin/bash -o pipefail -c '%s/authentik/scripts/backup.sh --files-only 2>&1 | logger -t database-platform-backup-authentik'\n" "$repo_root"
  printf '%s\n' "$end"
} | crontab -

echo "Installed idempotent daily backup schedule in the current user's crontab."
