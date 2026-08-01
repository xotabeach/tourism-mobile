#!/usr/bin/env bash
# Build a release-signed Android APK (and optionally install it).
#
# Prerequisites (one-time):
#   tourism-mobile/android/key.properties  (gitignored)
#   pointing at an existing .jks / .keystore — see
#   tourism-platform/docs/mobile-build-and-install.md §6.1
#
# Usage:
#   ./scripts/build-signed-apk.sh
#   ./scripts/build-signed-apk.sh --install
#   ./scripts/build-signed-apk.sh --api-url https://example.com --env test
#   ./scripts/build-signed-apk.sh --aab
#   ./scripts/build-signed-apk.sh --split-per-abi
#
# Env overrides (same as flags):
#   APP_ENV, DATA_SOURCE, API_BASE_URL

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

APP_ENV="${APP_ENV:-test}"
DATA_SOURCE="${DATA_SOURCE:-api}"
API_BASE_URL="${API_BASE_URL:-https://86-106-20-132.sslip.io}"
INSTALL=0
BUILD_AAB=0
SPLIT_PER_ABI=0
EXTRA_FLUTTER_ARGS=()

usage() {
  cat <<'EOF'
Build a release-signed Android APK with API dart-defines.

Usage:
  ./scripts/build-signed-apk.sh [options]

Options:
  --api-url URL       API_BASE_URL (default: https://86-106-20-132.sslip.io)
  --env NAME          APP_ENV: test|staging|production|local (default: test)
  --data-source NAME  DATA_SOURCE: api|mock (default: api)
  --install           adb install -r the APK after build
  --aab               Build App Bundle (.aab) for Play instead of APK
  --split-per-abi     Smaller per-ABI APKs (arm64 / armeabi / x86_64)
  -h, --help          Show this help

Examples:
  ./scripts/build-signed-apk.sh
  ./scripts/build-signed-apk.sh --install
  ./scripts/build-signed-apk.sh --api-url https://staging.example.org --env staging
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)
      API_BASE_URL="${2:?--api-url requires a value}"
      shift 2
      ;;
    --env)
      APP_ENV="${2:?--env requires a value}"
      shift 2
      ;;
    --data-source)
      DATA_SOURCE="${2:?--data-source requires a value}"
      shift 2
      ;;
    --install)
      INSTALL=1
      shift
      ;;
    --aab)
      BUILD_AAB=1
      shift
      ;;
    --split-per-abi)
      SPLIT_PER_ABI=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      EXTRA_FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command "%s" not found.\n' "$1" >&2
    exit 1
  fi
}

require_command flutter

cd "${PROJECT_ROOT}"

KEY_PROPS="${PROJECT_ROOT}/android/key.properties"
if [[ ! -f "${KEY_PROPS}" ]]; then
  cat >&2 <<EOF
Error: missing release signing file:
  ${KEY_PROPS}

Create it once (gitignored), for example:

  storePassword=...
  keyPassword=...
  keyAlias=crimeatrip
  storeFile=/absolute/path/to/tourism-mobile-upload.jks

Generate a keystore:
  mkdir -p "\$HOME/.crimeatrip-signing"
  keytool -genkey -v \\
    -keystore "\$HOME/.crimeatrip-signing/tourism-mobile-upload.jks" \\
    -keyalg RSA -keysize 2048 -validity 10000 \\
    -alias crimeatrip

Docs: tourism-platform/docs/mobile-build-and-install.md §6.1
EOF
  exit 1
fi

STORE_FILE="$(
  python3 - "${KEY_PROPS}" <<'PY'
import sys
from pathlib import Path
props = {}
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    props[k.strip()] = v.strip()
print(props.get("storeFile", ""))
PY
)"
if [[ -z "${STORE_FILE}" ]]; then
  printf 'Error: storeFile is empty in %s\n' "${KEY_PROPS}" >&2
  exit 1
fi
if [[ ! -f "${STORE_FILE}" ]]; then
  printf 'Error: keystore not found:\n  %s\n(from android/key.properties storeFile)\n' "${STORE_FILE}" >&2
  exit 1
fi

if [[ "${BUILD_AAB}" -eq 1 && "${INSTALL}" -eq 1 ]]; then
  printf 'Error: --install works with APK only, not --aab.\n' >&2
  exit 1
fi
if [[ "${BUILD_AAB}" -eq 1 && "${SPLIT_PER_ABI}" -eq 1 ]]; then
  printf 'Error: --split-per-abi is for APK only, not --aab.\n' >&2
  exit 1
fi

printf '==> Release signed Android build\n'
printf '    APP_ENV=%s\n' "${APP_ENV}"
printf '    DATA_SOURCE=%s\n' "${DATA_SOURCE}"
printf '    API_BASE_URL=%s\n' "${API_BASE_URL}"
printf '    keystore=%s\n' "${STORE_FILE}"

flutter pub get

DEFINES=(
  --dart-define="APP_ENV=${APP_ENV}"
  --dart-define="DATA_SOURCE=${DATA_SOURCE}"
  --dart-define="API_BASE_URL=${API_BASE_URL}"
)

if [[ "${BUILD_AAB}" -eq 1 ]]; then
  flutter build appbundle --release "${DEFINES[@]}" "${EXTRA_FLUTTER_ARGS[@]+"${EXTRA_FLUTTER_ARGS[@]}"}"
  ARTIFACT="${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab"
else
  BUILD_ARGS=(build apk --release)
  if [[ "${SPLIT_PER_ABI}" -eq 1 ]]; then
    BUILD_ARGS+=(--split-per-abi)
  fi
  flutter "${BUILD_ARGS[@]}" "${DEFINES[@]}" "${EXTRA_FLUTTER_ARGS[@]+"${EXTRA_FLUTTER_ARGS[@]}"}"
  if [[ "${SPLIT_PER_ABI}" -eq 1 ]]; then
    ARTIFACT_DIR="${PROJECT_ROOT}/build/app/outputs/flutter-apk"
    printf '\n==> Done. Per-ABI APKs:\n'
    ls -1 "${ARTIFACT_DIR}"/app-*-release.apk
    # Prefer arm64 for phones when installing.
    ARTIFACT="${ARTIFACT_DIR}/app-arm64-v8a-release.apk"
  else
    ARTIFACT="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
  fi
fi

if [[ ! -f "${ARTIFACT}" ]]; then
  printf 'Error: expected artifact missing:\n  %s\n' "${ARTIFACT}" >&2
  exit 1
fi

printf '\n==> Artifact:\n  %s\n' "${ARTIFACT}"
ls -lh "${ARTIFACT}"

if [[ "${INSTALL}" -eq 1 ]]; then
  require_command adb
  printf '\n==> Installing via adb...\n'
  adb install -r "${ARTIFACT}"
  printf 'Installed. Package: com.crimeatravel.tourism_mobile\n'
else
  cat <<EOF

Install on a phone (USB debugging on):
  adb install -r "${ARTIFACT}"

Or re-run with --install.
EOF
fi
