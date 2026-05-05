#!/usr/bin/env bash
set -euo pipefail

# Creates a Github release for the given version and uploads the built .pkg.tar.zst artifact
# Outputs asset download URL to GITHUB_OUTPUT

VERSION="${1:?Usage: create-release.sh <version> <pkg_path>}"
PKG_PATH="${2:?Usage: create-release.sh <version> <pkg_path>}"
REPO="${GITHUB_REPOSITORY}"

if [ ! -f "$PKG_PATH" ]; then
    echo "ERROR: Package file not found at $PKG_PATH" >&2
    exit 1
fi

echo "Creating Github release v${VERSION}..."
gh release create "v${VERSION}" \
    --repo "$REPO" \
    --title "v${VERSION}" \
    --notes "Automated build of webkit2gtk v${VERSION} from AUR" \
    "$PKG_PATH"

echo "Fetching asset URL..."
ASSET_URL=$(gh release view "v${VERSION}" \
    --repo "$REPO" \
    --json assets \
    --jq '.assets[] | select(.name | endswith(".pkg.tar.zst")) | .url'
)

if [ -z "$ASSET_URL" ]; then
    echo "ERROR: Could not retrieve asset URL after upload" >&2
    exit 1
fi

echo "Asset URL: $ASSET_URL"
echo "asset_url=$ASSET_URL" >> "$GITHUB_OUTPUT"