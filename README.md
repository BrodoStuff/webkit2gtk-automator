# webkit2gtk-automator

Automated builder and AUR publisher for [webkit2gtk](https://aur.archlinux.org/packages/webkit2gtk), running on GitHub Actions.

Every day a workflow checks the AUR for a new `webkit2gtk` version. When an update is detected, it triggers a build on a 64 cores runner, compiles the package from source inside an Arch Linux container, publishes the resulting binary as a GitHub Release, and updates the [webkit2gtk-bin](https://aur.archlinux.org/packages/webkit2gtk-bin) AUR package to point to the new artifact.

## How it works

```
check-version.yml (runs daily at midnight UTC)
    │
    ├── query AUR RPC API for webkit2gtk version
    ├── query latest GitHub Release tag
    ├── if unchanged -> stop
    └── if newer -> trigger build-release.yml with the new version
        │
        └── build-release.yml (ubuntu-latest-64-cores, archlinux container)
            │
            ├── build-package.sh
            │   ├── pacman -Syu, install base-devel, git, curl, jq, github-cli
            │   ├── clone webkit2gtk from AUR
            │   └── makepkg -s -> .pkg.tar.zst
            │
            ├── create-release.sh
            │   ├── gh release create vX.Y.Z
            │   └── upload .pkg.tar.zst as release asset
            │
            └── update-aur.sh
                ├── clone webkit2gtk-bin AUR repo via SSH
                ├── patch pkgver, source, sha256sums in PKGBUILD
                ├── makepkg --printsrcinfo -> .SRCINFO
                └── git push to AUR
```
