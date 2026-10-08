# MongoDB

MongoDB 7.0.41 runs with authorization enabled and an 8 GiB WiredTiger cache. The maintained 7.0 line is intentional: the workstation kernel is 7.0.0-34, which falls inside MongoDB's documented 6.19 through 7.0.13 incompatibility window for the newer TCMalloc-based releases. Upgrade MongoDB only after the host kernel reaches 7.0.14 or later. Backups use compressed archive format and restores are guarded by `--confirm` because `--drop` replaces collections present in the archive.
