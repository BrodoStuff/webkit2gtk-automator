# AGENTS.md — webkit2gtk-automator

This file provides guidance for agentic coding agents working in this repository.

---

## Project Overview

This project is a Bash/Docker automation daemon that:
1. Polls the AUR RPC API for new `webkit2gtk` releases
2. Builds the package using `makepkg` inside an Arch Linux container
3. Publishes the resulting `.pkg.tar.zst` artifact to GitHub Releases
4. Generates and pushes an updated `webkit2gtk-bin` PKGBUILD to the AUR

The entire codebase is Bash scripts orchestrated via Docker Compose. There is no application framework, no package manager (npm/pip/cargo), and no test suite.

---

## Repository Structure

```
webkit2gtk-automator/
├── .env.example           # Template for required environment variables
├── .gitignore
├── Dockerfile             # Arch Linux image with build dependencies
├── docker-compose.yml     # Defines the "builder" service
├── README.md
└── scripts/
    ├── entrypoint.sh      # Container entrypoint; polling loop
    ├── check-update.sh    # AUR API poll; triggers build + publish if new version
    ├── build.sh           # Runs makepkg; collects .pkg.tar.zst artifacts
    └── publish.sh         # Uploads to GitHub Releases; pushes PKGBUILD to AUR
```

Runtime-generated (gitignored):
- `state/last_version` — tracks last published version
- `state/artifacts/` — holds built `.pkg.tar.zst` files
- `webkit2gtk/` — AUR source package clone
- `webkit2gtk-bin/` — AUR binary package clone

---

## Environment Setup

Copy `.env.example` to `.env` and fill in all required values before starting:

```bash
cp .env.example .env
# Edit .env with your GITHUB_TOKEN, AUR SSH key path, GPG key, etc.
```

All scripts validate required variables at startup using the pattern:
```bash
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
```
Missing variables cause an immediate exit with a descriptive error.

---

## Build / Run Commands

| Purpose | Command |
|---|---|
| Start the daemon (detached) | `docker compose up -d` |
| Start and rebuild the image | `docker compose up -d --build` |
| Watch live logs | `docker compose logs -f` |
| Stop the daemon | `docker compose down` |
| Force a rebuild on next poll | `rm state/last_version && docker compose restart` |

---

## Running a Single Script

There is no test runner. To manually invoke a single script inside the container:

```bash
# Run check-update.sh (polls AUR and triggers build+publish if needed)
docker compose run --rm builder bash -c "source /workspace/.env && /workspace/scripts/check-update.sh"

# Run build.sh directly
docker compose run --rm builder bash -c "source /workspace/.env && /workspace/scripts/build.sh"

# Run publish.sh directly
docker compose run --rm builder bash -c "source /workspace/.env && /workspace/scripts/publish.sh"
```

To test publish without recompiling, pre-place an artifact in `state/artifacts/`:
```bash
# build.sh detects existing artifact and skips makepkg
cp some-existing.pkg.tar.zst state/artifacts/
docker compose run --rm builder bash -c "source /workspace/.env && /workspace/scripts/publish.sh"
```

---

## No Test Suite

There are no unit tests, integration tests, or test commands. Manual invocation of
individual scripts (see above) is the primary validation mechanism.

---

## Code Style Guidelines

### Shebang and Strict Mode

Every script **must** begin with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```
- `set -e` — exit immediately on any non-zero return code
- `set -u` — treat unset variables as errors
- `set -o pipefail` — propagate errors through pipelines

### Variable Naming

| Scope | Convention | Example |
|---|---|---|
| All variables (env or local) | `UPPER_SNAKE_CASE` | `PKG_VERSION`, `BUILD_DIR` |
| Functions | `snake_case` | `log`, `die`, `check_deps` |
| Script files | `kebab-case.sh` | `check-update.sh`, `build.sh` |

### Quoting

Always double-quote variable expansions. Use `${VAR}` brace syntax:
```bash
# Correct
cp "${SRC_FILE}" "${DEST_DIR}/"
echo "Version: ${PKG_VERSION}"

