#!/usr/bin/env bash
set -Eeuo pipefail

addon_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$(mktemp -d "${TMPDIR:-/tmp}/ddev-amezmo-install.XXXXXX")"
project_name="ddev-amezmo-install-${project_dir##*.}"
cleanup() {
  (cd "$project_dir" && ddev delete -Oy >/dev/null 2>&1) || true
  rm -rf "$project_dir"
}
trap cleanup EXIT HUP INT TERM

cd "$project_dir"
ddev config --project-type=php --docroot=. --project-name="$project_name"
ddev add-on get "$addon_root"
test -x .ddev/amezmo/amezmo
test -x .ddev/commands/host/amezmo
test -f .ddev/amezmo/bin/amezmo-cli.phar
test -f .ddev/amezmo/bin/amezmo-cli.phar.sha256
test -f .ddev/providers/amezmo-production.yaml
test -f .ddev/providers/amezmo-staging.yaml
test -f .ddev/amezmo/environments/production.env
test -f .ddev/amezmo/environments/staging.env
ddev amezmo cli --version | grep -q 'amezmo-cli 0.1.0-beta.1'
ddev add-on get "$addon_root"
ddev add-on remove amezmo
test ! -e .ddev/amezmo/amezmo
test ! -e .ddev/amezmo/bin/amezmo-cli.phar
test ! -e .ddev/amezmo/bin/amezmo-cli.phar.sha256
