# Security and path safety

The add-on is intentionally pull-only. It cannot push local data to Amezmo. SSH host-key checking remains enabled, and credentials are not copied to local configuration.

Remote paths must be absolute, non-root paths. Local paths must be project-relative, non-root, and cannot contain `..`. Connection and path identifiers use conservative syntax. Custom adapter commands are executable shell configuration and must be trusted and read-only.

Pulling production data replaces local database data and may copy sensitive customer content onto a developer machine. Follow organizational data-handling requirements and back up local work before pulling.
