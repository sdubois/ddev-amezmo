#!/usr/bin/env bash
# shellcheck disable=SC2016

setup_fixture() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/project"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  export DDEV_APPROOT="$TEST_ROOT"
  export FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_ROOT/.ddev/.downloads" "$FAKE_BIN" "$TMPDIR"
  cp "$BATS_TEST_DIRNAME/../amezmo/amezmo" "$BATS_TEST_TMPDIR/amezmo"
  chmod +x "$BATS_TEST_TMPDIR/amezmo"
  export HELPER="$BATS_TEST_TMPDIR/amezmo"
  export PATH="$FAKE_BIN:$PATH"
  export AMEZMO_ENVIRONMENT=staging
  export AMEZMO_SSH_HOST=example.test
  export AMEZMO_SSH_PORT=2222
  export AMEZMO_SSH_USER=deployer
  export AMEZMO_REMOTE_APP_ROOT=/webroot/current
  export AMEZMO_REMOTE_FILES_PATH=/webroot/storage/public
  export AMEZMO_LOCAL_FILES_PATH=web/sites/default/files
  export AMEZMO_DB_HOST=127.0.0.1
  export AMEZMO_DB_PORT=3306
  export AMEZMO_DB_NAME=app_db
  export AMEZMO_DB_USER=app_user
  export AMEZMO_DB_PASSWORD='space $quote! and "double"'
  unset FAKE_SSH_FAIL FAKE_DUMP_FAIL FAKE_RSYNC_FAIL FAKE_CAPTURE

  make_fake ssh '#!/usr/bin/env bash
set -eu
if [[ "${FAKE_SSH_FAIL:-}" == 1 ]]; then exit 23; fi
if [[ "$*" == *"sh -s"* ]]; then
  input=$(mktemp)
  cat > "$input"
  if [[ -n "${FAKE_CAPTURE:-}" ]]; then cp "$input" "$FAKE_CAPTURE"; fi
  if grep -q mysqldump "$input"; then
    [[ "${FAKE_DUMP_FAIL:-}" != 1 ]] || exit 24
    printf "%s\n" "CREATE TABLE test (id int);"
  fi
  rm -f "$input"
fi'
  make_fake rsync '#!/usr/bin/env bash
[[ "${FAKE_RSYNC_FAIL:-}" != 1 ]] || exit 25
printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/rsync.args"'
}

make_fake() {
  local name="$1" body="$2"
  printf '%s\n' "$body" > "$FAKE_BIN/$name"
  chmod +x "$FAKE_BIN/$name"
}
