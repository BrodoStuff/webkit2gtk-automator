#!/usr/bin/env bash
# check-update.sh
# Polls the AUR RPC API for the latest webkit2gtk version.
# If a newer version is detected, runs build.sh then publish.sh directly.
# Called by entrypoint.sh on a loop — runs entirely inside the container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Paths
STATE_DIR="${ROOT_DIR}/state"
LAST_VERSION_FILE="${STATE_DIR}/last_version"
mkdir -p "${STATE_DIR}"

# Logging
# Output goes to stdout so docker compose logs picks it up automatically.
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [check-update] $*"
}

# Fetch latest AUR version
AUR_API_URL="https://aur.archlinux.org/rpc/v5/info/webkit2gtk"

log "Querying AUR for webkit2gtk"
response=$(curl -fsSL "${AUR_API_URL}")
aur_version=$(echo "${response}" | jq -r '.results[0].Version')

if [[ -z "${aur_version}" || "${aur_version}" == "null" ]]; then
    log "ERROR: Failed to parse version from AUR response: ${response}"
    exit 1
fi

log "AUR version: ${aur_version}"

# Compare with last built version
last_version=""
if [[ -f "${LAST_VERSION_FILE}" ]]; then
    last_version=$(cat "${LAST_VERSION_FILE}")
fi

log "Last built version: ${last_version:-<none>}"

if [[ "${aur_version}" == "${last_version}" ]]; then
    log "Already up to date, nothing to do"
    exit 0
fi

log "New version detected: ${aur_version} (was: ${last_version:-<none>}), starting build"

# Update the webkit2gtk AUR clone
WEBKIT2GTK_DIR="${ROOT_DIR}/webkit2gtk"
if [[ -d "${WEBKIT2GTK_DIR}/.git" ]]; then
    log "Pulling latest PKGBUILD from AUR"
    git -C "${WEBKIT2GTK_DIR}" pull --ff-only
else
    log "Cloning webkit2gtk from AUR"
    git clone https://aur.archlinux.org/webkit2gtk.git "${WEBKIT2GTK_DIR}"
fi

# Build
log "Running build"
if "${SCRIPT_DIR}/build.sh"; then
    log "Build succeeded"
else
    log "ERROR: Build failed, aborting"
    exit 1
fi

# Publish
log "Running publish"
if "${SCRIPT_DIR}/publish.sh"; then
    log "Publish succeeded"
else
    log "ERROR: Publish failed, exit code: $?"
    exit 1
fi

# Record new version
echo "${aur_version}" > "${LAST_VERSION_FILE}"
log "Updated last_version to ${aur_version}, done"
