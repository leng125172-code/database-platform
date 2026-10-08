# MongoDB

MongoDB 9.0.2 runs with authorization enabled and an 8 GiB WiredTiger cache. Version 9 is required on this workstation because MongoDB 8.0 refuses to run on Linux kernels 6.19 and newer. Backups use compressed archive format and restores are guarded by `--confirm` because `--drop` replaces collections present in the archive.
