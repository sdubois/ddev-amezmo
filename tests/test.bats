#!/usr/bin/env bats

load test_helper

# This suite has no external assertion-library dependency, so bats_load_library
# is intentionally unnecessary. GITHUB_REPO is a placeholder until publication.
export GITHUB_REPO="sdubois/ddev-amezmo"
export DDEV_NONINTERACTIVE=true
export DDEV_NO_INSTRUMENTATION=true

teardown() {
  if [[ -n "${GITHUB_ENV:-}" && -e "${GITHUB_ENV:-}" ]]; then
    printf 'DDEV_AMEZMO_LAST_TEST=%s\n' "${BATS_TEST_NAME:-unknown}" >> "$GITHUB_ENV"
  fi
}

setup() {
  setup_fixture
}

@test "publishable add-on metadata lists generated files and removal support" {
  # The actual integration smoke test runs: ddev add-on get "$addon_root"
  grep -q '^name: amezmo$' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'Replace only these add-on-managed release assets' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'providers/amezmo-production.yaml' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'providers/amezmo-staging.yaml' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'amezmo/environments/production.env' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'amezmo/environments/staging.env' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'amezmo/bin/amezmo-cli.phar' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q '^removal_actions:' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'rm -f amezmo/bin/amezmo-cli.phar' "$BATS_TEST_DIRNAME/../install.yaml"
}

@test "bundled amezmo-cli is dispatched without an environment" {
  mkdir -p "$TEST_ROOT/.ddev/amezmo/bin"
  : > "$TEST_ROOT/.ddev/amezmo/bin/amezmo-cli.phar"
  make_fake php '#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then exit 0; fi
printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/php.args"'

  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" cli whoami --output=json
  [ "$status" -eq 0 ]
  grep -q "^${TEST_ROOT}/.ddev/amezmo/bin/amezmo-cli.phar whoami --output=json$" "$BATS_TEST_TMPDIR/php.args"
}

@test "amezmo drush loads the named environment and forwards arguments unchanged" {
  mkdir -p "$TEST_ROOT/.ddev/amezmo/environments"
  cp "$HELPER" "$TEST_ROOT/.ddev/amezmo/amezmo"
  sed \
    -e 's/^export AMEZMO_AUTO_TRUST_SSH_IP=.*/export AMEZMO_AUTO_TRUST_SSH_IP=false/' \
    -e 's/^export AMEZMO_SSH_HOST=.*/export AMEZMO_SSH_HOST=production.example.test/' \
    -e 's/^export AMEZMO_SSH_PORT=.*/export AMEZMO_SSH_PORT=2201/' \
    -e 's|^export AMEZMO_SITE_URI=.*|export AMEZMO_SITE_URI=https://production.example.test|' \
    "$BATS_TEST_DIRNAME/../amezmo/environments/production.env" \
    > "$TEST_ROOT/.ddev/amezmo/environments/production.env"

  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" drush production \
    config:set system.site name "My Site" -y
  [ "$status" -eq 0 ]
  expected="cd '/webroot/current' && 'vendor/bin/drush' '--uri=https://production.example.test' 'config:set' 'system.site' 'name' 'My Site' '-y'"
  [ "$(<"$BATS_TEST_TMPDIR/drush.remote")" = "$expected" ]
}

@test "amezmo drush requires a command" {
  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" drush staging
  [ "$status" -eq 2 ]
  [[ "$output" == *"ddev amezmo drush <environment> <command>"* ]]
}

@test "provider declares pull and push commands and delegates skips to DDEV" {
  for provider in "$BATS_TEST_DIRNAME"/../providers/amezmo-*.yaml; do
    grep -q '^db_pull_command:' "$provider"
    grep -q '^files_import_command:' "$provider"
    grep -q '^db_push_command:' "$provider"
    grep -q '^files_push_command:' "$provider"
  done
  grep -q -- '--skip-db' "$BATS_TEST_DIRNAME/../README.md"
  grep -q -- '--skip-files' "$BATS_TEST_DIRNAME/../README.md"
}

