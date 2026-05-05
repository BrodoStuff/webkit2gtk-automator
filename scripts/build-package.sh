#!/usr/bin/env bash
set -euo pipefail

# Setups Arch building environment, clones webkit2gtk from the AUR and builds it
# Outputs the path and filename of the built .pkg.tar.zst to GITHUB_OUTPUT

BUILD_DIR="/build/webkit2gtk"

echo "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinux

echo "Updating system..."
pacman -Syu --noconfirm

echo "Installing build dependencies..."
pacman -S --noconfirm base-devel git curl jq github-cli

echo "Creating builduser..."
if ! id builder &>/dev/null; then
    useradd -m builder
fi
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "Cloning webkit2gtk AUR repo..."
git clone https://aur.archlinux.org/webkit2gtk.git "$BUILD_DIR"
chown -R builder:builder "$BUILD_DIR"

echo "Building package..."
su builder -c "cd $BUILD_DIR && makepkg -s --noconfirm"

echo "Locating build package..."
PKG_PATH=$(find "$BUILD_DIR" -maxdepth 1 -name "*.pkg.tar.zst" | head -n 1)

if [ -z "$PKG_PATH" ]; then
    echo "ERROR: No .pkg.tar.zst found after build" >&2
    exit 1
fi

echo "Build package: $PKG_PATH"
echo "pkg_path=$PKG_PATH" >> "$GITHUB_OUTPUT"
echo "pkg_name=$(basename "$PKG_PATH")" >> "$GITHUB_OUTPUT"