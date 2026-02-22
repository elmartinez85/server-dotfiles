# Project Research Summary

**Project:** server-dotfiles
**Domain:** Server dotfiles / one-command bootstrap system (Ubuntu x86_64 + Raspberry Pi ARM64)
**Researched:** 2026-02-22
**Confidence:** HIGH

## Executive Summary

This project is a personal server bootstrap system: a single `curl | bash` command that turns a bare Ubuntu or Raspberry Pi server into a fully configured, secure environment matching the operator's macOS development setup. Research across all four areas confirms the domain is well-understood with established patterns. The correct approach is a pure bash script layered over GNU Stow — no external tool dependencies beyond bash, curl, and git. This eliminates the bootstrapping problem that frameworks like chezmoi and Ansible introduce (you cannot use a tool to install itself). The repository layout follows the topics-based convention with a modular `install/` directory, shared `lib/` helper functions, and GNU Stow packages per tool. The entire system is designed to be idempotent: re-running the bootstrap on an existing server applies only what is missing or changed.

The recommended stack is intentionally minimal: Bash for orchestration, GNU Stow for symlink-based config deployment, and direct GitHub Releases binary downloads for modern CLI tools that are either missing from apt or installed with wrong binary names (bat, fd, eza, neovim). The shell environment mirrors a macOS zsh setup — oh-my-zsh, starship prompt, zsh-autosuggestions, zsh-syntax-highlighting — with platform-conditional sourcing in `.zshrc` to handle OS differences without forking the config file. Docker is installed via the official convenience script, which handles both x86_64 and ARM64 automatically.

The dominant risk in this domain is the SSH hardening sequence: disabling password authentication before verifying that key-based login works results in permanent lockout. The second systemic risk is secrets in the public git repo — automated bots harvest credentials from GitHub's event stream within minutes. Both risks are fully preventable through careful script ordering (key deployment before hardening), `sshd -t` validation before every sshd restart, and a strict policy of zero secrets in the repo (env vars only). Architecture-specific binary download failures (x86_64 vs aarch64) are the third critical pitfall and are resolved by centralizing arch detection in `lib/platform.sh` and mapping per-tool asset naming conventions.

## Key Findings

### Recommended Stack

Pure bash with GNU Stow is the unambiguous recommendation. All alternatives evaluated (chezmoi, Ansible, Homebrew on Linux, Cargo builds) introduce either a bootstrapping dependency, excessive complexity for a single-user system, or poor ARM64 support on Raspberry Pi. The architecture detection pattern — `uname -m` mapped to per-tool asset naming conventions via `lib/platform.sh` — is the central technical pattern that makes the multi-arch install reliable. Every tool in the modern CLI set has official ARM64 binaries on GitHub Releases; apt versions are stale or install with the wrong binary name (bat installs as `batcat`, fd installs as `fdfind`).

**Core technologies:**
- Bash 5.x (system): Orchestration entrypoint — zero dependencies, present on every Ubuntu/RPi server
- GNU Stow 2.3+ (apt): Symlink management — idempotent by design, transforms topics-based dir layout into $HOME symlinks
- Git 2.x (apt): Repo cloning and version control — bootstrap clones repo, stow deploys it
- curl (system): Binary and install script fetching — present on all Ubuntu/RPi images
- zsh + oh-my-zsh: Target shell environment — unattended install required (`RUNZSH=no CHSH=no`)
- starship: Cross-shell prompt — official install script handles arch detection automatically
- tmux: Terminal multiplexer — apt version sufficient, no compilation required

**Tools requiring GitHub Releases (not apt):** ripgrep, fd, eza, bat, delta, neovim. All have aarch64 binaries. The `detect_arch()` function must map `uname -m` output to per-tool naming conventions (some use `aarch64`, others use `arm64`, `.deb` packages use `arm64` for Debian convention).

### Expected Features

Research confirms a clear two-tier MVP: table stakes features that make the system trustworthy, and differentiators that make it durable.

