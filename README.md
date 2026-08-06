[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![last commit](https://img.shields.io/github/last-commit/sdubois/ddev-amezmo)](https://github.com/sdubois/ddev-amezmo/commits)

# ddev-amezmo

`ddev-amezmo` is a pull-only DDEV hosting-provider integration for PHP applications on [Amezmo](https://www.amezmo.com/). It installs independent production and staging profiles. Each profile uses its remote Drupal/Drush site alias to stream one compressed database dump into DDEV and uses `rsync` to copy one explicitly configured persistent-files directory into the local project.

It never pushes, deploys, or changes remote data. There is deliberately no `ddev push amezmo` recipe.

## Status and limitations

Each environment supports one MySQL 5.7/8.0-compatible database and one files directory on macOS, Linux, and WSL2 where DDEV and standard OpenSSH tooling work. Production and staging are included; Advanced-plan custom environments can be added by copying a profile and provider recipe. Amezmo API discovery, multiple databases/mounts per environment, Redis, Solr, workers, cron, environment-variable recreation, deployments, and native Windows are out of scope.

The automated suite uses mocked SSH and does not prove compatibility with a live Amezmo account.

## Prerequisites

- DDEV v1.24.10 or newer and a configured, running project.
- Host `ssh` and `rsync` commands.
- SSH enabled for the Amezmo instance, your public key uploaded, and your current IP allowed if trusted-IP restrictions are enabled.
- The SSH hostname and allocated port shown in Amezmo's dashboard. Amezmo normally uses public-key authentication as `deployer`.
- A remote `vendor/bin/drush` installation with a working site alias and `rsync`.
- Explicit remote/local files paths and the corresponding Drush alias.

The add-on honors `~/.ssh/config`, `IdentityFile`, SSH agents, and normal `known_hosts` verification. It never disables host-key checking. If your key is available only through DDEV's agent, run `ddev auth ssh`; host SSH must still be able to use that agent.

## Installation

```bash
ddev config
ddev add-on get sdubois/ddev-amezmo
```

For development from a local checkout:

```bash
ddev add-on get /absolute/path/to/ddev-amezmo
```

Installation creates `.ddev/providers/amezmo-production.yaml`, `.ddev/providers/amezmo-staging.yaml`, and matching files under `.ddev/amezmo/environments/`. Edit the environment files, then remove their `#ddev-generated` lines so upgrades do not replace your settings. Remove the marker from a provider recipe only when you customize its commands.

## Configuration

Set these non-secret values independently in `.ddev/amezmo/environments/production.env` and `.ddev/amezmo/environments/staging.env`:

| Key | Required | Default | Purpose |
|---|---:|---|---|
| `AMEZMO_ENVIRONMENT` | Yes | Profile name | Environment label; must match the profile filename |
| `AMEZMO_SSH_HOST` | Yes | | Hostname or SSH config alias |
| `AMEZMO_SSH_PORT` | Yes | | Allocated Amezmo SSH port |
| `AMEZMO_SSH_USER` | Yes | `deployer` | SSH username |
| `AMEZMO_REMOTE_APP_ROOT` | Doctor | Production: `/webroot/current` | Readable environment-specific deployed app directory |
| `AMEZMO_DRUSH_ALIAS` | Database/doctor | Production: `live`; staging: `staging` | Remote Drush site alias, with or without the leading `@` |
| `AMEZMO_REMOTE_FILES_PATH` | Files | | Persistent remote source |
| `AMEZMO_LOCAL_FILES_PATH` | Files | | Project-relative local target |

Developer and Business plans commonly use the same SSH endpoint for production and staging but different environment roots and Drush aliases. Repeat the shared SSH values in both profiles and enter each environment's explicit paths and alias. Do not calculate the staging root from the production path.

Advanced environments are isolated. Treat each as a complete profile: SSH host, SSH port, paths, and Drush alias may all differ. See **Custom environments** below.

Profiles from the previous release need a small migration: remove the `AMEZMO_DB_HOST`, `AMEZMO_DB_PORT`, `AMEZMO_DB_NAME`, `AMEZMO_DB_USER`, and `AMEZMO_DB_PASSWORD_VARIABLE` lines, then add the environment's `AMEZMO_DRUSH_ALIAS`. Existing database passwords are no longer needed by this add-on.

After editing the profiles, restart so DDEV loads the environment:

```bash
ddev restart
ddev amezmo doctor production
ddev amezmo doctor staging
ddev amezmo pull production
ddev amezmo pull staging
```

### Files path examples

Amezmo documents production persistent storage at `/webroot/storage`; staging uses a separate environment root shown in the dashboard. Always verify the path rather than guessing it.

Typical local targets are:

- Drupal: `web/sites/default/files`
- WordPress: `wp-content/uploads`
- Laravel: `storage/app/public`
- Generic PHP: the application's project-relative uploads directory

The files pull does not use `--delete`. It excludes Git metadata, dotenv files, SQL dumps, logs, cache directories, and deployment release directories. It does not preserve remote owner/group IDs.

## Commands

```bash
ddev amezmo doctor production
ddev amezmo doctor staging
ddev amezmo pull production
ddev amezmo pull staging
ddev amezmo pull production --skip-db
ddev amezmo pull staging --skip-files
ddev amezmo pull production -y
```

The Amezmo command delegates pulls to DDEV's provider framework. DDEV still owns the confirmation prompt, `-y`, `--skip-db`, `--skip-files`, and `--environment` behavior. `doctor` is read-only: it checks local tools, configuration, SSH, remote directories/tools, and a `SELECT 1` database connection.

The underlying providers remain available as `ddev pull amezmo-production` and `ddev pull amezmo-staging`, but `ddev amezmo pull <environment>` is the recommended interface. DDEV does not support a second positional argument in `ddev pull`, so `ddev pull amezmo production` is not available.

### Custom environments

For an Advanced-plan environment such as `qa`:

1. Copy `.ddev/amezmo/environments/staging.env` to `.ddev/amezmo/environments/qa.env` and set `AMEZMO_ENVIRONMENT=qa` plus all SSH, path, and Drush alias values.
2. Copy `.ddev/providers/amezmo-staging.yaml` to `.ddev/providers/amezmo-qa.yaml` and replace each `--profile staging` with `--profile qa`.
3. Run `ddev restart`, `ddev amezmo doctor qa`, and `ddev amezmo pull qa`.

Custom profile and provider files are project-owned and are not removed by add-on uninstall.

## Credential protection and path safety

Database credentials remain in the remote Drupal site's configuration and are never requested, copied, or printed locally. For a dump or database check, the helper invokes the consuming project's local `vendor/bin/drush` with the configured alias; Drush then performs its one intended remote connection. The compressed dump is staged in a private temporary directory and moved to DDEV's standard download handoff only after success.

Connection and database identifiers are restricted to non-shell syntax. Remote paths must be absolute, non-root paths with a conservative character set. Local paths must be project-relative, non-root, and cannot contain `..`. When available, rsync `--protect-args` preserves safe handling for paths containing spaces and special characters. macOS's older openrsync/rsync 2.6.9 lacks that option, so the add-on detects support and uses a legacy-safe fallback only for paths containing letters, numbers, underscore, dot, slash, at-sign, plus, or hyphen; it fails clearly for other paths. OpenSSH argument arrays, quoting, and rsync's no-delete pull mode prevent configuration values from becoming shell commands.

## Troubleshooting

- **SSH fails:** Confirm SSH is enabled, the dashboard port is current, your public key is installed, your IP is trusted, and accept the host key only after independently verifying it. Test the dashboard's SSH command directly.
- **Doctor reports remote tools:** Amezmo must provide `vendor/bin/drush` under `AMEZMO_REMOTE_APP_ROOT` and `rsync` in the SSH session's `PATH`.
- **Database fails:** Run `vendor/bin/drush @live status` or `vendor/bin/drush @staging status` in the consuming project to verify the alias and its remote Drupal database connection, then copy the alias name into the selected profile.
- **Files fail:** Verify the environment-specific storage directory in the Amezmo dashboard and ensure `deployer` can read it.
- **Import fails after download:** DDEV may have partially replaced the local database. Correct the local DDEV/database issue and rerun the pull.
- **Rsync fails midway:** Existing local files may be partially updated; this MVP does not stage an entire files tree before replacement.
- **Rsync reports an unsupported `--protect-args` option:** The add-on automatically uses its legacy-safe fallback. If your configured path contains spaces or other unsupported characters, upgrade rsync or rename the path.

## Upgrade and uninstall

Upgrade with:

```bash
ddev add-on get sdubois/ddev-amezmo
```

DDEV upgrades files that retain `#ddev-generated` and preserves customized files whose marker was removed. Review release notes and merge provider changes manually when you own a customized recipe.

Remove with:

```bash
ddev add-on remove amezmo
```

DDEV removes generated add-on files. Customized or additional profile/provider files may require manual removal. Keep `.ddev/config.local.yaml` if it contains other project secrets; remove obsolete `AMEZMO_*_DB_PASSWORD` entries if they were used by an older profile format.

## Development and testing

```bash
shellcheck amezmo/amezmo commands/host/amezmo tests/*.bash
bats tests/test.bats
ddev add-on get "$PWD"
```

The Bats suite mocks network and database tools and needs no Amezmo account. CI validates YAML, runs ShellCheck and Bats, and performs a local add-on installation smoke test with DDEV when Docker is available.

## Security warning

Pulling production data replaces local data and may copy sensitive customer content onto a developer machine. Follow your organization's data-handling rules. This add-on is intentionally incapable of pushing local data to Amezmo.
