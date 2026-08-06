[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![last commit](https://img.shields.io/github/last-commit/sdubois/ddev-amezmo)](https://github.com/sdubois/ddev-amezmo/commits)

# ddev-amezmo

`ddev-amezmo` is a DDEV hosting-provider integration for CMS and framework applications on [Amezmo](https://www.amezmo.com/). It downloads remote database and files into a local DDEV project and can push local database and files back to a configured environment. It never deploys application code.

Production and staging profiles are installed independently. Drupal, WordPress, and custom application adapters are supported.

## Status and scope

This add-on supports one MySQL-compatible database and one files directory per environment on macOS, Linux, and WSL2. Amezmo API discovery, multiple databases or mounts, Redis, Solr, workers, cron, environment-variable recreation, deployments, and native Windows are out of scope. The automated suite uses mocked SSH and does not prove compatibility with a live Amezmo account.

## Prerequisites

- DDEV 1.24.10 or newer with a configured, running project.
- Host `ssh` and `rsync` commands.
- Amezmo SSH access, an uploaded public key, and a trusted current IP when required.
- The SSH hostname and allocated port shown in Amezmo's dashboard.

The add-on honors `~/.ssh/config`, `IdentityFile`, SSH agents, and normal `known_hosts` verification. It never disables host-key checking. If your key is available only through DDEV's agent, run `ddev auth ssh`.

## Install

```bash
ddev config
ddev add-on get sdubois/ddev-amezmo
```

For a local checkout:

```bash
ddev add-on get /absolute/path/to/ddev-amezmo
```

Installation creates production and staging profiles under `.ddev/providers/` and `.ddev/amezmo/environments/`. Edit the environment files and remove their `#ddev-generated` markers so upgrades preserve your settings.

## Configure and pull

Set these values independently in `.ddev/amezmo/environments/production.env` and `staging.env`:

```dotenv
export AMEZMO_ENVIRONMENT=production
export AMEZMO_APP_TYPE=drupal
export AMEZMO_SSH_HOST=your-amezmo-host
export AMEZMO_SSH_PORT=12345
export AMEZMO_SSH_USER=deployer
export AMEZMO_REMOTE_APP_ROOT=/webroot/current
export AMEZMO_DRUSH_ALIAS=live
export AMEZMO_REMOTE_FILES_PATH=/webroot/storage
export AMEZMO_LOCAL_FILES_PATH=web/sites/default/files
```

Use the environment-specific SSH endpoint, application root, Drush alias, and paths shown by Amezmo. Do not derive staging values from production. See the [configuration reference](https://github.com/sdubois/ddev-amezmo/wiki/Configuration) for all settings and adapter examples.

```bash
ddev restart
ddev amezmo doctor production
ddev amezmo pull production
ddev amezmo push staging
```

Useful options include `staging`, `--skip-db`, `--skip-files`, and `-y`:

```bash
ddev amezmo doctor staging
ddev amezmo pull staging --skip-db
```

`doctor` is read-only. A pull can replace local database data and copy sensitive production files, so back up local work and follow your organization's data-handling rules.

`push` writes local database and files to the selected Amezmo environment. DDEV displays a confirmation prompt, and the add-on prints an additional warning identifying the target. Review the environment, local data, and target paths carefully; pushing to production can overwrite important data. File pushes do not delete remote files, but database pushes replace data through the selected application CLI. Use `--skip-db` or `--skip-files` when only one asset type should be transferred.

Drupal pushes use `vendor/bin/drush sql:cli` on the remote application by default. WordPress pushes use `wp db import -`. Set `AMEZMO_REMOTE_CLI_PATH` in the environment profile when the remote CLI is elsewhere. Custom adapters must set `AMEZMO_REMOTE_DB_IMPORT_COMMAND`; the command receives the uncompressed SQL dump on standard input.

## Documentation

The detailed reference is in the [GitHub Wiki](https://github.com/sdubois/ddev-amezmo/wiki):

- [Configuration](https://github.com/sdubois/ddev-amezmo/wiki/Configuration)
- [Application adapters](https://github.com/sdubois/ddev-amezmo/wiki/Application-adapters)
- [Custom environments](https://github.com/sdubois/ddev-amezmo/wiki/Custom-environments)
- [Files and database behavior](https://github.com/sdubois/ddev-amezmo/wiki/Files-and-database-behavior)
- [Troubleshooting](https://github.com/sdubois/ddev-amezmo/wiki/Troubleshooting)
- [Upgrade and uninstall](https://github.com/sdubois/ddev-amezmo/wiki/Upgrade-and-uninstall)
- [Development and testing](https://github.com/sdubois/ddev-amezmo/wiki/Development-and-testing)
- [Security and path safety](https://github.com/sdubois/ddev-amezmo/wiki/Security-and-path-safety)

## Development

```bash
shellcheck amezmo/amezmo commands/host/amezmo tests/*.bash
bats tests/test.bats
ddev add-on get "$PWD"
```

CI validates YAML, ShellCheck, Bats, and local installation when Docker is available.
