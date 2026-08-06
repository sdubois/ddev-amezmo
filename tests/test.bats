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
  grep -q 'providers/amezmo-production.yaml' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'providers/amezmo-staging.yaml' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'amezmo/environments/production.env' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q 'amezmo/environments/staging.env' "$BATS_TEST_DIRNAME/../install.yaml"
  grep -q '^removal_actions:' "$BATS_TEST_DIRNAME/../install.yaml"
}

@test "provider is pull-only and delegates skips to DDEV" {
  for provider in "$BATS_TEST_DIRNAME"/../providers/amezmo-*.yaml; do
    grep -q '^db_pull_command:' "$provider"
    grep -q '^files_import_command:' "$provider"
    ! grep -q '_push_command:' "$provider"
  done
  grep -q -- '--skip-db' "$BATS_TEST_DIRNAME/../README.md"
  grep -q -- '--skip-files' "$BATS_TEST_DIRNAME/../README.md"
}

@test "generated profiles keep environments and password names independent" {
  production="$BATS_TEST_DIRNAME/../amezmo/environments/production.env"
  staging="$BATS_TEST_DIRNAME/../amezmo/environments/staging.env"
  grep -q '#ddev-generated' "$production"
  grep -q 'AMEZMO_ENVIRONMENT=production' "$production"
  grep -q 'AMEZMO_PRODUCTION_DB_PASSWORD' "$production"
  grep -q 'AMEZMO_ENVIRONMENT=staging' "$staging"
  grep -q 'AMEZMO_STAGING_DB_PASSWORD' "$staging"
  ! grep -q '^export AMEZMO_DB_PASSWORD=' "$production"
  ! grep -q '^export AMEZMO_DB_PASSWORD=' "$staging"
}

@test "named profile loads its own complete configuration" {
  profile_dir="$TEST_ROOT/.ddev/amezmo/environments"
  mkdir -p "$profile_dir"
  sed \
    -e 's/^export AMEZMO_SSH_HOST=.*/export AMEZMO_SSH_HOST=production.example.test/' \
    -e 's/^export AMEZMO_SSH_PORT=.*/export AMEZMO_SSH_PORT=2201/' \
    -e 's|^export AMEZMO_REMOTE_FILES_PATH=.*|export AMEZMO_REMOTE_FILES_PATH=/webroot/storage/public|' \
    -e 's|^export AMEZMO_LOCAL_FILES_PATH=.*|export AMEZMO_LOCAL_FILES_PATH=web/sites/default/files|' \
    -e 's/^export AMEZMO_DB_NAME=.*/export AMEZMO_DB_NAME=production_db/' \
    -e 's/^export AMEZMO_DB_USER=.*/export AMEZMO_DB_USER=production_user/' \
    "$BATS_TEST_DIRNAME/../amezmo/environments/production.env" > "$profile_dir/production.env"
  export AMEZMO_PRODUCTION_DB_PASSWORD=profile-secret

  run "$HELPER" --profile production doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"production at production.example.test:2201"* ]]
}

@test "missing named profile fails clearly" {
  run "$HELPER" --profile qa doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"environment profile 'qa' was not found"* ]]
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
  [[ "$output" == *"provider for environment 'qa' was not found"* ]]
}

@test "missing required configuration is actionable" {
  AMEZMO_SSH_HOST= run "$HELPER" auth
  [ "$status" -ne 0 ]
  [[ "$output" == *"AMEZMO_SSH_HOST is empty"* ]]
}

@test "doctor succeeds with mocked dependencies" {
  run "$HELPER" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"doctor passed"* ]]
}

@test "SSH connection failure is reported" {
  export FAKE_SSH_FAIL=1
  run "$HELPER" auth
  [ "$status" -ne 0 ]
  [[ "$output" == *"SSH connection"*"failed"* ]]
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
  grep -q '/webroot/storage/public/' "$BATS_TEST_TMPDIR/rsync.args"
  ! grep -q -- '--delete' "$BATS_TEST_TMPDIR/rsync.args"
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
  [[ "$output" == *"local database has not been imported"* ]]
}

@test "rsync failure warns about partial local files" {
  export FAKE_RSYNC_FAIL=1
  run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"partially updated"* ]]
}

@test "temporary database credentials are cleaned and secret stays out of output" {
  export FAKE_CAPTURE="$BATS_TEST_TMPDIR/remote-script"
  run "$HELPER" pull-db
  [ "$status" -eq 0 ]
  [[ "$output" != *"$AMEZMO_DB_PASSWORD"* ]]
  grep -q 'password=' "$FAKE_CAPTURE"
  [ -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'ddev-amezmo.*' -type d -print -quit 2>/dev/null)" ]
}

@test "remote root path is rejected" {
  AMEZMO_REMOTE_FILES_PATH=/ run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"may not be '/'"* ]]
}

@test "local absolute path is rejected" {
  AMEZMO_LOCAL_FILES_PATH=/tmp/files run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"relative to the project root"* ]]
}

@test "local traversal is rejected" {
  AMEZMO_LOCAL_FILES_PATH=../outside run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"may not contain '..'"* ]]
}

@test "remote shell injection syntax is rejected" {
  AMEZMO_REMOTE_FILES_PATH='/webroot/storage;touch /tmp/bad' run "$HELPER" pull-files
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsafe shell characters"* ]]
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
