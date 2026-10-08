# PostgreSQL

PostgreSQL 18.6 uses checksums and SCRAM authentication. `backup.sh` writes global roles plus one custom-format dump per database to HDD, allowing isolated restores. `restore.sh` creates a new database, refuses to overwrite an existing one, and is guarded by `--confirm`.
