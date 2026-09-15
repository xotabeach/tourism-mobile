#!/usr/bin/env bash
# Publish a built APK to the server so it can be installed from a link.
#
# The app is in neither store, so a link is the only way to hand someone a
# build. The backend serves /media as static files, so the APK goes into that
# volume under app/ and the landing proxies /download to it.
#
# This end is deliberately thin. The key in CI is restricted on the server by
# a forced command (see tourism-platform/deploy/test/apk-receive.sh), so it
# cannot open a shell, forward a port or deploy anything — it can hand over
# one APK and nothing else. All the placement logic lives there, where a
# compromised pipeline cannot rewrite it.
#
# Required protected CI variables:
#   DEPLOY_SSH_HOST, DEPLOY_SSH_PORT, DEPLOY_SSH_USER, DEPLOY_SSH_PRIVATE_KEY
#   DEPLOY_SSH_KNOWN_HOSTS  — full known_hosts line(s) or a GitLab File var.
# Optional:
#   APK_PUBLIC_BASE_URL     — printed at the end so the job log carries the link.
#
# Usage: ci-publish-apk.sh <path-to-apk> <version>

set -Eeuo pipefail

APK_PATH="${1:?usage: ci-publish-apk.sh <apk> <version>}"
VERSION="${2:?usage: ci-publish-apk.sh <apk> <version>}"

: "${DEPLOY_SSH_HOST:?DEPLOY_SSH_HOST is required}"
: "${DEPLOY_SSH_PORT:?DEPLOY_SSH_PORT is required}"
: "${DEPLOY_SSH_USER:?DEPLOY_SSH_USER is required}"
: "${DEPLOY_SSH_PRIVATE_KEY:?DEPLOY_SSH_PRIVATE_KEY is required}"
: "${DEPLOY_SSH_KNOWN_HOSTS:?DEPLOY_SSH_KNOWN_HOSTS is required (pin the host key)}"

if [[ ! -f "${APK_PATH}" ]]; then
  printf 'Error: APK not found: %s\n' "${APK_PATH}" >&2
  exit 1
fi
# The receiver accepts only this shape; failing here gives a clearer message
# than a rejected connection.
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Error: version must be major.minor.patch, got: %s\n' "${VERSION}" >&2
  exit 1
fi

materialize() {
  local value="$1" dest="$2" content
  if [[ -f "${value}" ]]; then content="$(cat "${value}")"; else content="${value}"; fi
  content="${content//$'\r'/}"
  if [[ "${content}" != *$'\n'* ]]; then content="${content//\\n/$'\n'}"; fi
  printf '%s' "${content}" > "${dest}"
  if [[ -s "${dest}" ]] && [[ "$(tail -c1 "${dest}" | wc -l)" -eq 0 ]]; then
    printf '\n' >> "${dest}"
  fi
  chmod 600 "${dest}"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "${tmp_dir}"' EXIT
key_file="${tmp_dir}/deploy_key"
known_hosts_file="${tmp_dir}/known_hosts"
materialize "${DEPLOY_SSH_PRIVATE_KEY}" "${key_file}"
materialize "${DEPLOY_SSH_KNOWN_HOSTS}" "${known_hosts_file}"
if ! ssh-keygen -y -f "${key_file}" >/dev/null 2>&1; then
  printf 'Error: DEPLOY_SSH_PRIVATE_KEY is not a usable OpenSSH private key.\n' >&2
  exit 1
fi

size="$(wc -c < "${APK_PATH}" | tr -d ' ')"
printf '==> Publishing %s (%s bytes) as version %s\n' "${APK_PATH}" "${size}" "${VERSION}"

# The APK is the whole conversation: stdin carries it, and "publish <version>"
# is the only thing the far end reads from the request line.
ssh \
  -i "${key_file}" \
  -p "${DEPLOY_SSH_PORT}" \
  -o IdentitiesOnly=yes \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="${known_hosts_file}" \
  "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" \
  "publish ${VERSION}" < "${APK_PATH}"

printf '\n==> Published.\n'
if [[ -n "${APK_PUBLIC_BASE_URL:-}" ]]; then
  printf '    %s/media/app/crimeatrip-latest.apk\n' "${APK_PUBLIC_BASE_URL%/}"
  printf '    %s/media/app/crimeatrip-%s.apk\n' "${APK_PUBLIC_BASE_URL%/}" "${VERSION}"
fi
