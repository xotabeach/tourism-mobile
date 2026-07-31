#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Error: required command "%s" not found.\n' "${command_name}" >&2
    exit 1
  fi
}

require_command flutter

cd "${PROJECT_ROOT}"

printf 'Resolving dependencies...\n'
flutter pub get

printf 'Checking dart format...\n'
dart format --set-exit-if-changed lib test

printf 'Running flutter analyze...\n'
flutter analyze --fatal-infos

printf 'Running flutter test...\n'
flutter test

# Pixel goldens are macOS-only (CI Linux skips them). Fail closed here so a
# push from a Mac cannot ship a stale baseline that CI would never catch.
if [[ "$(uname -s)" == "Darwin" ]]; then
  printf 'Running macOS pixel goldens...\n'
  flutter test test/golden
else
  printf 'Pixel goldens: SKIP (non-macOS host; enforced on developer Macs)\n'
fi

printf 'Validation completed successfully.\n'
