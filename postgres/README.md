# PostgreSQL

PostgreSQL 18.6 uses checksums and SCRAM authentication. `backup.sh` creates a compressed logical cluster dump on HDD. `restore.sh` is intentionally guarded by `--confirm` because it applies `--clean` statements from the dump.

