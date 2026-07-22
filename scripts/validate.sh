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
flutter analyze

printf 'Running flutter test...\n'
flutter test

printf 'Validation completed successfully.\n'
