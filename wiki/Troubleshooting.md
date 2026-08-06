# Troubleshooting

- **SSH fails:** Confirm SSH is enabled, the dashboard port is current, the public key is installed, and the current IP is trusted. Test the dashboard SSH command directly.
- **Remote tools fail:** Verify `rsync` and the selected adapter command in an SSH session. Drupal also needs local `vendor/bin/drush`.
- **Database fails:** Check the application root, CLI path, or Drush alias and run the adapter's read-only health command.
- **Files fail:** Verify the environment-specific storage directory and read access for `deployer`.
- **Import fails:** DDEV may have partially replaced the local database. Fix the local DDEV/database issue and rerun the pull.
- **Rsync stops midway:** Existing local files may be partially updated; this MVP does not stage an entire files tree before replacement.
- **`--protect-args` is unsupported:** The add-on uses a legacy-safe fallback. Upgrade rsync or use safe path characters if the configured path contains unsupported characters.