# Wrong — never do this
cp $SRC_FILE $DEST_DIR/
```

### Sourcing Files

Use `source` (not the POSIX `.` shorthand):
```bash
# Correct
source /workspace/.env

# Avoid
. /workspace/.env
```

To auto-export all variables from a sourced file:
```bash
set -a
source /workspace/.env
set +a
```

### Logging

Every script defines a `log()` function with a consistent timestamp prefix:
```bash
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [script-name] $*"; }
```
Use `log` for all informational output. Use `log "ERROR: ..." >&2` (or `die`) for errors.

### Arrays

Use Bash arrays when collecting multiple items:
```bash
packages=()
packages+=("${pkg_file}")
```

---

## Error Handling Conventions

### Required Variable Checks

Use Bash parameter expansion to validate required env vars:
```bash
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
: "${AUR_SSH_KEY:?AUR_SSH_KEY is not set}"
```

### `die()` Helper

Define and use a `die()` function for fatal errors:
```bash
die() {
    log "ERROR: $*" >&2
    exit 1
}

# Usage
[[ -f "${pkg_file}" ]] || die "Expected artifact not found: ${pkg_file}"
```

### Explicit Guard Blocks

Prefer explicit `if/else` over bare command calls for critical steps:
```bash
if "${SCRIPT_DIR}/build.sh"; then
    log "Build succeeded"
else
    log "ERROR: Build failed, aborting"
    exit 1
fi
```

### Null/Empty API Response Checks

Always validate outputs from `curl | jq` pipelines:
```bash
aur_version=$(curl -s "${AUR_API_URL}" | jq -r '.results[0].Version')
if [[ -z "${aur_version}" || "${aur_version}" == "null" ]]; then
    log "ERROR: Failed to parse version from AUR response"
    exit 1
fi
```

### Graceful No-Op

For idempotent operations (e.g., git commit), allow the no-op case:
```bash
git commit -m "Update to ${FULL_VERSION}" || {
    log "Nothing to commit, already at ${FULL_VERSION}"
    exit 0
}
```

---

## External Tool Dependencies

These CLI tools are invoked directly by the scripts. They must be present in the container:

| Tool | Purpose |
|---|---|
| `curl` | HTTP requests to AUR RPC API |
| `jq` | JSON parsing of AUR API responses |
| `makepkg` | Arch Linux package build tool |
| `gh` | GitHub CLI — creating releases and uploading assets |
| `git` | Cloning/pulling AUR repos, committing, pushing |
| `gpg` | Verifying PGP signatures on source tarballs |
| `sha256sum` | Computing checksums for the artifact |
| `bsdtar` | Extracting the `.pkg.tar.zst` in the generated PKGBUILD |
| `sudo` | Dropping privileges from root to `builduser` for `makepkg` |
| `ssh` | AUR authentication via SSH key |

All of these are installed in the `Dockerfile`. If adding a new dependency, add it there.

---

## Dockerfile and docker-compose.yml

- The base image is Arch Linux. Keep it updated with `pacman -Syu` in the `Dockerfile`.
- The container runs as root but drops to a `builduser` account for `makepkg` (which
  refuses to run as root).
- Secrets (`.env`, SSH keys, GPG keys) are mounted at runtime via volume mounts defined
  in `docker-compose.yml`. Never bake secrets into the image.

---

## ShellCheck

ShellCheck is the recommended linter for Bash scripts. It is not formally enforced (no
`.shellcheckrc` or CI step), but inline directives are already used in the codebase
(e.g., `# shellcheck source=/dev/null`). When editing scripts, run ShellCheck locally:

```bash
shellcheck scripts/*.sh
```

Fix all warnings before committing. Use inline directives sparingly and only with a
comment explaining why the suppression is necessary.

---

## Adding a New Script

1. Create the file as `scripts/kebab-case-name.sh`
2. Start with `#!/usr/bin/env bash` and `set -euo pipefail`
3. Define a `log()` function matching the pattern above
4. Validate all required env vars with `: "${VAR:?...}"`
5. Define a `die()` helper for fatal errors
6. Make it executable: `chmod +x scripts/kebab-case-name.sh`
7. If it needs to run inside the container, invoke it via `docker compose run --rm builder`
