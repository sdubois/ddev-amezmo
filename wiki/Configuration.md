# Configuration

Edit `.ddev/amezmo/environments/production.env` and `staging.env` independently. Remove the `#ddev-generated` marker from customized files so an add-on upgrade does not replace them.

| Key | Required | Default | Purpose |
|---|---:|---|---|
| `AMEZMO_ENVIRONMENT` | Yes | Profile name | Environment label; must match the profile filename |
| `AMEZMO_APP_TYPE` | No | `drupal` | `drupal`, `wordpress`, or `custom` |
| `AMEZMO_SSH_HOST` | Yes | | Hostname or SSH config alias |
| `AMEZMO_SSH_PORT` | Yes | | Allocated Amezmo SSH port |
| `AMEZMO_SSH_USER` | Yes | `deployer` | SSH username |
| `AMEZMO_REMOTE_APP_ROOT` | Doctor | Production: `/webroot/current` | Deployed app directory |
| `AMEZMO_DRUSH_ALIAS` | Drupal database/doctor | `live` or `staging` | Remote Drush site alias |
| `AMEZMO_REMOTE_CLI_PATH` | WordPress database/doctor | `wp` | Remote CLI executable or path |
| `AMEZMO_REMOTE_DB_DUMP_COMMAND` | Custom database | | Read-only command writing SQL to stdout |
| `AMEZMO_REMOTE_HEALTH_COMMAND` | Custom doctor | | Read-only health command |
| `AMEZMO_REMOTE_FILES_PATH` | Files | | Persistent remote source |
| `AMEZMO_LOCAL_FILES_PATH` | Files | | Project-relative local target |

Repeat shared SSH values in both profiles, but enter each environment's explicit root, adapter settings, and file paths. Advanced environments are complete, independent profiles; see [Custom environments](Custom-environments).
