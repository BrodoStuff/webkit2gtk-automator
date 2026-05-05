#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest webkit2gtk version from the AUR and compares with latest Github release
# Outputs the AUR version to GITHUB_OUTPUT if a build should be triggered, otherwiste ouputs an empty string

REPO="${GITHUB_REPOSITORY}"

echo "Fetching AUR version..."
AUR_VERSION=$(curl -s "https://aur.archlinux.org/rpc/v5/info/webkit2gtk" \
    | jq -r ".results[0].Version" \
)

if [ -z "$AUR_VERSION" ] || [ "$AUR_VERSION" = "null" ]; then
    echo "ERROR: Could not fetch AUR version" >&2
    exit 1
fi

echo "AUR version: $AUR_VERSION"

echo "Fetching latest Github release..."
TAG=$(gh release list \
    --repo "$REPO" \
    --limit 1 \
    --json tagName \
    --jq '.[0].tagName // ""'
)
RELEASE_VERSION="${TAG#v}"

echo "Release version: ${RELEASE_VERSION:-"(none)"}"

if [ -z "$RELEASE_VERSION" ] || [ "$AUR_VERSION" != "$RELEASE_VERSION" ]; then
    echo "Version mismatch or no release found, build required"
    echo "trigger_version=$AUR_VERSION" >> "$GITHUB_OUTPUT"
else
    echo "Version match, no build required"
    echo "trigger_version=" >> "$GITHUB_OUTPUT"
fi