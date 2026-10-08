# Valkey 7.2 compatibility instance

Valkey 7.2.14 is an isolated compatibility instance for applications that officially support the 7.2 release line. The container is named `dcfsValkey_7.2`, is reachable only as `valkey72:6379` on `dcfsCacheValkey72`, uses authenticated AOF/RDB persistence, and has a `noeviction` policy. It does not share data, credentials, storage, or a Docker network with the default Valkey 9 instance.
