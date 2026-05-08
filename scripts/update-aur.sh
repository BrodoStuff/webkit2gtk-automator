#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: update-aur.sh <version> <pkg_path> <asset_url>}"
PKG_PATH="${2:?Usage: update-aur.sh <version> <pkg_path> <asset_url>}"
ASSET_URL="${3:?Usage: update-aur.sh <version> <pkg_path> <asset_url>}"
AUR_DIR="/build/webkit2gtk-bin"

# VERSION is in the format pkgver-pkgrel (e.g. 2.46.5-2)
PKGVER="${VERSION%-*}"
PKGREL="${VERSION##*-}"

echo "Configuring AUR SSH key..."
mkdir -p /root/.ssh
echo "${AUR_SSH_KEY:?AUR_SSH_KEY environment variable is not set}" > /root/.ssh/aur
chmod 600 /root/.ssh/aur

cat >> /root/.ssh/config <<EOF
    IdentityFile /root/.ssh/aur
    User aur
    StrictHostKeyChecking accept-new
EOF

ssh-keyscan aur.archlinux.org >> /root/.ssh/known_hosts

echo "Cloning webkit2gtk-bin AUR repo"
git clone ssh://aur@aur.archlinux.org/webkit2gtk-bin.git "$AUR_DIR"

echo "Hashing artifact..."
SHA256=$(sha256sum "$PKG_PATH" | awk '{print $1}' )
echo "sha256: $SHA256"

echo "Updating PKBUILD..."
cd "$AUR_DIR"

sed -i "s|^pkgver=.*|pkgver=${PKGVER}|" PKGBUILD
sed -i "s|^pkgrel=.*|pkgrel=${PKGREL}|" PKGBUILD
sed -i "s|^source=.*|source=(\"${ASSET_URL}\")|" PKGBUILD
sed -i "s|^sha256sums=.*|sha256sums=(\"${SHA256}\")|" PKGBUILD

echo "Regenerating .SRCINFO..."
chown -R builder:builder "$AUR_DIR"
su builder -c "cd $AUR_DIR && makepkg --printsrcinfo > .SRCINFO"

echo "Committing and pushing to AUR..."
git config user.name "Brodino"
git config user.email "brodino96@gmail.com"
git add PKGBUILD .SRCINFO
git commit -m "Update to v${VERSION}"
git push