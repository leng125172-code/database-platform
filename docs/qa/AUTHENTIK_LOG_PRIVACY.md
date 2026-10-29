# Authentik access-log privacy

2026-10-29: bounded inspection of the last 1,000 Authentik server lines detected JWT-shaped values in INFO events (`event`, `path`, `spans[].path`). No plaintext values were printed or added to Git. The matched unique values were six temporary validation identities' OIDC tokens, one forged validation token and seven signed-media tokens with only `exp/nbf/path` claims. The temporary identities had already been deleted. This bounded sample does not prove all historical logs are free of other credentials.

The installed 2026.8.3 logger configuration supports `AUTHENTIK_LOG_LEVEL`; the candidate changes the shared server/worker level from INFO to WARNING. This suppresses URL-bearing access events, retains operational warnings/errors, and does not change PostgreSQL identity/audit data, storage mounts, image digests, protection labels, port isolation or log rotation limits.

Runtime recreation and fresh real login/logout plus bounded server/worker log checks remain pending. Recreating the two exact containers removes their former Docker-local log objects; it is not a claim of forensic disk erasure or external backup removal. No database or bind-mount data is deleted. Secret values must never be included in validation output.
