#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
[[ $repo_root =~ ^/[A-Za-z0-9_./-]+$ ]] || { echo 'Unsupported repository path for systemd storage dependencies.' >&2; exit 1; }

configuration() {
  printf '%s\n' '# Managed by database-platform: do not start Docker before its bind-mount storage.' \
    '[Unit]' "RequiresMountsFor=$repo_root /dataNvme/DockerData /data/DockerData"
}

case ${1:-install} in
  --print) configuration; exit 0 ;;
  install) [[ $# -le 1 ]] || exit 2 ;;
  *) echo 'Usage: install-docker-storage-dependencies.sh [install|--print]' >&2; exit 2 ;;
esac
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
command -v systemctl >/dev/null
command -v mountpoint >/dev/null
mountpoint -q /data || { echo 'The HDD /data mount is unavailable; refusing to configure or start dependency storage.' >&2; exit 1; }
fragment=$(systemctl show data.mount --property=FragmentPath --value)
case $fragment in
  /run/systemd/generator*/data.mount|/etc/systemd/system/data.mount|/usr/lib/systemd/system/data.mount|/lib/systemd/system/data.mount) ;;
  *) echo 'The /data mount needs a persistent fstab or systemd unit before adding Docker dependencies.' >&2; exit 1 ;;
esac
[[ -f "$repo_root/mariaDb/config/50-server.cnf" ]] || { echo 'MariaDB configuration must be a regular file.' >&2; exit 1; }

dropin_dir=/etc/systemd/system/docker.service.d
target="$dropin_dir/database-platform-storage.conf"
[[ ! -L $dropin_dir && ! -L $target ]] || { echo 'Refusing a symlinked systemd drop-in.' >&2; exit 1; }
install -d -o root -g root -m 0755 "$dropin_dir"
if [[ -e $target ]]; then
  [[ -f $target && $(stat -c %u "$target") == 0 ]] || { echo 'Existing storage drop-in is not a root-owned regular file.' >&2; exit 1; }
  grep -qFx '# Managed by database-platform: do not start Docker before its bind-mount storage.' "$target" || {
    echo 'Existing storage drop-in is not managed by this installer; inspect it manually.' >&2; exit 1;
  }
fi
temporary=$(mktemp "$dropin_dir/.database-platform-storage.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
configuration > "$temporary"
chmod 0644 "$temporary"
chown root:root "$temporary"
if ! cmp -s "$temporary" "$target"; then
  mv -T -- "$temporary" "$target"
fi
systemctl daemon-reload
echo 'Docker storage mount dependencies installed. Docker was not restarted.'
