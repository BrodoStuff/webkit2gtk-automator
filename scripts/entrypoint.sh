#!/usr/bin/env bash
# entrypoint.sh
# Container entry point. Runs as root, sets up the SSH key and git identity
# for builduser, then drops to builduser and starts the polling loop.
#
# The loop runs check-update.sh every POLL_INTERVAL_SECONDS (default: 3600).
# All output goes to stdout/stderr so 'docker compose logs -f' works naturally.

set -euo pipefail

POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-3600}"

# Set up AUR SSH key
SSH_DIR=/home/builduser/.ssh
KEY_SRC=/run/secrets/aur_id_rsa
KEY_DST="${SSH_DIR}/aur_id_rsa"

if [[ -f "${KEY_SRC}" ]]; then
    cp "${KEY_SRC}" "${KEY_DST}"
    chown builduser:builduser "${KEY_DST}"
    chmod 600 "${KEY_DST}"
    echo "[entrypoint] AUR SSH key installed"
else
    echo "[entrypoint] WARNING: AUR SSH key not found at ${KEY_SRC}, publishing to AUR will fail" >&2
fi

# Set git identity for builduser
sudo -u builduser git config --global user.name  "${AUR_MAINTAINER_NAME:-webkit2gtk-automator}"
sudo -u builduser git config --global user.email "${AUR_MAINTAINER_EMAIL:-noreply@localhost}"

# Import WebKitGTK PGP signing keys into builduser's keyring
# makepkg verifies the source tarball signature against these keys.
# Try the bundled local keys first (no network needed), then fall back to keyservers.
echo "[entrypoint] Importing WebKitGTK PGP signing keys"
if ls /workspace/webkit2gtk/keys/pgp/*.asc &>/dev/null; then
    sudo -u builduser gpg --import /workspace/webkit2gtk/keys/pgp/*.asc
    echo "[entrypoint] PGP keys imported from local bundle"
else
    sudo -u builduser gpg --keyserver keyserver.ubuntu.com --recv-keys \
        5AA3BC334FD7E3369E7C77B291C559DBE4C9123B \
        013A0127AC9C65B34FFA62526C1009B693975393 || \
    sudo -u builduser gpg --keyserver hkps://keys.openpgp.org --recv-keys \
        5AA3BC334FD7E3369E7C77B291C559DBE4C9123B \
        013A0127AC9C65B34FFA62526C1009B693975393
    echo "[entrypoint] PGP keys imported from keyserver"
fi

# Drop to builduser and start the polling loop
echo "[entrypoint] Starting polling loop, interval: ${POLL_INTERVAL_SECONDS}s"
exec sudo -u builduser bash -c '
    set -euo pipefail
    POLL_INTERVAL_SECONDS="'"${POLL_INTERVAL_SECONDS}"'"
    while true; do
        /workspace/scripts/check-update.sh
        echo "[entrypoint] Sleeping for ${POLL_INTERVAL_SECONDS}s"
        sleep "${POLL_INTERVAL_SECONDS}"
    done
'
