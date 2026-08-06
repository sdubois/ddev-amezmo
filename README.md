[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![last commit](https://img.shields.io/github/last-commit/sdubois/ddev-amezmo)](https://github.com/sdubois/ddev-amezmo/commits)

# ddev-amezmo

`ddev-amezmo` is a pull-only DDEV hosting-provider integration for PHP applications on [Amezmo](https://www.amezmo.com/). It installs independent production and staging profiles. Each profile streams one remote MySQL database into DDEV and uses `rsync` to copy one explicitly configured persistent-files directory into the local project.

It never pushes, deploys, or changes remote data. There is deliberately no `ddev push amezmo` recipe.

## Status and limitations

Each environment supports one MySQL 5.7/8.0-compatible database and one files directory on macOS, Linux, and WSL2 where DDEV and standard OpenSSH tooling work. Production and staging are included; Advanced-plan custom environments can be added by copying a profile and provider recipe. Amezmo API discovery, multiple databases/mounts per environment, Redis, Solr, workers, cron, environment-variable recreation, deployments, and native Windows are out of scope.

The automated suite uses mocked SSH and does not prove compatibility with a live Amezmo account.

## Prerequisites

- DDEV v1.24.10 or newer and a configured, running project.
- Host `ssh` and `rsync` commands.
- SSH enabled for the Amezmo instance, your public key uploaded, and your current IP allowed if trusted-IP restrictions are enabled.
- The SSH hostname and allocated port shown in Amezmo's dashboard. Amezmo normally uses public-key authentication as `deployer`.
- Remote `mysql`, `mysqldump`, and `rsync` commands.
- Database credentials and explicit remote/local files paths.

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
| `AMEZMO_REMOTE_FILES_PATH` | Files | | Persistent remote source |
| `AMEZMO_LOCAL_FILES_PATH` | Files | | Project-relative local target |
| `AMEZMO_DB_HOST` | Database | `127.0.0.1` | MySQL host as seen remotely |
| `AMEZMO_DB_PORT` | Database | `3306` | MySQL port as seen remotely |
| `AMEZMO_DB_NAME` | Database | | Database name |
| `AMEZMO_DB_USER` | Database | | Database username |
| `AMEZMO_DB_PASSWORD_VARIABLE` | Yes | Profile-specific | Name of the secret environment variable |

Developer and Business plans commonly use the same SSH endpoint for production and staging but different environment roots. Repeat the shared SSH values in both profiles and enter each environment's explicit paths and database settings. Do not calculate the staging root from the production path.

Advanced environments are isolated. Treat each as a complete profile: SSH host, SSH port, paths, and database settings may all differ. See **Custom environments** below.

Do not commit database passwords. Put the profile-specific secret variables in DDEV's normally gitignored `.ddev/config.local.yaml`:

```yaml
web_environment:
  - AMEZMO_PRODUCTION_DB_PASSWORD=replace-with-the-production-password
  - AMEZMO_STAGING_DB_PASSWORD=replace-with-the-staging-password
```

Then restart so DDEV loads the environment:

```bash
ddev restart
ddev amezmo doctor production
ddev amezmo doctor staging
ddev amezmo pull production
ddev amezmo pull staging
```

You may instead export the variable before invoking DDEV or temporarily override values through DDEV's provider mechanism:

```bash
ddev amezmo pull staging --environment="AMEZMO_STAGING_DB_PASSWORD=temporary-password"
```

Be aware that command-line secrets can be saved in shell history, so `config.local.yaml` is recommended for the password.

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

1. Copy `.ddev/amezmo/environments/staging.env` to `.ddev/amezmo/environments/qa.env` and set `AMEZMO_ENVIRONMENT=qa` plus all connection values.
2. Give it a unique secret name such as `AMEZMO_QA_DB_PASSWORD` and add that value to `.ddev/config.local.yaml`.
3. Copy `.ddev/providers/amezmo-staging.yaml` to `.ddev/providers/amezmo-qa.yaml` and replace each `--profile staging` with `--profile qa`.
4. Run `ddev restart`, `ddev amezmo doctor qa`, and `ddev amezmo pull qa`.

Custom profile and provider files are project-owned and are not removed by add-on uninstall.

## Credential protection and path safety

The database password is never added to SSH or MySQL command arguments and normal output never prints it. For a dump or database check, the helper builds a mode-0600 temporary script, sends it through SSH standard input, creates a mode-0600 MySQL defaults file remotely, and removes both with traps. The compressed dump is staged in a private temporary directory and moved to DDEV's standard download handoff only after success.

Connection and database identifiers are restricted to non-shell syntax. Remote paths must be absolute, non-root paths with a conservative character set. Local paths must be project-relative, non-root, and cannot contain `..`. OpenSSH argument arrays, quoting, and rsync protected-argument mode prevent configuration values from becoming shell commands.

## Troubleshooting

- **SSH fails:** Confirm SSH is enabled, the dashboard port is current, your public key is installed, your IP is trusted, and accept the host key only after independently verifying it. Test the dashboard's SSH command directly.
- **Doctor reports remote tools:** Amezmo must provide `mysql`, `mysqldump`, and `rsync` in the SSH session's `PATH`.
- **Database fails:** Verify the database values as seen from the remote instance. The database is generally private, so `AMEZMO_DB_HOST=127.0.0.1` is common but not guaranteed.
- **Files fail:** Verify the environment-specific storage directory in the Amezmo dashboard and ensure `deployer` can read it.
- **Import fails after download:** DDEV may have partially replaced the local database. Correct the local DDEV/database issue and rerun the pull.
- **Rsync fails midway:** Existing local files may be partially updated; this MVP does not stage an entire files tree before replacement.

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

DDEV removes generated add-on files. Customized or additional profile/provider files may require manual removal. Keep `.ddev/config.local.yaml` if it contains other project secrets; remove the `AMEZMO_*_DB_PASSWORD` entries yourself when no longer needed.

## Development and testing

```bash
shellcheck amezmo/amezmo commands/host/amezmo tests/*.bash
bats tests/test.bats
ddev add-on get "$PWD"
```

The Bats suite mocks network and database tools and needs no Amezmo account. CI validates YAML, runs ShellCheck and Bats, and performs a local add-on installation smoke test with DDEV when Docker is available.

## Security warning

Pulling production data replaces local data and may copy sensitive customer content onto a developer machine. Follow your organization's data-handling rules. This add-on is intentionally incapable of pushing local data to Amezmo.
