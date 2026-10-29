# PostgreSQL

PostgreSQL 18.6 uses checksums and SCRAM authentication. `backup.sh` writes global roles plus one custom-format dump per database to HDD, allowing isolated restores. `restore.sh` creates a new database, refuses to overwrite an existing one, and is guarded by `--confirm`.

Local Unix sockets use peer authentication. The readiness probe runs as the
container's `postgres` OS user through `gosu`; running `pg_isready -U postgres`
as container root can return a ready status while logging an authentication
failure on every probe. The probe contains no password. Readiness alone does
not replace `scripts/check.sh`, backup verification, or isolated restore tests.