@test "amezmo push delegates the named environment and flags to DDEV" {
  mkdir -p "$TEST_ROOT/.ddev/providers"
  : > "$TEST_ROOT/.ddev/providers/amezmo-production.yaml"
  make_fake ddev '#!/usr/bin/env bash
printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/ddev.args"'

  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" push production --skip-db -y
  [ "$status" -eq 0 ]
  grep -q '^push amezmo-production --skip-db -y$' "$BATS_TEST_TMPDIR/ddev.args"
  [[ "$output" == *"upload your local database and persistent storage files to Amezmo's production environment"* ]]
}

@test "generated profiles keep environments and site URIs independent" {
  production="$BATS_TEST_DIRNAME/../amezmo/environments/production.env"
  staging="$BATS_TEST_DIRNAME/../amezmo/environments/staging.env"
  grep -q '#ddev-generated' "$production"
  grep -q 'AMEZMO_ENVIRONMENT=production' "$production"
  grep -q 'AMEZMO_SITE_URI=' "$production"
  grep -q 'AMEZMO_ENVIRONMENT=staging' "$staging"
  grep -q 'AMEZMO_SITE_URI=' "$staging"
  ! grep -q 'AMEZMO_DRUSH_ALIAS' "$production"
  ! grep -q 'AMEZMO_DRUSH_ALIAS' "$staging"
  grep -q 'AMEZMO_AUTO_TRUST_SSH_IP=true' "$production"
  grep -q 'AMEZMO_AUTO_TRUST_SSH_IP=true' "$staging"
  ! grep -q 'AMEZMO_DB_' "$production"
  ! grep -q 'AMEZMO_DB_' "$staging"
}

@test "SSH access appends the current IP through the bundled amezmo-cli and retries" {
  export FAKE_SSH_FAIL_ONCE=1
  export AMEZMO_INSTANCE_ID=3503
  export AMEZMO_AUTO_TRUST_SSH_IP=true
  make_fake curl '#!/usr/bin/env bash
printf "%s\n" "203.0.113.10"'
  make_fake php '#!/usr/bin/env bash
if [[ "${1:-}" == "-r" ]]; then
  printf "%s\n" "198.51.100.10"
elif [[ "$*" == *"environments get"* ]]; then
  printf "%s\n" '{"trusted_ssh_ips":["198.51.100.10"]}'
else
  printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/amezmo-cli.args"
fi'
  mkdir -p "$TEST_ROOT/.ddev/amezmo/bin"
  : > "$TEST_ROOT/.ddev/amezmo/bin/amezmo-cli.phar"

  run bash -c 'printf "%s\n" "y" | "$1" auth' _ "$HELPER"
  [ "$status" -eq 0 ]
  grep -q 'environments update 3503 staging --trusted-ssh-ip 203.0.113.10 --yes --no-interaction --trusted-ssh-ip 198.51.100.10' "$BATS_TEST_TMPDIR/amezmo-cli.args"
  [[ "$output" == *"SSH connection succeeded"* ]]
}

@test "SSH IP update can be disabled" {
  export FAKE_SSH_FAIL=1
  export AMEZMO_AUTO_TRUST_SSH_IP=false
  run "$HELPER" auth
  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not connect to Amezmo's SSH endpoint"* ]]
}

@test "transfer and Drush actions check SSH access before operating" {
  local action
  for action in pull-db pull-files push-db push-files drush; do
    export FAKE_SSH_FAIL=1
    if [[ "$action" == "drush" ]]; then
      run "$HELPER" "$action" status
    else
      run "$HELPER" "$action"
    fi
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not connect to Amezmo's SSH endpoint"* ]]
  done
}

