# Phase 3: CLI Tools and Docker - Research

**Researched:** 2026-02-22
**Domain:** GitHub Releases binary installation, Docker Engine apt provisioning, Bash installer patterns
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- `lib/versions.sh` is the canonical version store — covers ALL pinned tools across all phases (not just Phase 3); gitleaks moves here too
- After each tool install, verify the installed binary's version matches the pinned version in versions.sh
- Idempotency: skip install if binary exists AND version matches; reinstall if version differs or binary is missing
- All seven CLI tools installed from GitHub Releases (direct binary download) — no apt dependency
- Binaries land in `/usr/local/bin` (system-wide)
- nvim installed from tarball (nvim-linux-{arch}.tar.gz) — AppImage is possible but tarball preferred on headless servers (no FUSE dependency)
- Docker install method: Claude's discretion (pick what's most idempotent and secure)
- Two installer files: `scripts/install-tools.sh` (seven CLI tools) and `scripts/install-docker.sh` (Docker Engine + Compose + lazydocker)
- One function per tool: `install_ripgrep()`, `install_fd()`, `install_fzf()`, `install_eza()`, `install_bat()`, `install_delta()`, `install_nvim()`, `install_lazydocker()`
- Wired into bootstrap.sh the same way as install-shell.sh (source + function call)
- Failure handling strategy: Claude's discretion
- Docker group: add user, log re-login message, continue — do NOT run docker run hello-world inside bootstrap
- In-bootstrap Docker check: `systemctl is-active docker`
- `scripts/verify.sh`: operator runs after re-login, reports pass/fail per tool

### Claude's Discretion

