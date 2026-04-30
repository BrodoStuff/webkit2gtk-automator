#!/usr/bin/env bash
# check-update.sh
# Queries the AUR RPC API for the latest webkit2gtk version and compares it
# against the last published version on GitHub Releases.
#
# Outputs:
#   aur_version=<string>   — latest AUR version string
#   should_build=true|false — whether a new build is needed
#
# When run inside a GitHub Actions step, GITHUB_OUTPUT is set and the outputs
# are written there automatically. When run locally, they are printed to stdout.
#
# Required env vars (only when comparing against GitHub Releases):
#   GITHUB_TOKEN  — a token with 'contents: read' on GITHUB_REPO
#   GITHUB_REPO   — owner/repo, e.g. Brodino96/webkit2gtk-automator

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [check-update] $*"
}

set_output() {
    local key="$1"
    local value="$2"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "${key}=${value}" >> "${GITHUB_OUTPUT}"
    else
        log "OUTPUT: ${key}=${value}"
    fi
}

# ---------------------------------------------------------------------------
# 1. Fetch latest AUR version
# ---------------------------------------------------------------------------
AUR_API_URL="https://aur.archlinux.org/rpc/v5/info/webkit2gtk"

log "Querying AUR for webkit2gtk"
response=$(curl -fsSL "${AUR_API_URL}")
aur_version=$(echo "${response}" | jq -r '.results[0].Version')

if [[ -z "${aur_version}" || "${aur_version}" == "null" ]]; then
    log "ERROR: Failed to parse version from AUR response: ${response}"
    exit 1
fi

log "AUR version: ${aur_version}"
set_output "aur_version" "${aur_version}"

# ---------------------------------------------------------------------------
# 2. Fetch last published version from GitHub Releases
# ---------------------------------------------------------------------------
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
: "${GITHUB_REPO:?GITHUB_REPO is not set}"

log "Fetching latest GitHub Release tag from ${GITHUB_REPO}"
tag=$(gh release list \
    --repo "${GITHUB_REPO}" \
    --limit 1 \
    --json tagName \
    --jq '.[0].tagName // ""' 2>/dev/null || echo "")

last_version="${tag#v}"
log "Last published version: ${last_version:-<none>}"

# ---------------------------------------------------------------------------
# 3. Compare
# ---------------------------------------------------------------------------
if [[ "${aur_version}" == "${last_version}" ]]; then
    log "Already up to date (${aur_version}), nothing to do"
    set_output "should_build" "false"
else
    log "New version detected: ${aur_version} (was: ${last_version:-<none>})"
    set_output "should_build" "true"
fi
