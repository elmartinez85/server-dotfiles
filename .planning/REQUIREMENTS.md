# Requirements: server-dotfiles

**Defined:** 2026-02-22
**Core Value:** One command turns a bare Ubuntu/RPi server into a fully-configured, familiar environment — no manual steps.

## v1 Requirements

### Bootstrap

- [ ] **BOOT-01**: User can bootstrap a fresh server with a single `curl | bash` command
- [ ] **BOOT-02**: Bootstrap script is idempotent — safe to re-run on an existing server without side effects
- [ ] **BOOT-03**: Bootstrap script detects OS architecture (x86_64 and ARM64) and installs appropriate binaries
- [ ] **BOOT-04**: Repository enforces a pre-commit hook to prevent secrets from being committed

### Shell Environment

- [ ] **SHELL-01**: User has zsh installed and set as the default shell after bootstrap
- [ ] **SHELL-02**: User has oh-my-zsh installed via unattended install (no interactive prompts)
- [ ] **SHELL-03**: User has starship prompt installed and active in zsh
- [ ] **SHELL-04**: User has tmux installed
- [ ] **SHELL-05**: User has zsh-autosuggestions plugin active
- [ ] **SHELL-06**: User has zsh-syntax-highlighting plugin active

### Config Deployment

- [ ] **CONF-01**: zsh config (.zshrc and aliases) deployed to $HOME via symlinks from repo
- [ ] **CONF-02**: tmux config (.tmux.conf) deployed to $HOME via symlinks from repo
- [ ] **CONF-03**: starship config (starship.toml) deployed to $HOME/.config via symlinks from repo
- [ ] **CONF-04**: Pre-existing config files backed up to ~/.dotfiles.bak/ before symlinks are created
- [ ] **CONF-05**: zsh config on servers provides a similar shell experience to macOS (same aliases, same tools, same feel — not required to run verbatim on macOS)

### CLI Tools

- [ ] **TOOL-01**: ripgrep installed and accessible as `rg`
- [ ] **TOOL-02**: fd installed and accessible as `fd`
- [ ] **TOOL-03**: fzf installed and accessible as `fzf`
- [ ] **TOOL-04**: eza installed and accessible as `eza`
- [ ] **TOOL-05**: bat installed and accessible as `bat`
- [ ] **TOOL-06**: delta installed and accessible as `delta`
- [ ] **TOOL-07**: neovim installed and accessible as `nvim`

### Docker

- [ ] **DOCK-01**: Docker Engine installed via official install script (handles x86_64 and ARM64)
- [ ] **DOCK-02**: Docker Compose plugin installed and accessible as `docker compose`
- [ ] **DOCK-03**: Bootstrap user added to docker group (docker commands run without sudo)
- [ ] **DOCK-04**: lazydocker installed for terminal-based container management (status, logs, start/stop)

### Security

- [ ] **SEC-01**: User's SSH public key deployed to ~/.ssh/authorized_keys from $SSH_PUBLIC_KEY env var
- [ ] **SEC-02**: SSH password authentication disabled after key deployment is verified
- [ ] **SEC-03**: SSH root login disabled
- [ ] **SEC-04**: sshd config validated with `sshd -t` before every sshd service restart
- [ ] **SEC-05**: fail2ban installed and enabled
- [ ] **SEC-06**: UFW configured with default-deny inbound policy and SSH explicitly allowed before firewall is enabled

### Maintenance

- [ ] **MAINT-01**: Tool versions centralized in a `versions.sh` file (single place to update all pinned versions)
- [ ] **MAINT-02**: Renovate Bot configured to open automated PRs when new GitHub Release versions are available for pinned tools

## v2 Requirements

### Shell

- **SHELL-07**: neovim full config (init.lua / Lua plugin setup) — neovim binary is v1; full config is a separate effort
- **SHELL-08**: git config (.gitconfig) deployed via symlinks

### Docker

- **DOCK-05**: Lightweight web UI for container management (e.g., Dozzle) deployed as a compose stack

### Secrets

- **SEC-07**: Secrets fetched from password manager CLI (Bitwarden `bw` or 1Password `op`) at bootstrap time — more ergonomic than env vars for multiple servers

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multiple server roles/profiles | Adds complexity beyond value for single-user homelab; all servers get identical setup |
| macOS bootstrap | macOS is already managed separately; out of scope for this repo |
| Interactive wizard during bootstrap | Breaks `curl \| bash` pattern — stdin is a pipe, not a terminal |
| Rollback/undo mechanism | Wrong abstraction layer; idempotent re-run is the recovery path; OS snapshots for the rest |
| Ansible / configuration management | Massive dependency for a personal tool; pure bash is simpler and sufficient |
| Compose files in this repo | Compose files live in a separate repo; bootstrap only installs Docker runtime |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOT-01 | Phase 1 | Pending |
| BOOT-02 | Phase 1 | Pending |
| BOOT-03 | Phase 1 | Pending |
| BOOT-04 | Phase 1 | Pending |
| SHELL-01 | Phase 2 | Pending |
| SHELL-02 | Phase 2 | Pending |
| SHELL-03 | Phase 2 | Pending |
| SHELL-04 | Phase 2 | Pending |
| SHELL-05 | Phase 2 | Pending |
| SHELL-06 | Phase 2 | Pending |
| CONF-01 | Phase 2 | Pending |
| CONF-02 | Phase 2 | Pending |
| CONF-03 | Phase 2 | Pending |
| CONF-04 | Phase 2 | Pending |
| CONF-05 | Phase 2 | Pending |
| TOOL-01 | Phase 3 | Pending |
| TOOL-02 | Phase 3 | Pending |
| TOOL-03 | Phase 3 | Pending |
| TOOL-04 | Phase 3 | Pending |
| TOOL-05 | Phase 3 | Pending |
| TOOL-06 | Phase 3 | Pending |
| TOOL-07 | Phase 3 | Pending |
| DOCK-01 | Phase 3 | Pending |
| DOCK-02 | Phase 3 | Pending |
| DOCK-03 | Phase 3 | Pending |
| DOCK-04 | Phase 3 | Pending |
| SEC-01 | Phase 4 | Pending |
| SEC-02 | Phase 4 | Pending |
| SEC-03 | Phase 4 | Pending |
| SEC-04 | Phase 4 | Pending |
| SEC-05 | Phase 4 | Pending |
| SEC-06 | Phase 4 | Pending |
| MAINT-01 | Phase 4 | Pending |
| MAINT-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 32 total
- Mapped to phases: 32
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-22*
*Last updated: 2026-02-22 after roadmap creation*
