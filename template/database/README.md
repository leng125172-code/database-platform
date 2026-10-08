# Database template

Replace the placeholders and rename `DATABASE_IMAGE` to a stack-specific variable such as `EXAMPLEDB_IMAGE`. Add that variable and its pinned digest only to the repository-root `.images.env` and `.images.env.example`, never to a runtime `.env`. Then add a health check, explicit security settings, engine-native backup/restore commands, and validate with both root environment files before starting it. Keep the network internal and connect only application containers that need database access; do not publish the database port on the host.
