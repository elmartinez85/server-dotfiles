---
phase: 03-cli-tools-and-docker
verified: 2026-02-22T00:00:00Z
status: passed
score: 16/16 must-haves verified
re_verification: false
---

# Phase 3: CLI Tools and Docker Verification Report

**Phase Goal:** All seven modern CLI tools are installed with correct binary names and Docker is running with the bootstrap user able to execute container commands without sudo
**Verified:** 2026-02-22
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                 | Status     | Evidence                                                                                           |
|----|-------------------------------------------------------------------------------------------------------|------------|----------------------------------------------------------------------------------------------------|
| 1  | lib/versions.sh exists and exports all pinned version variables for all phases                        | VERIFIED   | File present, all 9 vars confirmed (GITLEAKS, RIPGREP, FD, FZF, EZA, BAT, DELTA, NVIM, LAZYDOCKER) |
| 2  | install-gitleaks.sh sources lib/versions.sh and has no hardcoded GITLEAKS_VERSION variable           | VERIFIED   | `grep -c 'GITLEAKS_VERSION="8.30.0"'` returns 0; source call present at line 10                   |
| 3  | Sourcing versions.sh twice is a no-op (idempotency guard present)                                    | VERIFIED   | Double-source tested live: both source calls succeed silently; `_LIB_VERSIONS_LOADED` guard works  |
| 4  | install-tools.sh has 8 functions: 7 install functions + _arch_for_tool helper + _try_install wrapper | VERIFIED   | `grep -c "^install_"` returns 7; `_arch_for_tool` and `_try_install` both present at top level    |
| 5  | Each install function handles idempotency, DRY_RUN, arch mapping, and soft-fail                      | VERIFIED   | 7 DRY_RUN guards, 7 trap-based tmpdir cleanups, arch mapping in _arch_for_tool, _try_install wraps |
| 6  | Flat archives (fzf, eza) and subdirectory archives (ripgrep, fd, bat, delta, nvim) extracted correctly| VERIFIED   | fzf: `install "${tmpdir}/fzf"`; eza: `install "${tmpdir}/eza"`; others use `${tmpdir}/${subdir}/binary` |
| 7  | Each install function appends to summary arrays and writes to MANIFEST_FILE                           | VERIFIED   | 7 MANIFEST_FILE writes, _SUMMARY_INSTALLED and _SUMMARY_SKIPPED appends in every function         |
| 8  | install-docker.sh has 4 functions with correct responsibilities                                       | VERIFIED   | `grep -c` returns 4; install_docker_engine, verify_docker_running, add_user_to_docker_group, install_lazydocker |
| 9  | Docker Engine installed via official apt repo, not get.docker.com convenience script                 | VERIFIED   | `download.docker.com/linux` present; `get.docker.com` absent from file                            |
| 10 | Distro detection handles ubuntu, debian, and raspbian (RPi OS) correctly                             | VERIFIED   | `raspbian) docker_repo_distro="debian"` at line 36; `os_id` detection via `/etc/os-release`       |
| 11 | Bootstrap user added to docker group with re-login warning; docker run hello-world NOT in bootstrap  | VERIFIED   | `usermod -aG docker` present; re-login warn present; `docker run hello-world` absent from install-docker.sh |
| 12 | lazydocker uses flat archive extraction pattern                                                       | VERIFIED   | `install -m 755 "${tmpdir}/lazydocker"` (no subdir); FLAT comment at line 134                     |
| 13 | Docker Compose v2 plugin installed as docker-compose-plugin apt package                               | VERIFIED   | `docker-compose-plugin` in apt-get install block at line 62                                       |
| 14 | verify.sh exists, is executable, sources versions.sh, checks all 7 tools + 3 docker items            | VERIFIED   | 8 check_binary calls (7 tools + lazydocker) + docker run + docker compose; sources versions.sh    |
| 15 | verify.sh exits 0 only if all checks pass, exits 1 on any failure                                    | VERIFIED   | `[[ $FAIL -eq 0 ]]` at line 75 — non-zero exit code when FAIL > 0                                 |
| 16 | bootstrap.sh sources both Phase 3 scripts and calls functions with correct soft-fail/hard-fail split  | VERIFIED   | 7 `_try_install install_*` calls; `install_docker_engine` called bare (hard-fail); Phase 4 placeholder retained |

**Score:** 16/16 truths verified

---

### Required Artifacts

