#!/usr/bin/env bash
# Prepare android/key.properties + keystore for CI from GitLab CI variables.
# Never prints secret values. Does not leave keystore in artifacts (caller must
# exclude android/*.jks and key.properties from artifact paths).
#
# Required CI variables:
#   ANDROID_KEYSTORE_BASE64  — base64-encoded .jks / .keystore
#   ANDROID_KEY_ALIAS
#   ANDROID_KEY_PASSWORD
#   ANDROID_STORE_PASSWORD
#
# Optional:
#   ANDROID_KEYSTORE_PATH    — default: android/ci-upload.jks (job workspace)

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ANDROID_DIR="${PROJECT_ROOT}/android"
KEYSTORE_PATH="${ANDROID_KEYSTORE_PATH:-${ANDROID_DIR}/ci-upload.jks}"
KEY_PROPS="${ANDROID_DIR}/key.properties"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf 'Error: CI variable %s is required for signed APK builds.\n' "${name}" >&2
    exit 1
  fi
}

require_var ANDROID_KEYSTORE_BASE64
require_var ANDROID_KEY_ALIAS
require_var ANDROID_KEY_PASSWORD
require_var ANDROID_STORE_PASSWORD

mkdir -p "$(dirname "${KEYSTORE_PATH}")"
printf '%s' "${ANDROID_KEYSTORE_BASE64}" | base64 -d > "${KEYSTORE_PATH}"
chmod 600 "${KEYSTORE_PATH}"

# storeFile must be absolute for Gradle when run from nested dirs.
ABS_STORE="$(cd -- "$(dirname -- "${KEYSTORE_PATH}")" && pwd)/$(basename -- "${KEYSTORE_PATH}")"

cat > "${KEY_PROPS}" <<EOF
storePassword=${ANDROID_STORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=${ABS_STORE}
EOF
chmod 600 "${KEY_PROPS}"

printf 'Prepared release signing materials at android/key.properties (secrets redacted).\n'
printf 'Keystore path: %s\n' "${ABS_STORE}"
