# webkit2gtk-automator

Automated builder and AUR publisher for [webkit2gtk](https://aur.archlinux.org/packages/webkit2gtk), running on a self-hosted server.

Every hour the container polls the AUR for a new webkit2gtk version. When an update is detected, it builds the package from source inside an isolated Arch Linux container and publishes the resulting binary as a [webkit2gtk-bin](https://aur.archlinux.org/packages/webkit2gtk-bin) AUR package, with the prebuilt artifact hosted on [GitHub Releases](https://github.com/Brodino96/webkit2gtk-automator/releases).

## How it works

```
docker compose up -d
    │
    └── container starts
        │
        every hour:
        ├── query AUR RPC API for webkit2gtk version
        ├── if unchanged → sleep
        └── if newer →
            git pull webkit2gtk PKGBUILD
            makepkg (all available cores)
            upload .pkg.tar.zst to GitHub Releases
            update webkit2gtk-bin PKGBUILD + .SRCINFO
            git push to AUR
```

## Setup

**1) Clone the repository**
```bash
git clone https://github.com/Brodino96/webkit2gtk-automator.git
cd webkit2gtk-automator
```

**2) Configure the environment**
```bash
cp .env.example .env
```

Edit `.env` and fill in:

| Variable                  | Description                                                                       |
|---------------------------|-----------------------------------------------------------------------------------|
| `GITHUB_TOKEN`            | Personal access token with **Contents: read/write** on this repo                  |
| `GITHUB_REPO`             | `Brodino96/webkit2gtk-automator`                                                  |
| `AUR_SSH_KEY_PATH`        | Absolute path to the SSH private key registered on your AUR account               |
| `AUR_PACKAGE_NAME`        | `webkit2gtk-bin`                                                                  |
| `AUR_MAINTAINER_NAME`     | Your name (written into the published PKGBUILD)                                   |
| `AUR_MAINTAINER_EMAIL`    | Your email (written into the published PKGBUILD)                                  |
| `POLL_INTERVAL_SECONDS`   | How often to check for updates, in seconds (default: `3600`)                      |
| `NPROC`                   | CPU cores for compilation, also caps the container's CPU quota (default: `4`)     |

**3) Start the daemon**
```bash
docker compose up -d
```

**4) Optional - Watch the logs**
```bash
docker compose logs -f
```

## Useful commands

```bash
# Stop the daemon
docker compose down

# Rebuild the image after a Dockerfile change
docker compose up -d --build

# Force a rebuild on next poll (reset the tracked version)
rm state/last_version
docker compose restart
```

## Notes

- The build takes 1–3 hours depending on server hardware
- If an artifact for the current version already exists in `state/artifacts/`, the build step is skipped and the existing file is published directly (useful for testing)
- All logs go to stdout and are accessible via `docker compose logs`
- The `state/` directory is created at runtime and is not tracked by git