**Must have (table stakes) — v1:**
- Idempotent execution — `set -euo pipefail` + check-before-act guards on every install action
- OS/architecture detection — `uname -m` called once in `lib/platform.sh`, exported as `$ARCH_MUSL`, `$ARCH_GNU`, `$ARCH_DEB`
- apt package install — single `apt-get install -y` call for all apt-sourced tools
- Zsh + oh-my-zsh + starship — shell environment matching macOS setup
- Config deployment via symlinks — symlinks, never copies; enables `git pull` to propagate changes instantly
- Backup pre-existing configs — move existing dotfiles to `~/.dotfiles.bak/` before symlinking
- Docker + Docker Compose install — official `get.docker.com` script; user added to docker group
- SSH public key deployment — from `$SSH_PUBLIC_KEY` env var; `chmod 700/.ssh`, `chmod 600/authorized_keys`
- SSH hardening — disable password auth, disable root login; `sshd -t` validation before restart
- Error handling — `set -euo pipefail` at top of every script; progress output throughout
- Zero secrets in repo — all sensitive values via env vars at invocation time

**Should have (differentiators) — v1.x after validation:**
- Fail2ban install — brute-force protection; complements SSH hardening
- UFW firewall setup — default-deny inbound, explicit SSH allow before enabling
- Modular structure — split monolithic bootstrap into `install/*.sh` modules once it exceeds ~200 lines
- Logging to `/var/log/bootstrap.log` — `tee` output for post-mortem debugging
- Modern CLI tools (eza, bat, delta) — quality of life; defer if ARM binary availability is uncertain

**Defer (v2+):**
- Neovim config (`init.lua`) — neovim binary is table stakes; full Lua config is a separate concern
- Secrets from Bitwarden/1Password CLI — more ergonomic than env vars for multi-server; adds CLI dependency
- Pure `curl | bash` repo clone inside bootstrap — adds git auth complexity for private repos

**Anti-features (do not build):**
- Multiple server roles/profiles — complexity exceeds value for single-user setup
- Interactive wizard — breaks `curl | bash` pattern; stdin is pipe, not terminal
- Rollback/undo — wrong abstraction layer; use OS snapshots; bootstrap idempotency is the recovery path
- Ansible/configuration management — massive dependency for a personal homelab tool

### Architecture Approach

The architecture follows the holman/dotfiles topics-based layout with five distinct layers: invocation (curl URL | bash), bootstrap entrypoint (clones repo, sources lib, calls install modules), install modules layer (packages, shell, tools, docker, ssh — each independently testable), config deployment layer (GNU Stow symlinks topics dirs to $HOME), and secrets layer (env vars consumed at runtime, never persisted). The critical constraint is module execution order: packages first (provides git, stow, curl for subsequent modules), shell second, tools third, Docker fourth, SSH hardening last.

**Major components:**
1. `bootstrap.sh` — Curl-safe entrypoint; detects arch, clones repo, sources lib, calls install modules in order
2. `lib/` (logging.sh, platform.sh, idempotent.sh) — Shared functions; arch detection exported as variables; guard functions (`command_exists`, `apt_installed`, `file_contains`)
3. `install/*.sh` (packages, shell, tools, docker, ssh) — Idempotent modules, each independently sourceable for debugging
4. Topics dirs (`zsh/`, `tmux/`, `starship/`, `git/`, `neovim/`) — GNU Stow packages; directory layout mirrors $HOME paths
5. `install/ssh.sh` — Sequenced: deploy key from env var → `sshd -t` validate → disable password auth → reload sshd

**Key patterns to follow:**
- Module sourcing with shared lib (not exec) — modules share shell session, inherit lib functions and ARCH vars
- Idempotency guards in `lib/idempotent.sh` — `command_exists`, `apt_installed`, `file_contains` used everywhere
- Architecture abstraction in `lib/platform.sh` — single `uname -m` call; per-tool naming variants exported
- Symlink deployment via `stow --restow` — runs after all tool installs so configs reference available binaries
- Platform-conditional zsh sourcing — `$OSTYPE` in `.zshrc` for macOS/Linux config splits

