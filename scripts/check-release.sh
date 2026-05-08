#!/usr/bin/env bash
set -euo pipefail

# Checks if a release is already present on Github
# Outputs the asset path and url in case already exists

VERSION="${1:?Usage: check-release.sh <version>}"
REPO="${GITHUB_REPO_NAME:-$GITHUB_REPOSITORY}"
DOWNLOAD_DIR="/build/webkit2gtk-prebuilt"

echo "Checking for existing GitHub release v${VERSION}..."

ASSET_URL=$(gh release view "v${VERSION}" \
    --repo "$REPO" \
    --json assets \
    --jq '.assets[] | select(.name | endswith(".pkg.tar.zst")) | .url' \
    2>/dev/null || true
)

if [ -z "$ASSET_URL" ]; then
    echo "No existing release found, build required"
    echo "release_exists=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

PKG_NAME=$(gh release view "v${VERSION}" \
    --repo "$REPO" \
    --json assets \
    --jq '.assets[] | select(.name | endswith(".pkg.tar.zst")) | .name'
)

echo "Existing release found: $ASSET_URL"
echo "Downloading artifact..."
mkdir -p "$DOWNLOAD_DIR"
gh release download "v${VERSION}" \
    --repo "$REPO" \
    --pattern "*.pkg.tar.zst" \
    --dir "$DOWNLOAD_DIR"

PKG_PATH="$DOWNLOAD_DIR/$PKG_NAME"

if [ ! -f "$PKG_PATH" ]; then
    echo "ERROR: Downloaded file not found at $PKG_PATH" >&2
    exit 1
fi

echo "Artifact downloaded to $PKG_PATH"
echo "release_exists=true" >> "$GITHUB_OUTPUT"
echo "asset_url=$ASSET_URL" >> "$GITHUB_OUTPUT"
echo "pkg_path=$PKG_PATH" >> "$GITHUB_OUTPUT"
