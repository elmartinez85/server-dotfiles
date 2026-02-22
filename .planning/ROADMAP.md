# Roadmap: server-dotfiles

## Overview

Four phases transform an empty repo into a one-command bootstrap system. Phase 1 builds the repo skeleton and foundation scripts that everything else depends on. Phase 2 installs and deploys the shell environment — the core product that makes a server feel familiar. Phase 3 installs the modern CLI tools and Docker runtime that complete the workstation-class environment. Phase 4 hardens SSH access and adds brute-force protection, and then locks in version management tooling so the system stays current. Phases execute in strict order: SSH hardening requires all tools and shell configs to be correct before access is restricted.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Repo skeleton, bootstrap entrypoint, shared lib functions, and secret prevention (completed 2026-02-22)
- [x] **Phase 2: Shell Environment and Config Deployment** - zsh, oh-my-zsh, starship, tmux, plugins, and symlinked configs (completed 2026-02-22)
- [x] **Phase 3: CLI Tools and Docker** - Modern CLI tools from GitHub Releases and Docker Engine with Compose (completed 2026-02-22)
- [ ] **Phase 4: Security and Maintenance** - SSH hardening, fail2ban, UFW firewall, and automated version updates

## Phase Details

### Phase 1: Foundation
**Goal**: A working repo structure exists with a runnable bootstrap entrypoint, shared helper libraries, and safeguards that prevent secrets from ever reaching the repo
**Depends on**: Nothing (first phase)
**Requirements**: BOOT-01, BOOT-02, BOOT-03, BOOT-04
**Success Criteria** (what must be TRUE):
  1. Running `curl <url> | bash` on a fresh server starts the bootstrap without error
  2. Running the bootstrap script a second time on the same server completes without side effects or failures
  3. The bootstrap script correctly detects x86_64 and ARM64 architectures and exports the appropriate variables
  4. Attempting to commit a file containing a secret causes the pre-commit hook to block the commit
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Repo skeleton and shared bash libraries (lib/log.sh, lib/os.sh, lib/pkg.sh)
- [ ] 01-02-PLAN.md — bootstrap.sh entrypoint (curl | bash, idempotent, arch detection, cleanup, dry-run)
- [ ] 01-03-PLAN.md — gitleaks installer and pre-commit hook (secret prevention)

### Phase 2: Shell Environment and Config Deployment
**Goal**: After bootstrap, the server has zsh as the default shell with oh-my-zsh, starship, tmux, and all plugins active, and all config files deployed as symlinks from the repo
**Depends on**: Phase 1
**Requirements**: SHELL-01, SHELL-02, SHELL-03, SHELL-04, SHELL-05, SHELL-06, CONF-01, CONF-02, CONF-03, CONF-04, CONF-05
**Success Criteria** (what must be TRUE):
  1. A new shell session on the bootstrapped server opens zsh with starship prompt, autosuggestions, and syntax highlighting active
  2. tmux is installed and launches without error
  3. Config files (.zshrc, aliases, .tmux.conf, starship.toml) exist in $HOME as symlinks pointing into the cloned repo
  4. Pre-existing config files are preserved in ~/.dotfiles.bak/ rather than overwritten
  5. The server shell feels similar to macOS (same aliases, same tools, same prompt) — not required to run the same .zshrc verbatim on macOS
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Dotfiles content (dotfiles/.zshrc, .zsh_aliases, .tmux.conf, starship.toml)
- [ ] 02-02-PLAN.md — Shell stack installer (scripts/install-shell.sh) and bootstrap.sh wiring

### Phase 3: CLI Tools and Docker
**Goal**: All seven modern CLI tools are installed with correct binary names and Docker is running with the bootstrap user able to execute container commands without sudo
**Depends on**: Phase 2
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05, TOOL-06, TOOL-07, DOCK-01, DOCK-02, DOCK-03, DOCK-04
**Success Criteria** (what must be TRUE):
  1. `rg`, `fd`, `fzf`, `eza`, `bat`, `delta`, and `nvim` all run successfully on both x86_64 and ARM64 after bootstrap
  2. `docker run hello-world` succeeds without sudo as the bootstrap user
  3. `docker compose version` returns a version string
  4. `lazydocker` launches and shows the container management UI
**Plans**: 4 plans

Plans:
- [ ] 03-01-PLAN.md — lib/versions.sh (canonical version store) + update install-gitleaks.sh to source it
- [ ] 03-02-PLAN.md — scripts/install-tools.sh (seven CLI tool installer functions)
- [ ] 03-03-PLAN.md — scripts/install-docker.sh (Docker Engine + Compose + lazydocker)
- [ ] 03-04-PLAN.md — scripts/verify.sh (operator post-relogin checks) + bootstrap.sh Phase 3 wiring

### Phase 4: Security and Maintenance
**Goal**: The server rejects all SSH password authentication attempts and brute-force attacks, the firewall enforces default-deny inbound policy, and pinned tool versions are tracked in a single file with automated update PRs
**Depends on**: Phase 3
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, MAINT-01, MAINT-02
**Success Criteria** (what must be TRUE):
  1. SSH login with the configured public key succeeds; SSH login with a password is rejected
  2. SSH root login is rejected
  3. fail2ban is running and its status shows the sshd jail is active
  4. UFW status shows default-deny inbound with SSH explicitly allowed, and SSH connections work through the firewall
  5. All pinned tool versions are defined in a single `versions.sh` file and Renovate Bot is configured to open PRs for new releases
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete   | 2026-02-22 |
| 2. Shell Environment and Config Deployment | 2/2 | Complete   | 2026-02-22 |
| 3. CLI Tools and Docker | 4/4 | Complete   | 2026-02-22 |
| 4. Security and Maintenance | 0/TBD | Not started | - |
