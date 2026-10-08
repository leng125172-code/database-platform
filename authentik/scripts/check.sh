#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

for container in dcfsAuthentikServer dcfsAuthentikWorker; do
  state=$(docker inspect --format '{{.State.Status}}' "$container")
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container")
  [[ "$state" == "running" ]] || { echo "$container: $state" >&2; exit 1; }
  [[ "$health" == "healthy" ]] || { echo "$container health: $health" >&2; exit 1; }
  bindings=$(docker inspect --format '{{json .HostConfig.PortBindings}}' "$container")
  [[ "$bindings" == "{}" || "$bindings" == "null" ]] || { echo "$container publishes a host port: $bindings" >&2; exit 1; }
done

docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' dcfsAuthentikServer \
  | grep -Fx 'AUTHENTIK_LISTEN__HTTPS=127.0.0.1:9443' >/dev/null \
  || { echo 'Authentik HTTPS listener is not restricted to container loopback' >&2; exit 1; }

[[ "$(docker network inspect dcfsAppAuthentik --format '{{.Internal}}')" == "true" ]] \
  || { echo 'dcfsAppAuthentik is not an internal network' >&2; exit 1; }

docker exec dcfsAuthentikServer ak healthcheck >/dev/null
echo 'Authentik server and worker are healthy; HTTP is internal-only, TLS is loopback-only, and no host ports are published.'