@test "named profile loads its own complete configuration" {
  profile_dir="$TEST_ROOT/.ddev/amezmo/environments"
  mkdir -p "$profile_dir"
  sed \
    -e 's/^export AMEZMO_SSH_HOST=.*/export AMEZMO_SSH_HOST=production.example.test/' \
    -e 's/^export AMEZMO_SSH_PORT=.*/export AMEZMO_SSH_PORT=2201/' \
    -e 's|^export AMEZMO_REMOTE_FILES_PATH=.*|export AMEZMO_REMOTE_FILES_PATH=/webroot/storage/public|' \
    -e 's|^export AMEZMO_LOCAL_FILES_PATH=.*|export AMEZMO_LOCAL_FILES_PATH=web/sites/default/files|' \
    -e 's|^export AMEZMO_SITE_URI=.*|export AMEZMO_SITE_URI=https://www.example.test|' \
    "$BATS_TEST_DIRNAME/../amezmo/environments/production.env" > "$profile_dir/production.env"
  run "$HELPER" --profile production doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Amezmo production environment"*"production.example.test:2201"* ]]
}

@test "missing named profile fails clearly" {
  run "$HELPER" --profile qa doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"Amezmo environment profile 'qa' was not found"* ]]
}

@test "amezmo pull delegates the named environment and flags to DDEV" {
  mkdir -p "$TEST_ROOT/.ddev/providers"
  : > "$TEST_ROOT/.ddev/providers/amezmo-production.yaml"
  make_fake ddev '#!/usr/bin/env bash
printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/ddev.args"'

  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" pull production --skip-db -y
  [ "$status" -eq 0 ]
  grep -q '^pull amezmo-production --skip-db -y$' "$BATS_TEST_TMPDIR/ddev.args"
}

@test "amezmo pull rejects an environment without a provider" {
  run "$BATS_TEST_DIRNAME/../commands/host/amezmo" pull qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider configuration for Amezmo environment 'qa' was not found"* ]]
}

@test "missing required configuration is actionable" {
  AMEZMO_SSH_HOST= run "$HELPER" auth
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_SSH_HOST is empty"* ]]
}

@test "doctor succeeds with mocked dependencies" {
  run "$HELPER" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"environment check passed"* ]]
}

@test "SSH connection failure is reported" {
  export FAKE_SSH_FAIL=1
  run "$HELPER" auth
  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not connect to Amezmo's SSH endpoint"* ]]
}

@test "database-only pull creates DDEV handoff dump" {
  run "$HELPER" pull-db
  [ "$status" -eq 0 ]
  [ -s "$TEST_ROOT/.ddev/.downloads/db.sql.gz" ]
  gzip -cd "$TEST_ROOT/.ddev/.downloads/db.sql.gz" | grep -q 'CREATE TABLE'
}

@test "files-only pull invokes rsync without delete" {
  run "$HELPER" pull-files
  [ "$status" -eq 0 ]
  grep -q -- '--protect-args' "$BATS_TEST_TMPDIR/rsync.args"
  grep -q '/webroot/storage/public/' "$BATS_TEST_TMPDIR/rsync.args"
  ! grep -q -- '--delete' "$BATS_TEST_TMPDIR/rsync.args"
}

@test "files-only download works without protect-args for compatibility-safe paths" {
  export FAKE_RSYNC_NO_PROTECT_ARGS=1
  run "$HELPER" pull-files
  [ "$status" -eq 0 ]
  ! grep -q -- '--protect-args' "$BATS_TEST_TMPDIR/rsync.args"
  [[ "$output" == *"compatibility-safe path mode"* ]]
  grep -q '/webroot/storage/public/' "$BATS_TEST_TMPDIR/rsync.args"
}

@test "database-only push imports the DDEV handoff dump remotely" {
  printf '%s\n' 'CREATE TABLE local_test (id int);' | gzip > "$TEST_ROOT/.ddev/.downloads/db.sql.gz"
  run "$HELPER" push-db
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: This will upload your local database"* ]]
  [[ "$output" == *"Database upload completed"* ]]
}

