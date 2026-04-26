#!/usr/bin/env bash
# publish.sh
# Runs INSIDE the Docker container as builduser.
#
# Steps:
#   1. Find the built webkit2gtk .pkg.tar.zst in state/artifacts/
#   2. Upload it to a GitHub Release (creates the release if needed)
#   3. Update webkit2gtk-bin/PKGBUILD with the new version, URL and sha256sum
#   4. Regenerate webkit2gtk-bin/.SRCINFO
#   5. Commit and push webkit2gtk-bin/ to the AUR

set -euo pipefail

WORKSPACE=/workspace
ARTIFACTS_DIR="${WORKSPACE}/state/artifacts"
BIN_PKG_DIR="${WORKSPACE}/webkit2gtk-bin"
SRC_PKGBUILD="${WORKSPACE}/webkit2gtk/PKGBUILD"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [publish] $*"
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

# Validate required env vars
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
: "${GITHUB_REPO:?GITHUB_REPO is not set}"
: "${AUR_PACKAGE_NAME:?AUR_PACKAGE_NAME is not set}"
: "${AUR_MAINTAINER_NAME:?AUR_MAINTAINER_NAME is not set}"
: "${AUR_MAINTAINER_EMAIL:?AUR_MAINTAINER_EMAIL is not set}"

# Authenticate gh CLI
echo "${GITHUB_TOKEN}" | gh auth login --with-token

# Find the main webkit2gtk package (not -docs)
log "Looking for built package in ${ARTIFACTS_DIR}"
# We want webkit2gtk-<ver>-<rel>-x86_64.pkg.tar.zst, NOT webkit2gtk-docs-*
pkg_file=$(find "${ARTIFACTS_DIR}" -maxdepth 1 \
    -name 'webkit2gtk-*.pkg.tar.zst' \
    ! -name 'webkit2gtk-docs-*' \
    -print | sort -V | tail -n1)

[[ -n "${pkg_file}" ]] || die "No webkit2gtk .pkg.tar.zst found in ${ARTIFACTS_DIR}"
log "Found package: ${pkg_file}"
# Derive version from the built PKGBUILD
pkgver=$(bash -c "source ${SRC_PKGBUILD}; echo \${pkgver}")
pkgrel=$(bash -c "source ${SRC_PKGBUILD}; echo \${pkgrel}")
full_version="${pkgver}-${pkgrel}"
log "Package version: ${full_version}"
# Compute sha256sum of the artifact
sha256=$(sha256sum "${pkg_file}" | awk '{print $1}')
log "sha256sum: ${sha256}"
pkg_filename=$(basename "${pkg_file}")

# Upload to GitHub Releases
release_tag="v${full_version}"
release_title="webkit2gtk ${full_version}"

log "Creating/updating GitHub release ${release_tag}"

# Create the release if it doesn't exist; ignore error if it already does
gh release create "${release_tag}" \
    --repo "${GITHUB_REPO}" \
    --title "${release_title}" \
    --notes "Automated build of webkit2gtk ${full_version}" \
    2>/dev/null || log "Release ${release_tag} already exists, proceeding to upload asset"

# Upload the package (--clobber overwrites an existing asset with the same name)
log "Uploading ${pkg_filename} to release ${release_tag}"
gh release upload "${release_tag}" \
    --repo "${GITHUB_REPO}" \
    --clobber \
    "${pkg_file}"

# Build the public download URL
download_url="https://github.com/${GITHUB_REPO}/releases/download/${release_tag}/${pkg_filename}"
log "Download URL: ${download_url}"
# Ensure webkit2gtk-bin AUR clone exists
AUR_REMOTE="ssh://aur@aur.archlinux.org/${AUR_PACKAGE_NAME}.git"

if [[ ! -d "${BIN_PKG_DIR}/.git" ]]; then
    log "Cloning ${AUR_PACKAGE_NAME} from AUR"
    git clone "${AUR_REMOTE}" "${BIN_PKG_DIR}"
else
    log "Pulling latest ${AUR_PACKAGE_NAME} from AUR"
    git -C "${BIN_PKG_DIR}" pull --ff-only
fi

# Generate PKGBUILD
log "Generating PKGBUILD for ${AUR_PACKAGE_NAME}"