### Critical Pitfalls

1. **SSH hardening locks you out** — Sequence is non-negotiable: (1) deploy key to authorized_keys, (2) validate `sshd -t`, (3) disable password auth, (4) reload sshd. Never harden before key is verified. Never skip `sshd -t`. Keep a second session open during testing.

2. **Secrets committed to git history** — git history is permanent; automated bots harvest credentials within minutes of a public push. Prevention: comprehensive `.gitignore` for credential-adjacent filenames, pre-commit hook (`git-secrets` or `gitleaks`), env vars only for runtime secrets. Establish before any configs are written.

3. **Oh-my-zsh hijacks the bootstrap script** — Default installer spawns a new zsh shell, silently ending the parent bash script before subsequent steps run. Prevention: always install with `RUNZSH=no CHSH=no`; set default shell via `chsh` separately.

4. **Architecture-specific binary download failures** — Wrong arch binary silently installs, fails at runtime with `Exec format error`. Different tools use different naming conventions (aarch64 vs arm64 vs linux_arm64). Prevention: `lib/platform.sh` exports per-convention arch variables; `file $(which <tool>)` verification after install.

5. **Idempotency failures leave partial state** — Bootstrap interrupted and re-run hits "directory already exists" or appends duplicate config lines. Prevention: `set -euo pipefail` everywhere; `mkdir -p`, `ln -sf`, `grep -qxF` guards on every non-idempotent operation.

## Implications for Roadmap

Based on combined research, the dependency graph drives a clear 4-phase structure. Phases are ordered by build dependencies — each phase produces what the next phase needs.

### Phase 1: Repository Skeleton and Bootstrap Foundation

**Rationale:** Security posture and script correctness must be established before any code is written. The `.gitignore` strategy and `set -euo pipefail` convention cannot be retrofitted — they must exist from the first commit. This phase has no technical dependencies and unblocks everything.

**Delivers:** A working repo structure, `.gitignore` covering all credential-adjacent files, `bootstrap.sh` entrypoint with error handling, `lib/` shared functions (logging, platform/arch detection, idempotency guards), and the topics-based directory layout.

**Addresses:** Idempotent execution skeleton, OS/architecture detection, error handling, zero-secrets policy, pre-commit hook for secret scanning.

**Avoids:** Secrets in git history (Pitfall 1), idempotency failures from partial state (Pitfall 2), hardcoded architecture in download URLs (Pitfall 4).

**Research flag:** Standard patterns — well-documented. No additional research needed.

### Phase 2: Shell Environment and Config Deployment

**Rationale:** The shell environment is the core product — it's what makes the server feel familiar. It depends on Phase 1 (lib functions, arch detection) and is the prerequisite for config deployment (symlinks reference zsh being installed). All config files must exist before stow can deploy them.

**Delivers:** zsh installed and set as default shell, oh-my-zsh installed (unattended), starship prompt installed (arch-aware), tmux installed, zsh plugins (autosuggestions, syntax-highlighting, completions), config symlinks via GNU Stow (`zsh/`, `tmux/`, `starship/`, `git/`), backup of pre-existing configs.

**Addresses:** Zsh + oh-my-zsh + starship (P1), config deployment via symlinks (P1), backup pre-existing configs (P1), macOS config compatibility.

**Avoids:** Oh-my-zsh hijacking script (Pitfall 3 — `RUNZSH=no CHSH=no` required), macOS/Linux config incompatibility (platform-conditional sourcing in `.zshrc`).

**Research flag:** Standard patterns — well-documented. Specific flag: test `RUNZSH=no CHSH=no` behavior on Ubuntu 24.04 if not already verified.

### Phase 3: Modern CLI Tools and Docker