@test "files-only push invokes rsync without remote deletion" {
  mkdir -p "$TEST_ROOT/web/sites/default/files"
  run "$HELPER" push-files
  [ "$status" -eq 0 ]
  grep -q -- '--protect-args' "$BATS_TEST_TMPDIR/rsync.args"
  grep -q "$TEST_ROOT/web/sites/default/files/" "$BATS_TEST_TMPDIR/rsync.args"
  grep -q '/webroot/storage/public/' "$BATS_TEST_TMPDIR/rsync.args"
  ! grep -q -- '--delete' "$BATS_TEST_TMPDIR/rsync.args"
  [[ "$output" == *"WARNING: This will upload your local database"* ]]
}

@test "legacy rsync rejects paths that need protected arguments" {
  export FAKE_RSYNC_NO_PROTECT_ARGS=1
  AMEZMO_REMOTE_FILES_PATH='/webroot/storage/public files' run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not support --protect-args"* ]]
  [[ "$output" == *"AMEZMO_REMOTE_FILES_PATH"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/rsync.args" ]
}

@test "full pull building blocks both succeed" {
  run "$HELPER" auth
  [ "$status" -eq 0 ]
  run "$HELPER" pull-db
  [ "$status" -eq 0 ]
  run "$HELPER" pull-files
  [ "$status" -eq 0 ]
}

@test "dump failure is nonzero and leaves no handoff dump" {
  export FAKE_DUMP_FAIL=1
  run "$HELPER" pull-db
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_ROOT/.ddev/.downloads/db.sql.gz" ]
  [[ "$output" == *"Could not download the Amezmo database"* ]]
}

@test "rsync failure warns about partial local files" {
  export FAKE_RSYNC_FAIL=1
  run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"partially updated"* ]]
}

@test "remote Drush dump uses the site-local CLI and stays compressed" {
  run "$HELPER" pull-db
  [ "$status" -eq 0 ]
  grep -q "^cd '/webroot/current' && 'vendor/bin/drush' '--uri=https://staging.example.test' 'sql:dump' '--gzip' '--no-interaction'$" "$BATS_TEST_TMPDIR/drush.remote"
  [[ "$output" != *"TTY mode requires /dev/tty"* ]]
  gzip -t "$TEST_ROOT/.ddev/.downloads/db.sql.gz"
  [ -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'ddev-amezmo.*' -type d -print -quit 2>/dev/null)" ]
}

@test "doctor uses site-local Drush over the configured SSH connection" {
  run "$HELPER" doctor
  [ "$status" -eq 0 ]
  grep -q "^cd '/webroot/current' && 'vendor/bin/drush' '--uri=https://staging.example.test' 'status' '--no-interaction'$" "$BATS_TEST_TMPDIR/drush.remote"
  [[ "$output" != *"TTY mode requires /dev/tty"* ]]
}

@test "Drush action uses the configured remote root and site URI" {
  run "$HELPER" drush cache:rebuild --yes
  [ "$status" -eq 0 ]
  grep -q "^cd '/webroot/current' && 'vendor/bin/drush' '--uri=https://staging.example.test' 'cache:rebuild' '--yes'$" "$BATS_TEST_TMPDIR/drush.remote"
}

@test "Drush action supports a configured remote CLI path" {
  export AMEZMO_REMOTE_CLI_PATH=bin/drush
  run "$HELPER" drush status
  [ "$status" -eq 0 ]
  grep -q "^cd '/webroot/current' && 'bin/drush' '--uri=https://staging.example.test' 'status'$" "$BATS_TEST_TMPDIR/drush.remote"
}

@test "Drush action shell-quotes arbitrary argument values" {
  run "$HELPER" drush config:set system.site name "O'Brien; touch /tmp/bad"
  [ "$status" -eq 0 ]
  grep -Fq "'O'\\''Brien; touch /tmp/bad'" "$BATS_TEST_TMPDIR/drush.remote"
}

@test "Drush action requires the environment site URI" {
  export AMEZMO_SITE_URI=
  run "$HELPER" drush status
  [ "$status" -ne 0 ]
  [[ "$output" == *"Amezmo setting AMEZMO_SITE_URI is empty"* ]]
}