| Artifact                     | Expected                                        | Status     | Details                                                                |
|------------------------------|-------------------------------------------------|------------|------------------------------------------------------------------------|
| `lib/versions.sh`            | Canonical version store for all phases          | VERIFIED   | 27 lines; idempotency guard; 9 version variables; no exports           |
| `scripts/install-gitleaks.sh`| Updated to source versions.sh                  | VERIFIED   | Sources lib/versions.sh line 10; GITLEAKS_VERSION no longer hardcoded |
| `scripts/install-tools.sh`   | Seven CLI tool installer functions (min 200 ln) | VERIFIED   | 409 lines; contains install_ripgrep and all 6 peers                    |
| `scripts/install-docker.sh`  | Docker Engine + Compose + group + lazydocker   | VERIFIED   | 140 lines; contains install_docker_engine                              |
| `scripts/verify.sh`          | Operator post-relogin verification script       | VERIFIED   | 75 lines; executable (-rwxr-xr-x); contains docker run hello-world    |
| `bootstrap.sh`               | Bootstrap entrypoint with Phase 3 wiring       | VERIFIED   | Contains install-tools.sh source and all 7 _try_install calls          |

---

### Key Link Verification

| From                        | To                        | Via                                         | Status  | Details                                                      |
|-----------------------------|---------------------------|---------------------------------------------|---------|--------------------------------------------------------------|
| install-gitleaks.sh         | lib/versions.sh           | `source ${DOTFILES_DIR}/lib/versions.sh`    | WIRED   | Line 10; pattern `source.*lib/versions\.sh` matches          |
| install-tools.sh            | lib/versions.sh           | `source ${DOTFILES_DIR}/lib/versions.sh`    | WIRED   | Line 13; pattern matches                                     |
| install_ripgrep             | /usr/local/bin/rg         | `install -m 755`                            | WIRED   | `install -m 755 "${tmpdir}/${subdir}/rg" "$install_path"`    |
| install_nvim                | /usr/local/bin/nvim       | `install -m 755 .*/nvim-linux-.*/bin/nvim`  | WIRED   | `install -m 755 "${tmpdir}/nvim-linux-${ARCH}/bin/nvim"`     |
| install-docker.sh           | lib/versions.sh           | `source ${DOTFILES_DIR}/lib/versions.sh`    | WIRED   | Line 13; pattern matches                                     |
| install_docker_engine       | download.docker.com       | apt repository docker.list sources file     | WIRED   | `download.docker.com/linux/${docker_repo_distro}` in both GPG and apt lines |
| add_user_to_docker_group    | usermod -aG docker        | usermod                                     | WIRED   | `usermod -aG docker "$target_user"` at line 96               |
| install_lazydocker          | /usr/local/bin/lazydocker | `install -m 755` (flat archive)             | WIRED   | `install -m 755 "${tmpdir}/lazydocker" "$install_path"`      |
| bootstrap.sh                | scripts/install-tools.sh  | `source ${DOTFILES_DIR}/scripts/install-tools.sh` | WIRED | Line 165; pattern `source.*install-tools\.sh` matches  |
| bootstrap.sh                | scripts/install-docker.sh | `source ${DOTFILES_DIR}/scripts/install-docker.sh` | WIRED | Line 175; pattern `source.*install-docker\.sh` matches |
| scripts/verify.sh           | lib/versions.sh           | `source ${DOTFILES_DIR}/lib/versions.sh`    | WIRED   | Line 11; pattern matches; uses $RIPGREP_VERSION etc. (not hardcoded) |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                              | Status    | Evidence                                                                 |
|-------------|-------------|--------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------|
| TOOL-01     | 03-02, 03-04 | ripgrep installed and accessible as `rg`                                | SATISFIED | install_ripgrep installs to /usr/local/bin/rg; verify.sh checks `rg`    |
| TOOL-02     | 03-02, 03-04 | fd installed and accessible as `fd`                                     | SATISFIED | install_fd installs to /usr/local/bin/fd; verify.sh checks `fd`          |
| TOOL-03     | 03-02, 03-04 | fzf installed and accessible as `fzf`                                   | SATISFIED | install_fzf installs to /usr/local/bin/fzf; verify.sh checks `fzf`      |
| TOOL-04     | 03-02, 03-04 | eza installed and accessible as `eza`                                   | SATISFIED | install_eza installs to /usr/local/bin/eza; verify.sh checks `eza`       |
| TOOL-05     | 03-02, 03-04 | bat installed and accessible as `bat`                                   | SATISFIED | install_bat installs to /usr/local/bin/bat; verify.sh checks `bat`       |
| TOOL-06     | 03-02, 03-04 | delta installed and accessible as `delta`                               | SATISFIED | install_delta installs to /usr/local/bin/delta; verify.sh checks `delta` |
| TOOL-07     | 03-02, 03-04 | neovim installed and accessible as `nvim`                               | SATISFIED | install_nvim installs to /usr/local/bin/nvim via tarball (not AppImage); verify.sh checks `nvim` |
| DOCK-01     | 03-03, 03-04 | Docker Engine installed via official install (x86_64 and ARM64)         | SATISFIED | Official apt repo method with distro detection; raspbian->debian fallback for RPi OS arm64 |
| DOCK-02     | 03-03, 03-04 | Docker Compose plugin accessible as `docker compose`                    | SATISFIED | docker-compose-plugin installed in same apt block; verify.sh checks `docker compose version` |
| DOCK-03     | 03-03, 03-04 | Bootstrap user added to docker group (no sudo required)                 | SATISFIED | add_user_to_docker_group uses usermod -aG docker; verify.sh tests `docker run --rm hello-world` without sudo |
| DOCK-04     | 03-03, 03-04 | lazydocker installed for terminal-based container management             | SATISFIED | install_lazydocker installs from GitHub Releases flat archive; verify.sh checks lazydocker binary |
| MAINT-01    | 03-01       | Tool versions centralized in versions.sh                                | SATISFIED | lib/versions.sh created with all 9 pinned versions; all install scripts source it |