**Rationale:** These are independent of each other but both depend on Phase 1 arch detection. They can be built in parallel within the phase. CLI tools use the `$ARCH_MUSL`/`$ARCH_GNU`/`$ARCH_DEB` variables from `lib/platform.sh`. Docker uses the official install script that handles arch internally.

**Delivers:** ripgrep, fd, fzf, eza, bat, delta, neovim installed (arch-appropriate binaries), Docker Engine + Compose plugin installed, user added to docker group.

**Addresses:** apt package install (P1), modern CLI tools (P2), Docker + Compose (P1).

**Avoids:** apt binary naming issues (bat as batcat, fd as fdfind — use GitHub Releases), arch-specific binary failures (Pitfall 4 — per-tool URL functions with correct naming), Docker armhf deprecation (use arm64 not armhf on RPi).

**Research flag:** Needs attention during implementation — verify aarch64 asset availability for each tool at pinned versions. ARCHITECTURE.md notes ripgrep uses GNU libc (not musl) for arm64; confirm delta arm64 CI is stable at target version.

### Phase 4: SSH Hardening and Security Hardening

**Rationale:** SSH hardening must come last. The sequence is safety-critical: key must be deployed and verifiable before password auth is disabled. Running this phase before the shell environment is configured risks locking out of a misconfigured server. Additionally, fail2ban and UFW should be added in this phase.

**Delivers:** SSH public key deployed to `~/.ssh/authorized_keys` from `$SSH_PUBLIC_KEY` env var, `sshd_config` hardened (disable password auth, disable root login), `sshd -t` validation before every restart, fail2ban installed and enabled, UFW firewall configured (default-deny, SSH allowed before enabling).

**Addresses:** SSH key deployment (P1), SSH hardening (P1), fail2ban (P2), UFW (P2).

**Avoids:** SSH lockout (Pitfall 3 — strict sequencing and sshd -t before every restart), authorized_keys permission errors (explicit chmod 700/.ssh and chmod 600/authorized_keys), UFW self-lock (SSH allow before `ufw --force enable`).

**Research flag:** Standard patterns — well-documented. Critical: validate the exact `sshd -t` + `systemctl reload` sequence on both Ubuntu 24.04 and Raspberry Pi OS Bookworm (service name may differ).

### Phase Ordering Rationale

- Phase 1 before everything: repo structure and secret policy cannot be added later without history rewriting risk; arch detection must exist before any binary download
- Phase 2 before Phase 3: shell must be installed before tool configs are symlinked (configs reference tools); stow must be installed (via apt in Phase 1 packages) before config deployment
- Phase 3 before Phase 4: fully configured server before hardening reduces debugging complexity; a broken tool install is much easier to fix when you can still password-auth in
- Phase 4 last: SSH hardening is irreversible until manually undone; complete server configuration before locking down access

### Research Flags

Phases needing deeper research or implementation-time verification:
- **Phase 3 (tool installs):** Verify aarch64 binary availability at specific pinned versions for each tool before committing version numbers. Delta arm64 CI has had intermittent failures per STACK.md. Confirm `nvim-linux-arm64.tar.gz` format (not AppImage) for server use.
- **Phase 4 (SSH/UFW):** Confirm `systemctl` service name for sshd on RPi OS Bookworm (`sshd` vs `ssh`). Verify UFW sequence on Ubuntu 24.04 fresh install.

Phases with standard, well-documented patterns (no additional research needed):
- **Phase 1:** Bash scripting fundamentals, `.gitignore` patterns, and lib/logging/idempotency patterns are thoroughly documented.
- **Phase 2:** Oh-my-zsh unattended install flags are documented in the official repo. GNU Stow manual covers all deployment patterns. Starship's own installer handles arch detection.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core approach (bash + stow) verified via official docs. Tool-specific patterns verified against official GitHub Release pages and Docker docs. |
| Features | MEDIUM | Table stakes and anti-features are clear. v1.x prioritization (fail2ban, UFW, modular structure) is based on community consensus, not hard requirements. |
| Architecture | HIGH | holman/dotfiles topics pattern is widely replicated. GNU Stow manual is authoritative. Module sourcing pattern verified across multiple sources. |
| Pitfalls | HIGH | SSH lockout and OMZ hijacking patterns verified against official issue trackers and DigitalOcean tutorials. Arch binary failure modes verified against actual GitHub Release assets. |

