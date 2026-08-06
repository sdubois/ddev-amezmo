# Files and database behavior

Typical local files targets are:

- Drupal: `web/sites/default/files`
- WordPress: `wp-content/uploads`
- Laravel: `storage/app/public`

Amezmo production persistent storage is commonly `/webroot/storage`; staging has a separate environment root. Verify both paths in the dashboard rather than guessing.

Files pulls do not use `--delete`. They exclude Git metadata, dotenv files, SQL dumps, logs, cache directories, and deployment release directories. Remote owner and group IDs are not preserved.

Database credentials remain in the remote application configuration. They are not requested, copied, or printed locally. The compressed dump is staged privately and handed to DDEV only after a successful download.
