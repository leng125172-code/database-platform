# SQL Server

SQL Server 2025 CU9 stores database and transaction-log files on NVMe and native `.bak` files on HDD. `backup.sh` backs up every online user database with compression and checksums. `restore.sh` restores a database under its original name and refuses to overwrite an existing database.

