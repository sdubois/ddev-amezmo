# Application adapters

## Drupal

The consuming project's local `vendor/bin/drush` is used with its configured alias:

```dotenv
export AMEZMO_APP_TYPE=drupal
export AMEZMO_DRUSH_ALIAS=live
```

## WordPress

WP-CLI runs remotely in the application root:

```dotenv
export AMEZMO_APP_TYPE=wordpress
export AMEZMO_REMOTE_CLI_PATH=wp
```

Set an absolute path if the installation does not expose `wp` on `PATH`.

## Custom

Supply read-only project-owned commands:

```dotenv
export AMEZMO_APP_TYPE=custom
export AMEZMO_REMOTE_DB_DUMP_COMMAND='php artisan db:dump --stdout'
export AMEZMO_REMOTE_HEALTH_COMMAND='php artisan about >/dev/null'
```

Commands run over SSH as the configured deployment user in `AMEZMO_REMOTE_APP_ROOT`. Do not put secrets in them.
