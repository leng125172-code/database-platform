# Database template

Replace the placeholders, add a health check, explicit security settings, engine-native backup/restore commands, and validate with `docker compose config --quiet` before starting it. Keep the network internal and connect only application containers that need database access; do not publish the database port on the host.