**Overall confidence:** HIGH

### Gaps to Address

- **Delta arm64 binary stability:** STACK.md notes delta has had ARM64 CI breakage in some releases. At implementation time, verify the target pinned version has a working arm64 .deb before committing it.
- **Neovim ARM install method:** AppImage vs tarball for ARM64 — STACK.md recommends tarball (`nvim-linux-arm64.tar.gz`) to avoid FUSE dependency on headless servers. Confirm this at pinned version.
- **RPi OS Bookworm service names:** `sshd_config` reload uses `systemctl reload sshd` on Ubuntu but may be `systemctl reload ssh` on Debian-based RPi OS. Verify during Phase 4 implementation.
- **Pinned versions:** All GitHub Release binary versions must be pinned explicitly in install scripts. These will go stale over time; the repository needs a documented process for updating pinned versions.
- **Starship version pinning:** The official install script fetches latest; for reproducible installs, evaluate pinning the version via direct binary download instead.

## Sources

### Primary (HIGH confidence)
- [starship.rs](https://starship.rs/) — official install script, arch support
- [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) — `--unattended` flag, RUNZSH/CHSH vars, $ZSH_CUSTOM plugin pattern
- [docker/docker-install](https://github.com/docker/docker-install) — get.docker.com convenience script, ARM64 support
- [GNU Stow manual](https://www.gnu.org/software/stow/manual/stow.html) — symlink deployment patterns
- [holman/dotfiles](https://github.com/holman/dotfiles) — topics-based structure (widely replicated pattern)
- [eza-community/eza releases](https://github.com/eza-community/eza/releases) — aarch64 asset availability confirmed
- [BurntSushi/ripgrep releases](https://github.com/BurntSushi/ripgrep/releases) — aarch64-unknown-linux-gnu asset confirmed
- [neovim ARM64 AppImage issue #15143](https://github.com/neovim/neovim/issues/15143) — ARM64 AppImage since v0.10.4
- [ohmyzsh/ohmyzsh Issue #5675](https://github.com/ohmyzsh/ohmyzsh/issues/5675) — RUNZSH/CHSH env vars for automation
- [Docker on Raspberry Pi OS — Official Docs](https://docs.docker.com/engine/install/raspberry-pi-os/) — ARM Docker install, armhf deprecation

### Secondary (MEDIUM confidence)
- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/) — chezmoi vs stow vs alternatives
- [arslan.io idempotent bash](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — idempotency patterns for bash scripts
- [awesome-dotfiles](https://github.com/webpro/awesome-dotfiles) — curated ecosystem overview
- [ArchWiki: Dotfiles](https://wiki.archlinux.org/title/Dotfiles) — symlink vs copy patterns, bare git repo tradeoffs
- [SSH Hardening Guides — sshaudit.com](https://www.sshaudit.com/hardening_guides.html) — current sshd_config recommendations
- [Back to Basics: sshd Hardening 2025](https://www.msbiro.net/posts/back-to-basics-sshd-hardening/) — SSH hardening sequence pitfalls
- [How To Protect SSH with Fail2Ban — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-ubuntu-20-04) — fail2ban setup
- [1Password secrets in dotfiles](https://samedwardes.com/blog/2023-11-03-1password-for-secret-dotfiles/) — secrets via password manager CLI
- [dandavison/delta installation](https://dandavison.github.io/delta/installation.html) — .deb packages for ARM64 (ARM64 CI breakage noted in some releases)

### Tertiary (LOW confidence)
- [dotfiles.github.io](https://dotfiles.github.io/bootstrap/) — community catalog of bootstrap approaches (curated but not authoritative)

---
*Research completed: 2026-02-22*
*Ready for roadmap: yes*
