#!/usr/bin/env bash
# Build a signed production APK locally and publish it through the restricted
# APK-only SSH receiver. No build or signing secret is sent to GitLab CI.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
LOCAL_CONFIG="${SCRIPT_DIR}/publish.env"
DRY_RUN=0

usage() {
  cat <<'EOF'
Build and publish the signed production APK.

Usage:
  ./scripts/publish-production-apk.sh [--dry-run]

Options:
  --dry-run  Validate local signing, API and SSH configuration without building
             or uploading anything.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Optional machine-specific overrides. This file is gitignored.
if [[ -f "${LOCAL_CONFIG}" ]]; then
  # shellcheck disable=SC1090
  source "${LOCAL_CONFIG}"
fi

# build.env is already the local source for API_BASE_URL used by the build
# helper. Load it here as well so the production URL can be validated before a
# lengthy release build begins.
if [[ -f "${SCRIPT_DIR}/build.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/build.env"
fi

PRODUCTION_API_BASE_URL="${MOBILE_PROD_API_BASE_URL:-${API_BASE_URL:-}}"
DEPLOY_SSH_HOST="${DEPLOY_SSH_HOST:-crimeatrip-prod}"
DEPLOY_SSH_PORT="${DEPLOY_SSH_PORT:-22}"
DEPLOY_SSH_USER="${DEPLOY_SSH_USER:-crimeatrip-deploy}"
DEPLOY_SSH_PRIVATE_KEY="${DEPLOY_SSH_PRIVATE_KEY:-${HOME}/.ssh/crimeatrip-apk-publish}"
DEPLOY_SSH_KNOWN_HOSTS="${DEPLOY_SSH_KNOWN_HOSTS:-${HOME}/.ssh/known_hosts}"
APK_PUBLIC_BASE_URL="${APK_PUBLIC_BASE_URL:-${PRODUCTION_API_BASE_URL}}"

if [[ ! "${PRODUCTION_API_BASE_URL}" =~ ^https://[^[:space:]]+$ ]]; then
  printf 'Error: set an HTTPS MOBILE_PROD_API_BASE_URL in scripts/publish.env\n' >&2
  printf '       or API_BASE_URL in scripts/build.env.\n' >&2
  exit 1
fi
if [[ ! -s "${PROJECT_ROOT}/android/key.properties" ]]; then
  printf 'Error: android/key.properties is missing; configure release signing first.\n' >&2
  exit 1
fi
if [[ ! -s "${DEPLOY_SSH_PRIVATE_KEY}" ]]; then
  printf 'Error: APK publish key not found: %s\n' "${DEPLOY_SSH_PRIVATE_KEY}" >&2
  exit 1
fi
if [[ ! -s "${DEPLOY_SSH_KNOWN_HOSTS}" ]]; then
  printf 'Error: pinned SSH known_hosts file not found: %s\n' "${DEPLOY_SSH_KNOWN_HOSTS}" >&2
  exit 1
fi

VERSION="$(awk '/^version:/ {print $2; exit}' "${PROJECT_ROOT}/pubspec.yaml")"
VERSION="${VERSION%%+*}"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Error: pubspec version must be major.minor.patch, got: %s\n' "${VERSION}" >&2
  exit 1
fi

printf 'Production APK plan:\n'
printf '  version: %s\n' "${VERSION}"
printf '  API: %s\n' "${PRODUCTION_API_BASE_URL}"
printf '  SSH target: %s@%s:%s (APK-only forced command)\n' \
  "${DEPLOY_SSH_USER}" "${DEPLOY_SSH_HOST}" "${DEPLOY_SSH_PORT}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  printf 'Dry run complete; nothing was built or uploaded.\n'
  exit 0
fi

"${SCRIPT_DIR}/build-signed-apk.sh" \
  --env production \
  --data-source api \
  --api-url "${PRODUCTION_API_BASE_URL}"

APK_PATH="${PROJECT_ROOT}/dist/CrimeaTrip-production-api.apk"
if command -v unzip >/dev/null 2>&1; then
  unzip -tq "${APK_PATH}" >/dev/null
fi

export DEPLOY_SSH_HOST DEPLOY_SSH_PORT DEPLOY_SSH_USER
export DEPLOY_SSH_PRIVATE_KEY DEPLOY_SSH_KNOWN_HOSTS APK_PUBLIC_BASE_URL
"${SCRIPT_DIR}/ci-publish-apk.sh" "${APK_PATH}" "${VERSION}"