- Docker install method (official apt repo vs convenience script — pick what's most idempotent and secure)
- Failure handling strategy for individual tool install failures
- Exact AppImage mount/symlink approach for nvim (research recommends tarball over AppImage — see Architecture Patterns)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | ripgrep installed and accessible as `rg` | GitHub Releases: `ripgrep-{ver}-{arch}-unknown-linux-{libc}.tar.gz`, binary at `ripgrep-{ver}-{arch}-unknown-linux-{libc}/rg` |
| TOOL-02 | fd installed and accessible as `fd` | GitHub Releases: `fd-v{ver}-{arch}-unknown-linux-{libc}.tar.gz`, binary at `fd-v{ver}-{arch}-unknown-linux-{libc}/fd` |
| TOOL-03 | fzf installed and accessible as `fzf` | GitHub Releases: `fzf-{ver}-linux_{mapped_arch}.tar.gz`, flat archive (binary at root, no subdirectory) |
| TOOL-04 | eza installed and accessible as `eza` | GitHub Releases: `eza_{arch}-unknown-linux-gnu.tar.gz`, flat archive (binary at `./eza`) |
| TOOL-05 | bat installed and accessible as `bat` | GitHub Releases: `bat-v{ver}-{arch}-unknown-linux-{libc}.tar.gz`, binary at `bat-v{ver}-{arch}-unknown-linux-{libc}/bat` |
| TOOL-06 | delta installed and accessible as `delta` | GitHub Releases: `delta-{ver}-{arch}-unknown-linux-gnu.tar.gz`, binary at `delta-{ver}-{arch}-unknown-linux-gnu/delta` |
| TOOL-07 | neovim installed and accessible as `nvim` | GitHub Releases: `nvim-linux-{arch}.tar.gz`, binary at `nvim-linux-{arch}/bin/nvim` (tarball, not AppImage) |
| DOCK-01 | Docker Engine installed via official install script (handles x86_64 and ARM64) | Official apt repository method: handles both Ubuntu and Debian/RPi OS 64-bit; idempotent; more appropriate than convenience script |
| DOCK-02 | Docker Compose plugin installed and accessible as `docker compose` | Included in `docker-compose-plugin` package; installed alongside docker-ce |
| DOCK-03 | Bootstrap user added to docker group (docker commands run without sudo) | `usermod -aG docker $SUDO_USER`; group active after re-login; in-bootstrap check: `systemctl is-active docker` |
| DOCK-04 | lazydocker installed for terminal-based container management | GitHub Releases: `lazydocker_{ver}_Linux_{mapped_arch}.tar.gz`, flat archive (binary at root) |
</phase_requirements>

---

## Summary

Phase 3 installs seven CLI tools (ripgrep, fd, fzf, eza, bat, delta, neovim) from GitHub Releases and Docker Engine with Compose plugin plus lazydocker. All tools follow a verified-exact pattern: download tarball for the correct architecture, extract the binary, place at `/usr/local/bin/{name}`, and verify the installed version matches the pinned version in `lib/versions.sh`.

The primary complexity in this phase is architecture mapping. Each tool uses a different naming convention for architectures (some use `x86_64`/`aarch64`, others use `amd64`/`arm64`), and tarball structures vary between tools (some are flat archives, some have a single subdirectory wrapping the binary). All this must be resolved at install time using the `$ARCH` variable already exported by bootstrap.sh.

Docker requires a different installation path than the CLI tools: it uses the official apt repository method (not the get.docker.com convenience script) because the convenience script has a 20-second interactive delay on re-run and is explicitly documented as unsuitable for upgrade scenarios. The apt method is fully idempotent via standard package management. A critical platform difference exists: Ubuntu uses `download.docker.com/linux/ubuntu` while Raspberry Pi OS 64-bit (Bookworm, `ID=debian`) must use `download.docker.com/linux/debian` — the raspbian repo only has `binary-armhf/` and lacks `binary-arm64/`.

**Primary recommendation:** Use the official Docker apt repository method with dynamic OS detection (`source /etc/os-release` + `$ID`). Guard with `command -v docker` for idempotency. Install `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` in one apt command. Create `lib/versions.sh` as the canonical version store for all tools, source it from both install-tools.sh and install-docker.sh.

---

## Standard Stack

### Core (verified from live GitHub Releases API, 2026-02-22)

| Tool | Pinned Version | Binary Name | GitHub Repo |
|------|---------------|-------------|-------------|
| ripgrep | 15.1.0 | `rg` | BurntSushi/ripgrep |
| fd | 10.3.0 | `fd` | sharkdp/fd |
| fzf | 0.68.0 | `fzf` | junegunn/fzf |
| eza | 0.23.4 | `eza` | eza-community/eza |
| bat | 0.26.1 | `bat` | sharkdp/bat |
| delta | 0.18.2 | `delta` | dandavison/delta |
| neovim | 0.11.6 | `nvim` | neovim/neovim |
| lazydocker | 0.24.4 | `lazydocker` | jesseduffield/lazydocker |

### Supporting

| Package | Purpose | When to Use |
|---------|---------|-------------|
| `docker-ce` | Docker Engine | Always |
| `docker-ce-cli` | Docker CLI | Always |
| `containerd.io` | Container runtime | Always |
| `docker-buildx-plugin` | BuildKit integration | Always (bundled) |
| `docker-compose-plugin` | `docker compose` subcommand | Always (DOCK-02) |

---

## Architecture Patterns

### Recommended File Structure

```
lib/
├── log.sh           # existing
├── os.sh            # existing
├── pkg.sh           # existing
└── versions.sh      # NEW: canonical version store for all phases

scripts/
├── install-gitleaks.sh   # existing (update to source versions.sh)
├── install-shell.sh      # existing
├── install-tools.sh      # NEW: seven CLI tool installers
├── install-docker.sh     # NEW: Docker Engine + lazydocker
└── verify.sh             # NEW: operator runs post-relogin
```

### Pattern 1: Generic Binary Installer (used by all seven CLI tools)

The gitleaks installer in `scripts/install-gitleaks.sh` establishes the canonical pattern. All seven CLI tools follow it exactly:

```bash
install_ripgrep() {
  local version="${RIPGREP_VERSION}"
  local install_path="/usr/local/bin/rg"

  log_step "Checking ripgrep ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "ripgrep ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("ripgrep ${version}")
      return 0
    fi
    log_info "ripgrep version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install ripgrep ${version} (${ARCH})"
    return 0
  fi

  # Architecture mapping: ripgrep uses x86_64 / aarch64 (matches $ARCH from os.sh)
  local arch_map
  case "$ARCH" in
    x86_64) arch_map="x86_64" ;;
    arm64)  arch_map="aarch64" ;;
  esac

  local url="https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-${arch_map}-unknown-linux-gnu.tar.gz"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/ripgrep-${version}-${arch_map}-unknown-linux-gnu/rg" "$install_path"

  log_success "ripgrep ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("ripgrep ${version}")
}
```

### Pattern 2: versions.sh — Canonical Version Store

Sourced by install-tools.sh, install-docker.sh, and install-gitleaks.sh. All version variables use consistent naming.

```bash
# lib/versions.sh
#!/usr/bin/env bash
if [[ -n "${_LIB_VERSIONS_LOADED:-}" ]]; then return 0; fi
_LIB_VERSIONS_LOADED=1

# Phase 1 tools
GITLEAKS_VERSION="8.30.0"

# Phase 3: CLI tools
RIPGREP_VERSION="15.1.0"
FD_VERSION="10.3.0"
FZF_VERSION="0.68.0"
EZA_VERSION="0.23.4"
BAT_VERSION="0.26.1"
DELTA_VERSION="0.18.2"
NVIM_VERSION="0.11.6"

# Phase 3: Docker tools
LAZYDOCKER_VERSION="0.24.4"
# Docker Engine version managed by apt (always installs latest stable)
```

### Pattern 3: Docker Installation via Official apt Repository

**Recommended over convenience script** (see Pitfall 2 for reasons).

```bash
install_docker_engine() {
  log_step "Checking Docker Engine..."

  # Idempotency: skip if docker already installed and daemon is running
  if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
    log_info "Docker already installed and running — skipping"
    _SUMMARY_SKIPPED+=("Docker Engine")
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install Docker Engine via official apt repository"
    return 0
  fi

  log_step "Installing Docker Engine via official apt repository..."

  # Detect distro: Ubuntu uses /linux/ubuntu, Raspberry Pi OS 64-bit uses /linux/debian
  local os_id
  os_id="$(. /etc/os-release && echo "$ID")"
  local docker_repo_distro
  case "$os_id" in
    ubuntu)   docker_repo_distro="ubuntu" ;;
    debian)   docker_repo_distro="debian" ;;
    raspbian) docker_repo_distro="debian" ;;  # RPi OS 64-bit Bookworm reports ID=debian, but guard for older
    *)        docker_repo_distro="debian" ;;   # default to debian for other Debian derivatives
  esac

  local version_codename
  version_codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"

  # Install prerequisites
  apt-get update -qq
  apt-get install -y ca-certificates curl

  # Add Docker GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl --fail --silent --show-error --location \
    "https://download.docker.com/linux/${docker_repo_distro}/gpg" \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker apt repository (idempotent: overwrite existing file)
  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${docker_repo_distro} ${version_codename} stable
EOF

  apt-get update -qq

  # Install Docker Engine + Compose plugin in one command
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  log_success "Docker Engine installed"
  echo "file:/usr/bin/docker" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("Docker Engine")
}
```

### Pattern 4: Docker Group and Re-login Warning

```bash
add_user_to_docker_group() {
  log_step "Adding ${SUDO_USER:-root} to docker group..."

  local target_user="${SUDO_USER:-root}"

  # Ensure docker group exists (created by docker-ce install, but guard anyway)
  if ! getent group docker &>/dev/null; then
    groupadd docker
    log_info "Created docker group"
  fi

  # Idempotency: skip if already a member
  if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
    log_info "${target_user} is already in the docker group — skipping"
    _SUMMARY_SKIPPED+=("docker group membership")
    return 0
  fi

  usermod -aG docker "$target_user"
  log_success "${target_user} added to docker group"
  log_warn "IMPORTANT: Docker group membership takes effect after re-login."
  log_warn "Run 'scripts/verify.sh' after opening a new SSH session."
  _SUMMARY_WARNINGS+=("docker group: re-login required before running docker commands")
}
```

### Pattern 5: In-Bootstrap Docker Verification (no hello-world)

```bash
verify_docker_running() {
  log_step "Verifying Docker daemon is running..."
  if systemctl is-active --quiet docker; then
    log_success "Docker daemon is active"
    _SUMMARY_INSTALLED+=("Docker daemon (running)")
  else
    log_warn "Docker daemon is not active — attempting to start..."
    systemctl enable --now docker || log_warn "Could not start Docker daemon"
  fi
}
```

### Pattern 6: verify.sh — Operator Runs After Re-login

```bash
#!/usr/bin/env bash
# scripts/verify.sh — Run after re-login to confirm Phase 3 is complete
# Usage: bash ~/.dotfiles/scripts/verify.sh

PASS=0; FAIL=0

check_binary() {
  local name="$1" cmd="$2" expected_ver="$3"
  if ! command -v "$name" &>/dev/null; then
    echo "FAIL: $name not found in PATH"
    FAIL=$((FAIL+1)); return
  fi
  local ver
  ver="$($cmd 2>/dev/null | head -1)"
  if [[ "$ver" == *"$expected_ver"* ]]; then
    echo "PASS: $name $expected_ver"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name version mismatch (got: $ver, want: $expected_ver)"
    FAIL=$((FAIL+1))
  fi
}

# CLI tools
check_binary rg         "rg --version"         "15.1.0"
check_binary fd         "fd --version"         "10.3.0"
check_binary fzf        "fzf --version"        "0.68.0"
check_binary eza        "eza --version"        "0.23.4"
check_binary bat        "bat --version"        "0.26.1"
check_binary delta      "delta --version"      "0.18.2"
check_binary nvim       "nvim --version"       "0.11.6"

# Docker (requires re-login for group membership to be active)
if docker run --rm hello-world &>/dev/null; then
  echo "PASS: docker run hello-world (no sudo)"
  PASS=$((PASS+1))
else
  echo "FAIL: docker run hello-world failed (did you re-login?)"
  FAIL=$((FAIL+1))
fi

if docker compose version &>/dev/null; then
  echo "PASS: docker compose version"
  PASS=$((PASS+1))
else
  echo "FAIL: docker compose not available"
  FAIL=$((FAIL+1))
fi

check_binary lazydocker "lazydocker --version" "0.24.4"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

### Anti-Patterns to Avoid

- **Running `docker run hello-world` inside bootstrap:** Group membership is not active in the same session that ran `usermod`. Always defer to verify.sh.
- **Using `newgrp docker`:** This creates a subshell that breaks `set -eEuo pipefail` scripts. Not usable inside bootstrap.sh.
- **Using the get.docker.com convenience script for re-runs:** It prints a warning and blocks for 20 seconds when Docker is already installed. Silently continuing is not possible without `--force`.
- **Using `download.docker.com/linux/raspbian` for ARM64:** The raspbian Docker repo has `binary-armhf/` only — no arm64 packages. ARM64 RPi OS must use the `debian` repo.
- **Hardcoding version strings inside install functions:** All versions must come from `lib/versions.sh` so Phase 4 Renovate Bot setup has a single file to target.
- **Extracting binary without checking tarball structure:** Each tool has a different archive layout. See tarball structures below.

---

## Architecture Mapping Table (CRITICAL)

The `$ARCH` variable from `os.sh` outputs `x86_64` or `arm64`. Each tool uses different naming in their GitHub Release URLs. This table is the single source of truth for the planner.

| Tool | x86_64 URL fragment | arm64 URL fragment | Tarball structure | Binary path in archive |
|------|--------------------|--------------------|-------------------|------------------------|
| ripgrep | `x86_64-unknown-linux-musl` | `aarch64-unknown-linux-gnu` | subdirectory | `ripgrep-{ver}-{arch}/rg` |
| fd | `x86_64-unknown-linux-musl` | `aarch64-unknown-linux-gnu` | subdirectory | `fd-v{ver}-{arch}/fd` |
| fzf | `linux_amd64` | `linux_arm64` | **flat (no subdir)** | `fzf` |
| eza | `x86_64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu` | **flat (./eza)** | `./eza` |
| bat | `x86_64-unknown-linux-musl` | `aarch64-unknown-linux-gnu` | subdirectory | `bat-v{ver}-{arch}/bat` |
| delta | `x86_64-unknown-linux-musl` | `aarch64-unknown-linux-gnu` | subdirectory | `delta-{ver}-{arch}/delta` |
| neovim | `nvim-linux-x86_64` | `nvim-linux-arm64` | subdirectory | `nvim-linux-{arch}/bin/nvim` |
| lazydocker | `Linux_x86_64` | `Linux_arm64` | **flat (no subdir)** | `lazydocker` |

**Notes on arch naming in URLs:**
- ripgrep x86_64 uses `-musl` (statically linked, better portability); arm64 uses `-gnu`
- fd: both versions available in both musl and gnu; use `-musl` for x86_64, `-gnu` for aarch64 for consistency
- fzf: uses `amd64`/`arm64` (not x86_64/aarch64) — requires mapping from `$ARCH`
- eza: uses `x86_64`/`aarch64` (matching `$ARCH` on x86_64, but arm64 maps to `aarch64`)
- neovim: uses `x86_64`/`arm64` (arm64 matches `$ARCH` directly, x86_64 matches too)
- lazydocker: uses `x86_64`/`arm64` (matching `$ARCH` on arm64, but x86_64 matches too)

**Summary of `$ARCH` mappings needed in install functions:**

| `$ARCH` value | ripgrep | fd | fzf | eza | bat | delta | nvim | lazydocker |
|---------------|---------|-----|-----|-----|-----|-------|------|------------|
| `x86_64` | `x86_64` (musl) | `x86_64` (musl) | `amd64` | `x86_64` | `x86_64` (musl) | `x86_64` (musl) | `x86_64` | `x86_64` |
| `arm64` | `aarch64` (gnu) | `aarch64` (gnu) | `arm64` | `aarch64` | `aarch64` (gnu) | `aarch64` (gnu) | `arm64` | `arm64` |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Docker Engine install | Custom package setup | Official apt repo pattern | Handles GPG, repo sources, multi-arch, updates |
| Architecture detection | Custom `uname -m` parsing | Existing `os_detect_arch()` from `lib/os.sh` | Already normalized, already tested |
| OS detection for Docker repo | Custom `/etc/os-release` parsing | `. /etc/os-release && echo "$ID"` | Standard subshell sourcing pattern |
| Temp directory cleanup | Manual rm in script body | `trap 'rm -rf "$tmpdir"' RETURN` | Established pattern from gitleaks installer |
| Version store | Per-file version vars | `lib/versions.sh` | Single file for Phase 4 Renovate Bot |
| Idempotency check | Script-level re-run guard | Per-function binary+version check | Allows partial re-runs if one install fails |

**Key insight:** The gitleaks installer in `scripts/install-gitleaks.sh` is the canonical reference implementation for the GitHub Releases binary download pattern. All seven CLI tool installers follow it exactly — the only differences are the URL template and binary path within the archive.

---

## Common Pitfalls

### Pitfall 1: Architecture Mismatch in URLs
**What goes wrong:** Using `arm64` in a URL where the release uses `aarch64` (or vice versa) causes a 404 at download time.
**Why it happens:** No consistent convention across GitHub project maintainers.
**How to avoid:** Use the Architecture Mapping Table above. Test URLs for both architectures before writing the install function.
**Warning signs:** `curl` exits with non-zero due to HTTP 404; verify with `--fail` flag (already in the established pattern).

### Pitfall 2: Docker Convenience Script is Not Idempotent
**What goes wrong:** Running `curl https://get.docker.com | bash` when Docker is already installed prints a warning, **blocks for 20 seconds** (hardcoded `sleep 20`), then continues — not safely idempotent.
**Why it happens:** The script is designed for first-time installs; it explicitly documents it is not for upgrades.
**How to avoid:** Use the official apt repository method. Guard with `command -v docker` + `systemctl is-active --quiet docker`.
**Warning signs:** Bootstrap hangs for 20 seconds on re-run.

### Pitfall 3: raspbian Docker Repo Lacks arm64 Packages
**What goes wrong:** Raspberry Pi OS 64-bit (Bookworm) — `ID=debian` in `/etc/os-release` — has no `binary-arm64/` in `download.docker.com/linux/raspbian/dists/bookworm/stable/`. Install fails silently or with a "package not found" error.
**Why it happens:** Docker's raspbian repo only supports 32-bit armhf. 64-bit RPi OS is treated as Debian.
**How to avoid:** Detect `ID` from `/etc/os-release`. Map `raspbian` → `debian` for the Docker repo URL. Raspberry Pi OS 64-bit Bookworm actually reports `ID=debian` already, so the default `debian` fallback handles it.
**Warning signs:** `apt-get install docker-ce` fails with "package not found" on RPi 64-bit.

### Pitfall 4: Flat Archive Extraction vs Subdirectory Archive
**What goes wrong:** Extracting fzf, eza, or lazydocker with a path expecting a subdirectory (e.g., `tar -xz -C "$tmpdir" fzf-0.68.0-linux_amd64/fzf`) fails because the archive is flat.
**Why it happens:** Each maintainer makes their own packaging choice. No standard.
**How to avoid:** Use the Architecture Mapping Table column "Tarball structure" to know which tools need `tar -xz -C "$tmpdir"` (flat) vs targeting a specific path.
**Implementation pattern for flat archives:**
```bash
# Flat archive (fzf, eza, lazydocker):
tar -xz -C "$tmpdir" -f <(curl ...) fzf  # won't work - pipe + path
# Better:
curl ... | tar -xz -C "$tmpdir"
install -m 755 "${tmpdir}/fzf" "$install_path"
```

### Pitfall 5: neovim AppImage Requires FUSE — Use Tarball Instead
**What goes wrong:** AppImage requires FUSE kernel module. Many minimal/headless server images lack `fuse` or `libfuse2`. AppImage execution fails with "cannot mount AppImage: no usable temporary directory found in $TMPDIR:/$HOME/.appimage:/$HOME:/$HOME/Applications:/tmp".
**Why it happens:** AppImage relies on FUSE for self-mounting the embedded filesystem.
**How to avoid:** Use the tarball release (`nvim-linux-{arch}.tar.gz`), not the AppImage. The tarball extracts to `nvim-linux-{arch}/bin/nvim` — a standard ELF binary with no FUSE dependency.
**Warning signs:** STATE.md already flags this: "Confirm neovim ARM64 install method — tarball (nvim-linux-arm64.tar.gz) recommended over AppImage to avoid FUSE dependency on headless servers."

### Pitfall 6: Docker Group Not Active During Bootstrap Session
**What goes wrong:** Running `docker run hello-world` as `$SUDO_USER` inside bootstrap fails with "permission denied" even after `usermod -aG docker $SUDO_USER`.
**Why it happens:** Group membership changes require a new login session to take effect. The current session's group list is fixed at login.
**How to avoid:** Do NOT run docker commands as the bootstrap user inside bootstrap. Use `systemctl is-active docker` for in-bootstrap verification. Defer `docker run hello-world` to `scripts/verify.sh`.
**Warning signs:** `docker: permission denied while trying to connect to the Docker daemon socket`.

### Pitfall 7: install-gitleaks.sh Has Hardcoded GITLEAKS_VERSION
**What goes wrong:** After creating `lib/versions.sh`, the gitleaks version is defined in two places — the hardcoded variable in `install-gitleaks.sh` AND in `versions.sh`. Phase 4 Renovate Bot targets `versions.sh` only; the hardcoded one becomes stale.
**Why it happens:** `install-gitleaks.sh` was written in Phase 1 before `versions.sh` existed.
**How to avoid:** Phase 3 must update `install-gitleaks.sh` to source `versions.sh` and remove the hardcoded `GITLEAKS_VERSION="8.30.0"` line. This is part of the Phase 3 scope since `versions.sh` is created in this phase.

### Pitfall 8: Failure in One Tool Aborts All Remaining Installs
**What goes wrong:** With `set -eEuo pipefail` active in bootstrap.sh, a single tool install failure exits the entire bootstrap, leaving the server in a partial state.
**Why it happens:** `set -e` exits on any non-zero return code.
**How to avoid:** Wrap each tool install in a helper that catches failures and appends to `_SUMMARY_WARNINGS` rather than failing hard. Recommended failure strategy: soft-fail per tool (log warning, continue), hard-fail for Docker Engine (required infrastructure). This matches the principle from bootstrap.sh where `|| true` is used for non-critical operations.

---

## Code Examples

### Architecture Mapping Function (reusable within install-tools.sh)

```bash
# Maps os.sh canonical ARCH to tool-specific naming
_arch_for_tool() {
  local tool="$1"
  case "$tool" in
    fzf)
      case "$ARCH" in
        x86_64) echo "amd64" ;;
        arm64)  echo "arm64" ;;
      esac
      ;;
    eza|ripgrep|fd|bat|delta)
      case "$ARCH" in
        x86_64) echo "x86_64" ;;
        arm64)  echo "aarch64" ;;
      esac
      ;;
    nvim|lazydocker)
      # nvim and lazydocker use x86_64/arm64 naming (matching $ARCH)
      echo "$ARCH"
      ;;
  esac
}
```

### Flat Archive Install (fzf, eza, lazydocker pattern)

```bash
install_fzf() {
  local version="${FZF_VERSION}"
  local install_path="/usr/local/bin/fzf"

  log_step "Checking fzf ${version}..."

  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "fzf ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("fzf ${version}")
      return 0
    fi
  fi

  [[ "${DRY_RUN:-false}" == "true" ]] && { log_info "[DRY RUN] Would install fzf ${version}"; return 0; }

  # fzf uses amd64/arm64 naming, not x86_64/aarch64
  local fzf_arch
  case "$ARCH" in
    x86_64) fzf_arch="amd64" ;;
    arm64)  fzf_arch="arm64" ;;
  esac

  local url="https://github.com/junegunn/fzf/releases/download/v${version}/fzf-${version}-linux_${fzf_arch}.tar.gz"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  # fzf is a flat archive — binary is directly in $tmpdir
  install -m 755 "${tmpdir}/fzf" "$install_path"

  log_success "fzf ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("fzf ${version}")
}
```

### neovim Tarball Install (subdirectory with bin/ path)

```bash
install_nvim() {
  local version="${NVIM_VERSION}"
  local install_path="/usr/local/bin/nvim"

  log_step "Checking nvim ${version}..."

  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "nvim ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("nvim ${version}")
      return 0
    fi
  fi

  [[ "${DRY_RUN:-false}" == "true" ]] && { log_info "[DRY RUN] Would install nvim ${version}"; return 0; }

  # nvim uses x86_64/arm64 naming (arm64 matches $ARCH directly; x86_64 also matches)
  # Tarball: nvim-linux-{arch}/bin/nvim
  local url="https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-${ARCH}.tar.gz"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/nvim-linux-${ARCH}/bin/nvim" "$install_path"

  log_success "nvim ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("nvim ${version}")
}
```

### bootstrap.sh Wiring Pattern (matches install-shell.sh precedent)

```bash
# Phase 3: CLI tools and Docker
# shellcheck source=scripts/install-tools.sh
source "${DOTFILES_DIR}/scripts/install-tools.sh"
install_ripgrep
install_fd
install_fzf
install_eza
install_bat
install_delta
install_nvim

# shellcheck source=scripts/install-docker.sh
source "${DOTFILES_DIR}/scripts/install-docker.sh"
install_docker_engine
verify_docker_running
add_user_to_docker_group
install_lazydocker
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Docker convenience script (get.docker.com) | Official apt repository | Ongoing — script is designed for dev convenience, not provisioning | Idempotent, no 20-second block, version-pinnable |
| neovim AppImage | neovim tarball (`nvim-linux-{arch}.tar.gz`) | Available since v0.9.x | No FUSE dependency; works on headless servers |
| Hardcoded versions in install scripts | Centralized `lib/versions.sh` | Phase 3 introduces | Single file for Phase 4 Renovate Bot |

**Deprecated/outdated:**
- `docker-compose` (v1, standalone binary): Replaced by `docker compose` (v2, plugin). The `docker-compose-plugin` package installs the v2 plugin. Do not install v1.
- neovim AppImage: Functional but FUSE-dependent. Tarball is the correct choice for servers.

---

## Open Questions

1. **GITLEAKS_VERSION in install-gitleaks.sh needs to be updated**
   - What we know: `install-gitleaks.sh` has `GITLEAKS_VERSION="8.30.0"` hardcoded. `versions.sh` is being created in Phase 3.
   - What's unclear: Does Phase 3 include updating `install-gitleaks.sh` to source `versions.sh` and remove the hardcoded value, or does Phase 4 handle this when wiring up Renovate Bot?
   - Recommendation: Include this in Phase 3 scope since `versions.sh` is created here. A partial migration (new tools use `versions.sh`, gitleaks doesn't) defeats the purpose of a canonical version store.

2. **Failure handling: soft-fail per tool vs hard-fail all**
   - What we know: Claude's discretion per CONTEXT.md. `set -eEuo pipefail` is active in bootstrap.sh.
   - What's unclear: Whether to propagate per-tool failures or catch and warn.
   - Recommendation: Soft-fail for CLI tools (each wrapped in a function that catches failures with `|| true` and appends to `_SUMMARY_WARNINGS`), hard-fail for Docker Engine installation (Docker is core infrastructure — if apt setup fails, there's a real problem).

3. **delta arm64 binary stability**
   - What we know: STATE.md flags "Verify delta arm64 binary stability at target pinned version before committing version number." delta 0.18.2 does have `delta-0.18.2-aarch64-unknown-linux-gnu.tar.gz` on GitHub Releases.
   - What's unclear: The STATE.md concern may be about whether the compiled binary runs reliably on RPi OS Bookworm arm64 (potential glibc version issues with `-gnu` builds).
   - Recommendation: Pin to 0.18.2 (confirmed present). If glibc issues arise, delta 0.18.2 does not have a musl arm64 build — would need to fall back to apt `git-delta` package. Flag as LOW risk since the gnu build typically works on Bookworm's glibc 2.35+.

---

## Sources

### Primary (HIGH confidence)

- Live GitHub Releases API (`api.github.com/repos/.../releases/latest`) — all version numbers and asset names verified 2026-02-22
- Tarball contents verified via `curl | tar -tz` for all eight tools (both architectures where applicable)
- `https://docs.docker.com/engine/install/ubuntu/` — Ubuntu apt repository installation steps
- `https://docs.docker.com/engine/install/debian/` — Debian apt repository installation steps (covers RPi OS 64-bit)
- `https://download.docker.com/linux/raspbian/dists/bookworm/stable/` — confirmed: no `binary-arm64/` present
- `https://download.docker.com/linux/debian/dists/bookworm/stable/` — confirmed: `binary-arm64/` present
- `https://get.docker.com` (actual script source) — confirmed: 20-second `sleep` on re-run, explicit "not designed for upgrades" comment

### Secondary (MEDIUM confidence)

- `https://docs.docker.com/engine/install/raspberry-pi-os/` — RPi OS 32-bit specific guide; confirmed recommendation to use Debian packages for 64-bit
- `https://docs.docker.com/engine/install/linux-postinstall/` — docker group membership and `usermod -aG docker $USER`

### Tertiary (LOW confidence)

- lazydocker `--version` output format: based on source code inspection (flaggy library with version string); actual output format not directly verified by running the binary

---

## Metadata

**Confidence breakdown:**
- Standard stack (versions, repos): HIGH — verified from live GitHub Releases API and tarball contents
- Architecture mapping table: HIGH — verified by actually fetching each tarball and checking contents
- Docker install method: HIGH — verified from official Docker docs and live script inspection
- Docker raspbian vs debian repo distinction: HIGH — verified by listing actual repository contents
- Pitfalls: HIGH — verified from script source, official docs, and project STATE.md flags
- lazydocker --version format: LOW — inferred from source code, not executed

**Research date:** 2026-02-22
**Valid until:** 2026-05-22 (stable ecosystem; tool versions change but patterns are stable for ~90 days)
