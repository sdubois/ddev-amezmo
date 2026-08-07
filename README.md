[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![last commit](https://img.shields.io/github/last-commit/sdubois/ddev-amezmo)](https://github.com/sdubois/ddev-amezmo/commits)

# ddev-amezmo

`ddev-amezmo` is a DDEV integration for CMS and framework applications hosted on [Amezmo](https://www.amezmo.com/). It downloads a selected Amezmo environment's database and persistent storage files into a local DDEV project and can upload local database and persistent storage files back to a selected environment. It never deploys application code.

Production and staging profiles are installed independently. Drupal, WordPress, and custom application adapters are supported.

## Status and scope

This add-on supports one MySQL-compatible database and one persistent storage directory per environment on macOS, Linux, and WSL2. Amezmo API discovery, multiple databases or storage mounts, Redis, Solr, workers, cron, environment-variable recreation, deployments, and native Windows are out of scope. The automated suite uses mocked SSH and does not prove compatibility with a live Amezmo account.

## Prerequisites

- DDEV 1.24.10 or newer with a configured, running project.
- Host `ssh` and `rsync` commands.
- SSH access enabled for the Amezmo application environment, an added public key, and a trusted current IP when required.
- The SSH endpoint hostname and allocated port shown in Amezmo's dashboard.

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

## Configure an environment

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

Use the SSH endpoint, application root, Drush alias, and persistent storage paths for that exact Amezmo environment. Amezmo normally stores persistent data under `/webroot/storage`; staging environments can have a different storage root. Do not derive staging values from production. See the [configuration reference](https://github.com/sdubois/ddev-amezmo/wiki/Configuration) for all settings and adapter examples.

```bash
ddev restart
ddev amezmo doctor production
ddev amezmo pull production
ddev amezmo push staging
ddev amezmo cli whoami
```

Useful options include `--skip-db`, `--skip-files`, and `-y`:

```bash
ddev amezmo doctor staging
ddev amezmo pull staging --skip-db
```

`doctor` is read-only. A download can replace the local database and copy sensitive persistent storage files from Amezmo, so back up local work and follow your organization's data-handling rules.

`push` uploads the local database and persistent storage files to the selected Amezmo environment. DDEV displays a confirmation prompt, and the add-on prints an additional warning identifying the Amezmo target. Review the environment, local data, and paths carefully; uploading to production can overwrite important data. File uploads overwrite matching files but do not delete files already in the Amezmo environment. Database uploads replace the target database contents through the selected application CLI. Use `--skip-db` or `--skip-files` when only one asset type should be transferred.

The add-on also bundles the pinned `amezmo-cli` `v0.1.0-beta.1` release for Amezmo API operations:

```bash
ddev amezmo cli whoami
ddev amezmo cli environments list INSTANCE_ID
ddev amezmo cli deployments get INSTANCE_ID DEPLOYMENT_ID
```

These commands require PHP 8.3 or newer on the host. The API CLI manages Amezmo resources; it does not replace this add-on's database or persistent-storage transfers.

Drupal database uploads use `vendor/bin/drush sql:cli` in the Amezmo application release by default. WordPress database uploads use `wp db import -`. Set `AMEZMO_REMOTE_CLI_PATH` in the environment profile when the application CLI is elsewhere. Custom adapters must set `AMEZMO_REMOTE_DB_IMPORT_COMMAND`; the command receives the uncompressed SQL export on standard input.

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
