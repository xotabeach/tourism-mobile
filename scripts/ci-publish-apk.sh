#!/usr/bin/env bash
# Publish a built APK to the server so it can be installed from a link.
#
# The app is not in either store yet, so the only way to hand someone a build
# is a URL. The backend already serves /media as static files, so the APK goes
# into that same volume under app/ and is reachable at
# https://<host>/media/app/crimeatrip-latest.apk
#
# Required protected CI variables (same shape as the backend's deploy):
#   DEPLOY_SSH_HOST, DEPLOY_SSH_PORT, DEPLOY_SSH_USER, DEPLOY_SSH_PRIVATE_KEY
#   DEPLOY_SSH_KNOWN_HOSTS  — full known_hosts line(s) or a GitLab File var.
#   DEPLOY_BACKEND_CONTAINER — container whose /app/data/media to write into.
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
: "${DEPLOY_BACKEND_CONTAINER:?DEPLOY_BACKEND_CONTAINER is required}"

if [[ ! -f "${APK_PATH}" ]]; then
  printf 'Error: APK not found: %s\n' "${APK_PATH}" >&2
  exit 1
fi

# Keep the name boring: people paste this link into chats and it must not
# change between builds. The versioned copy next to it is the archive.
LATEST_NAME="crimeatrip-latest.apk"
VERSIONED_NAME="crimeatrip-${VERSION}.apk"

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
key_file="${tmp_dir}/deploy_key"
known_hosts_file="${tmp_dir}/known_hosts"
trap 'rm -rf -- "${tmp_dir}"' EXIT
materialize "${DEPLOY_SSH_PRIVATE_KEY}" "${key_file}"
materialize "${DEPLOY_SSH_KNOWN_HOSTS}" "${known_hosts_file}"
if ! ssh-keygen -y -f "${key_file}" >/dev/null 2>&1; then
  printf 'Error: DEPLOY_SSH_PRIVATE_KEY is not a usable OpenSSH private key.\n' >&2
  exit 1
fi

_common_opts=(
  -i "${key_file}"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile="${known_hosts_file}"
)
# scp spells the port -P, ssh spells it -p. Two arrays rather than rewriting
# one, so a path or port that happens to contain "-p" cannot be mangled.
ssh_opts=("${_common_opts[@]}" -p "${DEPLOY_SSH_PORT}")
scp_opts=("${_common_opts[@]}" -P "${DEPLOY_SSH_PORT}")

size="$(wc -c < "${APK_PATH}" | tr -d ' ')"
printf '==> Publishing %s (%s bytes) as %s\n' "${APK_PATH}" "${size}" "${LATEST_NAME}"

# Two steps on purpose: the APK and the remote script would otherwise both
# want ssh's stdin. Staged on the host first, then moved into the container's
# media volume.
REMOTE_TMP="/tmp/crimeatrip-apk-$$.apk"
scp "${scp_opts[@]}" "${APK_PATH}" \
  "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}:${REMOTE_TMP}"

# Written under a temporary name and moved into place: the previous build
# stays downloadable until the new one is complete, because a half-written
# APK installs as a corrupt package.
ssh "${ssh_opts[@]}" "${DEPLOY_SSH_USER}@${DEPLOY_SSH_HOST}" \
  "CONTAINER=$(printf '%q' "${DEPLOY_BACKEND_CONTAINER}") \
   LATEST=$(printf '%q' "${LATEST_NAME}") \
   VERSIONED=$(printf '%q' "${VERSIONED_NAME}") \
   EXPECTED=$(printf '%q' "${size}") \
   REMOTE_TMP=$(printf '%q' "${REMOTE_TMP}") \
   bash -s" <<'EOS'
set -Eeuo pipefail
MEDIA=/app/data/media/app
cleanup() { rm -f "${REMOTE_TMP}"; }
trap cleanup EXIT

actual="$(wc -c < "${REMOTE_TMP}" | tr -d ' \r')"
if [[ "${actual}" != "${EXPECTED}" ]]; then
  printf 'Error: staged %s bytes, expected %s — not publishing.\n' "${actual}" "${EXPECTED}" >&2
  exit 1
fi

# Streamed in as the container's own user, so nothing has to chown after.
docker exec -i "${CONTAINER}" sh -c "mkdir -p '${MEDIA}' && cat > '${MEDIA}/.incoming.apk'" < "${REMOTE_TMP}"
inside="$(docker exec "${CONTAINER}" sh -c "wc -c < '${MEDIA}/.incoming.apk'" | tr -d ' \r')"
if [[ "${inside}" != "${EXPECTED}" ]]; then
  docker exec "${CONTAINER}" sh -c "rm -f '${MEDIA}/.incoming.apk'"
  printf 'Error: landed %s bytes, expected %s — not publishing.\n' "${inside}" "${EXPECTED}" >&2
  exit 1
fi
docker exec "${CONTAINER}" sh -c \
  "cp '${MEDIA}/.incoming.apk' '${MEDIA}/${VERSIONED}' && mv '${MEDIA}/.incoming.apk' '${MEDIA}/${LATEST}'"
docker exec "${CONTAINER}" sh -c "ls -l '${MEDIA}'"
EOS

printf '\n==> Published.\n'
if [[ -n "${APK_PUBLIC_BASE_URL:-}" ]]; then
  printf '    %s/media/app/%s\n' "${APK_PUBLIC_BASE_URL%/}" "${LATEST_NAME}"
  printf '    %s/media/app/%s\n' "${APK_PUBLIC_BASE_URL%/}" "${VERSIONED_NAME}"
fi
