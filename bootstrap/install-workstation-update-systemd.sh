#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ $EUID -eq 0 ]] || { echo 'Run this installer with sudo.' >&2; exit 1; }

install -o root -g root -m 0644 \
  "$repo_root/bootstrap/systemd/database-platform-workstation-update.service" \
  /etc/systemd/system/database-platform-workstation-update.service
install -o root -g root -m 0644 \
  "$repo_root/bootstrap/systemd/database-platform-workstation-update.timer" \
  /etc/systemd/system/database-platform-workstation-update.timer

systemctl disable --now dcfs-workstation-update.timer >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable --now database-platform-workstation-update.timer
systemctl list-timers database-platform-workstation-update.timer --no-pager
