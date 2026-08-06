# Custom environments

For an Advanced-plan environment such as `qa`:

1. Copy `.ddev/amezmo/environments/staging.env` to `qa.env` and set `AMEZMO_ENVIRONMENT=qa` plus all SSH, path, and adapter values.
2. Copy `.ddev/providers/amezmo-staging.yaml` to `amezmo-qa.yaml` and replace each `--profile staging` with `--profile qa`.
3. Run `ddev restart`, `ddev amezmo doctor qa`, and `ddev amezmo pull qa`.

Do not infer custom endpoints, paths, storage, or databases from production. Custom profile and provider files are project-owned and are not removed by add-on uninstall.