**Note on MAINT-01 traceability:** REQUIREMENTS.md traceability table maps MAINT-01 to Phase 4, but Plan 03-01 correctly claims and implements it in Phase 3 (lib/versions.sh is created here). The traceability table entry is a documentation inconsistency — the requirement is fully implemented and satisfied in this phase.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No anti-patterns detected across all six files |

---

### Human Verification Required

#### 1. Actual server installation — CLI tools

**Test:** Run bootstrap.sh on a fresh Ubuntu 22.04 or Raspberry Pi OS Bookworm arm64 server, then run `bash ~/.dotfiles/scripts/verify.sh` after re-login.
**Expected:** All 7 CLI tool checks report PASS with the correct version strings from lib/versions.sh.
**Why human:** Cannot test actual GitHub Release downloads, tarball extraction, or binary installation in this environment. Architecture mapping correctness (especially aarch64 vs arm64 naming) can only be confirmed by live execution on the target platform.

#### 2. Docker Engine installation on RPi OS arm64

**Test:** Run bootstrap.sh on a Raspberry Pi OS Bookworm arm64 server. Check that Docker Engine installs from `download.docker.com/linux/debian` (not `linux/raspbian` which lacks arm64 binaries).
**Expected:** `docker --version` succeeds; `systemctl status docker` shows active.
**Why human:** Distro detection logic (`raspbian -> debian` fallback) can only be validated by running against actual `/etc/os-release` content from RPi OS. The code path is correct but the test requires target hardware.

#### 3. Docker group membership and no-sudo container execution

**Test:** After bootstrap, log out and log back in via a new SSH session, then run `docker run --rm hello-world` without sudo.
**Expected:** Container runs successfully without sudo (exits 0). verify.sh reports "PASS: docker run hello-world (no sudo)".
**Why human:** Group membership (`usermod -aG docker`) only takes effect after a full re-login. The bootstrap correctly avoids `newgrp docker` (which would break set -eEuo pipefail). This can only be verified by a human performing the re-login and running the command.

#### 4. lazydocker TUI launch

**Test:** After installation, run `lazydocker` in a terminal.
**Expected:** Terminal UI launches showing Docker containers/images/volumes.
**Why human:** TUI launch cannot be automated; verify.sh only checks the binary's --version output (which RESEARCH.md notes has low confidence on format). Full functionality requires interactive testing.

---

### Gaps Summary

No gaps. All automated checks pass. The phase goal is fully achieved in code:

- lib/versions.sh is the canonical version store for all nine pinned tool versions with idempotency guard
- install-gitleaks.sh no longer has a hardcoded version and sources versions.sh
- install-tools.sh delivers all seven CLI tool installer functions with correct architecture mapping, flat/subdirectory archive handling, idempotency, DRY_RUN, soft-fail, and manifest entries
- install-docker.sh delivers Docker Engine via official apt repo, Compose plugin, docker group membership with re-login warning, and lazydocker — all without using get.docker.com
- verify.sh is executable, sources versions.sh for version strings, checks all 7 tools + docker run hello-world + docker compose + lazydocker, and exits 1 on any failure
- bootstrap.sh is fully wired: sources both Phase 3 scripts, calls all 7 CLI tools via _try_install (soft-fail), calls install_docker_engine bare (hard-fail), and retains the Phase 4 placeholder

Four items require human verification on live target hardware: actual download/installation, RPi OS distro detection, no-sudo docker execution after re-login, and lazydocker TUI launch.

---

_Verified: 2026-02-22_
_Verifier: Claude (gsd-verifier)_