# Read the full depends array from the source PKGBUILD to keep them in sync
depends_block=$(bash -c "
    source ${SRC_PKGBUILD}
    for d in \"\${depends[@]}\"; do printf '  %s\n' \"\$d\"; done
")
provides_block=$(bash -c "
    source ${SRC_PKGBUILD}
    # package_webkit2gtk() sets provides; source the function then call it in a subshell
    # Simpler: hardcode from .SRCINFO since provides is stable
    echo '  libjavascriptcoregtk-4.0.so'
    echo '  libwebkit2gtk-4.0.so'
    echo '  webkit2gtk'
")

cat > "${BIN_PKG_DIR}/PKGBUILD" <<PKGBUILD
# Maintainer: ${AUR_MAINTAINER_NAME} <${AUR_MAINTAINER_EMAIL}>
# Automated binary repackaging of webkit2gtk built from AUR sources.
# Source: https://github.com/${GITHUB_REPO}

pkgname=${AUR_PACKAGE_NAME}
pkgver=${pkgver}
pkgrel=${pkgrel}
pkgdesc="Web content engine for GTK (prebuilt binary)"
url="https://webkitgtk.org"
arch=(x86_64)
license=(
  'AFL-2.0 OR GPL-2.0-or-later'
  Apache-2.0
  'Apache-2.0 WITH LLVM-exception'
  BSD-2-Clause
  BSD-2-Clause-Views
  BSD-3-Clause
  BSD-Source-Code
  BSL-1.0
  bzip2-1.0.6
  GPL-2.0-only
  'GPL-3.0-only WITH Autoconf-exception-3.0'
  'GPL-3.0-or-later WITH Bison-exception-2.2'
  ICU
  ISC
  LGPL-2.1-only
  LGPL-2.1-or-later
  MIT
  MPL-1.1
  MPL-2.0
  NCSA
  'NCSA OR MIT'
  OFL-1.1
  SunPro
  Unicode-TOU
)
depends=(
  at-spi2-core
  atk
  bubblewrap
  cairo
  enchant
  expat
  fontconfig
  freetype2
  gdk-pixbuf2
  glib2
  glibc
  gst-plugins-bad-libs
  gst-plugins-base-libs
  gstreamer
  gtk3
  harfbuzz
  harfbuzz-icu
  hyphen
  icu
  lcms2
  libatomic
  libavif
  libdrm
  libegl
  libepoxy
  libgcc
  libgcrypt
  libgl
  libgles
  libjpeg-turbo
  libjxl
  libmanette
  libpng
  libseccomp
  libsecret
  libsoup
  libstdc++
  libsystemd
  libtasn1
  libwebp
  libx11
  libxml2
  libxslt
  mesa
  openjpeg2
  pango
  sqlite
  ttf-font
  wayland
  woff2
  xdg-dbus-proxy
  zlib
)
provides=(
  libjavascriptcoregtk-4.0.so
  libwebkit2gtk-4.0.so
  webkit2gtk
)
conflicts=(webkit2gtk)
source=("${pkg_filename}::${download_url}")
sha256sums=('${sha256}')

package() {
  # The .pkg.tar.zst is a pre-built Arch package.
  # bsdtar extracts it; we relocate its contents into \$pkgdir.
  cd "\${srcdir}"
  bsdtar -xf "${pkg_filename}" -C "\${pkgdir}"
  # Remove the embedded .PKGINFO and .MTREE metadata files that
  # bsdtar includes – they are not part of the installed file tree.
  rm -f "\${pkgdir}"/.PKGINFO "\${pkgdir}"/.MTREE "\${pkgdir}"/.BUILDINFO
}
PKGBUILD

log "PKGBUILD generated"

# Generate .SRCINFO
log "Generating .SRCINFO"
cd "${BIN_PKG_DIR}"
makepkg --printsrcinfo > .SRCINFO
log ".SRCINFO generated"

# Commit and push to AUR
log "Committing changes to AUR"
git -C "${BIN_PKG_DIR}" add PKGBUILD .SRCINFO
git -C "${BIN_PKG_DIR}" commit -m "Update to ${full_version}" || {
    log "Nothing to commit, package already at ${full_version}"
    exit 0
}

log "Pushing to AUR remote (${AUR_REMOTE})"
git -C "${BIN_PKG_DIR}" push origin master

log "Successfully published ${AUR_PACKAGE_NAME} ${full_version} to AUR"
