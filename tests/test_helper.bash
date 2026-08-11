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
  export AMEZMO_AUTO_TRUST_SSH_IP=false
  export AMEZMO_APP_TYPE=drupal
  export AMEZMO_SSH_HOST=example.test
  export AMEZMO_SSH_PORT=2222
  export AMEZMO_SSH_USER=deployer
  export AMEZMO_REMOTE_APP_ROOT=/webroot/current
  export AMEZMO_SITE_URI=https://staging.example.test
  export AMEZMO_REMOTE_FILES_PATH=/webroot/storage/public
  export AMEZMO_LOCAL_FILES_PATH=web/sites/default/files
  unset FAKE_SSH_FAIL FAKE_SSH_FAIL_ONCE FAKE_DUMP_FAIL FAKE_DRUSH_FAIL FAKE_RSYNC_FAIL FAKE_RSYNC_NO_PROTECT_ARGS FAKE_CAPTURE

  make_fake ssh '#!/usr/bin/env bash
set -eu
if [[ "${FAKE_SSH_FAIL:-}" == 1 ]]; then exit 23; fi
if [[ "${FAKE_SSH_FAIL_ONCE:-}" == 1 && ! -e "${BATS_TEST_TMPDIR}/ssh.failed" ]]; then touch "${BATS_TEST_TMPDIR}/ssh.failed"; exit 23; fi
last_arg="${!#}"
if [[ "$last_arg" == *"/drush"* ]]; then
  printf "%s\n" "$last_arg" > "${BATS_TEST_TMPDIR}/drush.remote"
  [[ "${FAKE_DRUSH_FAIL:-}" != 1 ]] || exit 27
  if [[ "$last_arg" == *"sql:dump"* ]]; then
    [[ "$last_arg" == *"--no-interaction"* ]] || { printf "%s\n" "TTY mode requires /dev/tty to be read/writable." >&2; exit 26; }
    [[ "${FAKE_DUMP_FAIL:-}" != 1 ]] || exit 24
    printf "%s\n" "diagnostic output belongs on stderr" >&2
    printf "%s\n" "CREATE TABLE test (id int);" | gzip
  elif [[ "$last_arg" == *"sql:cli"* ]]; then
    cat >/dev/null
  fi
elif [[ "$*" == *"db export"* ]]; then
  [[ "${FAKE_DUMP_FAIL:-}" != 1 ]] || exit 24
  printf "%s\n" "CREATE TABLE wordpress_test (id int);"
fi'
  make_fake rsync '#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]]; then
  if [[ "${FAKE_RSYNC_NO_PROTECT_ARGS:-}" != 1 ]]; then
    printf "%s\n" "  --protect-args           protect args from remote shell"
  else
    printf "%s\n" "  --safe-links             ignore unsafe symlinks"
  fi
  exit 0
fi
[[ "${FAKE_RSYNC_FAIL:-}" != 1 ]] || exit 25
printf "%s\n" "$*" > "${BATS_TEST_TMPDIR}/rsync.args"'
}

make_fake() {
  local name="$1" body="$2"
  printf '%s\n' "$body" > "$FAKE_BIN/$name"
  chmod +x "$FAKE_BIN/$name"
}
