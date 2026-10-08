#!/usr/bin/env bash
set -Eeuo pipefail

exec 9>/run/lock/database-platform-workstation-update.lock
if ! flock -n 9; then
  echo "Another workstation update is already running; exiting."
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "[$(date --iso-8601=seconds)] Refreshing package metadata"
/usr/bin/apt-get update

echo "[$(date --iso-8601=seconds)] Installing available package upgrades"
/usr/bin/apt-get --yes upgrade

if [[ -f /run/reboot-required ]]; then
  echo "[$(date --iso-8601=seconds)] Reboot required; automatic reboot is intentionally disabled."
fi

echo "[$(date --iso-8601=seconds)] Workstation update completed"