@test "Drush action returns the Drush exit status" {
  export FAKE_DRUSH_FAIL=1
  run "$HELPER" drush cache:rebuild
  [ "$status" -eq 27 ]
}

@test "Drush action rejects non-Drupal adapters" {
  export AMEZMO_APP_TYPE=wordpress
  run "$HELPER" drush cache:rebuild
  [ "$status" -ne 0 ]
  [[ "$output" == *"drush is available only when AMEZMO_APP_TYPE=drupal"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/drush.remote" ]
}

@test "WordPress adapter streams a remote WP-CLI dump" {
  export AMEZMO_APP_TYPE=wordpress
  export AMEZMO_REMOTE_CLI_PATH=wp
  run "$HELPER" pull-db
  [ "$status" -eq 0 ]
  [ -s "$TEST_ROOT/.ddev/.downloads/db.sql.gz" ]
  gzip -cd "$TEST_ROOT/.ddev/.downloads/db.sql.gz" | grep -q 'CREATE TABLE wordpress_test'
  [[ "$output" == *"WP-CLI"* ]]
}

@test "WordPress adapter doctor uses the remote CLI" {
  export AMEZMO_APP_TYPE=wordpress
  run "$HELPER" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"environment check passed"* ]]
}

@test "custom adapter requires explicit read-only commands" {
  export AMEZMO_APP_TYPE=custom
  unset AMEZMO_REMOTE_DB_DUMP_COMMAND AMEZMO_REMOTE_HEALTH_COMMAND
  run "$HELPER" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_REMOTE_HEALTH_COMMAND is empty"* ]]
}

@test "custom database push requires an explicit import command" {
  export AMEZMO_APP_TYPE=custom
  unset AMEZMO_REMOTE_DB_IMPORT_COMMAND
  printf '%s\n' 'CREATE TABLE local_test (id int);' | gzip > "$TEST_ROOT/.ddev/.downloads/db.sql.gz"
  run "$HELPER" push-db
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_REMOTE_DB_IMPORT_COMMAND is empty"* ]]
}

@test "unknown application adapter is rejected" {
  export AMEZMO_APP_TYPE=joomla
  run "$HELPER" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_APP_TYPE must be drupal, wordpress, or custom"* ]]
}

@test "invalid Drupal site URI is rejected" {
  AMEZMO_SITE_URI='javascript:alert(1)' run "$HELPER" pull-db
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_SITE_URI must be a complete HTTP or HTTPS URL"* ]]
}

@test "remote root path is rejected" {
  AMEZMO_REMOTE_FILES_PATH=/ run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"may not be '/'"* ]]
}

@test "local absolute path is rejected" {
  AMEZMO_LOCAL_FILES_PATH=/tmp/files run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"relative to the local project root"* ]]
}

@test "local traversal is rejected" {
  AMEZMO_LOCAL_FILES_PATH=../outside run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"may not contain '..'"* ]]
}

@test "remote shell injection syntax is rejected" {
  AMEZMO_REMOTE_FILES_PATH='/webroot/storage;touch /tmp/bad' run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"characters that cannot be used safely in an Amezmo path"* ]]
}

@test "database import failure remains DDEV framework responsibility" {
  grep -q 'DDEV will now import it' "$BATS_TEST_DIRNAME/../amezmo/amezmo"
  grep -q 'db_pull_command:' "$BATS_TEST_DIRNAME/../providers/amezmo-production.yaml"
  grep -q 'db_pull_command:' "$BATS_TEST_DIRNAME/../providers/amezmo-staging.yaml"
  ! grep -q 'ddev import-db' "$BATS_TEST_DIRNAME/../amezmo/amezmo"
}

@test "reinstallation policy preserves customized generated files" {
  grep -q 'remove their.*#ddev-generated' "$BATS_TEST_DIRNAME/../README.md"
  grep -q 'will not overwrite' "$BATS_TEST_DIRNAME/../providers/amezmo-production.yaml"
}
