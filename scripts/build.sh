#!/usr/bin/env bash
# build.sh
# Runs INSIDE the Docker container as builduser.
# Builds webkit2gtk from the AUR PKGBUILD and copies the resulting
# .pkg.tar.zst packages to /workspace/state/artifacts/.

set -euo pipefail

WORKSPACE=/workspace
SRC_DIR="${WORKSPACE}/webkit2gtk"
ARTIFACTS_DIR="${WORKSPACE}/state/artifacts"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [build] $*"
}

# Sanity checks
if [[ ! -f "${SRC_DIR}/PKGBUILD" ]]; then
    log "ERROR: PKGBUILD not found at ${SRC_DIR}/PKGBUILD"
    exit 1
fi

mkdir -p "${ARTIFACTS_DIR}"

# Skip rebuild if artifacts for this version already exist
pkgver=$(bash -c "source ${SRC_DIR}/PKGBUILD; echo \${pkgver}")
pkgrel=$(bash -c "source ${SRC_DIR}/PKGBUILD; echo \${pkgrel}")
existing=$(find "${ARTIFACTS_DIR}" -maxdepth 1 \
    -name "webkit2gtk-${pkgver}-${pkgrel}-*.pkg.tar.zst" \
    ! -name 'webkit2gtk-docs-*' \
    -print | head -n1)

if [[ -n "${existing}" ]]; then
    log "Artifacts for ${pkgver}-${pkgrel} already exist, skipping build"
    log "Using cached: $(basename "${existing}")"
    exit 0
fi

# Clean any leftover build artifacts from a previous run
log "Cleaning previous build artifacts in ${SRC_DIR}"
# makepkg leaves behind src/, pkg/ and the .pkg.tar.zst files
cd "${SRC_DIR}"
rm -rf src/ pkg/
find . -maxdepth 1 -name '*.pkg.tar.zst' -delete
find . -maxdepth 1 -name '*.pkg.tar.zst.sig' -delete

# Build
# Use all available cores. MAKEFLAGS is respected by makepkg and passed
# through to cmake/ninja. NPROC can be overridden via the environment.
nproc="${NPROC:-$(nproc)}"
export MAKEFLAGS="-j${nproc}"
log "Building with ${nproc} cores"
log "Running makepkg in ${SRC_DIR}"
# --syncdeps  : install missing makedepends automatically
# --noconfirm : do not ask for confirmations
# --clean     : clean up src/ and pkg/ after a successful build
# --log       : write build log to makepkg-<pkgname>.log
makepkg \
    --syncdeps \
    --noconfirm \
    --log

# Collect artifacts
log "Collecting built packages"
packages=()
while IFS= read -r -d '' pkg; do
    packages+=("${pkg}")
done < <(find "${SRC_DIR}" -maxdepth 1 -name '*.pkg.tar.zst' -print0)

if [[ ${#packages[@]} -eq 0 ]]; then
    log "ERROR: No .pkg.tar.zst files found after build"
    exit 1
fi

for pkg in "${packages[@]}"; do
    log "Copying $(basename "${pkg}") to ${ARTIFACTS_DIR}/"
    cp "${pkg}" "${ARTIFACTS_DIR}/"
done

log "Build complete, artifacts:"
ls -lh "${ARTIFACTS_DIR}"/*.pkg.tar.zst
