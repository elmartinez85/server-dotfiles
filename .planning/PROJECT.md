# Server Dotfiles

## What This Is

A one-command bootstrap system for fresh Ubuntu and Raspberry Pi servers. Run a single curl command on a new machine and walk away — it installs your preferred shell environment (zsh + oh-my-zsh + starship + tmux), modern CLI tools (ripgrep, fzf, fd, eza, bat, delta, neovim), Docker/Compose, and deploys all shell configs as symlinks from the repo. Shell configs are shared with macOS so servers feel immediately familiar.

Built for personal VPS and homelab use. Multiple servers get identical configs.

## Core Value

One command turns a bare Ubuntu/RPi server into a fully-configured, familiar environment — no manual steps.

## Requirements

### Validated

- ✓ Bootstrap script runs via `curl | bash` on a fresh server — v1.0
- ✓ Bootstrap is idempotent — safe to re-run on an existing server without side effects — v1.0
- ✓ Bootstrap detects OS architecture (x86_64 and ARM64) and installs appropriate binaries — v1.0
- ✓ Repository enforces a pre-commit hook to prevent secrets from being committed — v1.0
- ✓ Installs zsh as default shell, oh-my-zsh (unattended), starship, and tmux — v1.0
- ✓ Installs zsh-autosuggestions and zsh-syntax-highlighting plugins — v1.0
- ✓ Deploys shell configs (.zshrc, aliases, .tmux.conf, starship.toml) as symlinks from repo — v1.0
- ✓ Pre-existing config files backed up to ~/.dotfiles.bak/ before symlinks created — v1.0
- ✓ Server shell experience matches macOS (same aliases, same tools, same prompt) — v1.0
- ✓ Installs modern CLI tools: ripgrep, fd, fzf, eza, bat, delta, neovim — v1.0
- ✓ Installs Docker Engine + Docker Compose via official apt repo — v1.0
- ✓ Adds bootstrap user to docker group (no-sudo docker commands) — v1.0
- ✓ Installs lazydocker for terminal container management — v1.0
- ✓ Tool versions centralized in lib/versions.sh (single place to update all pinned versions) — v1.0

### Active

- [ ] SSH hardening: disable password auth, disable root login, validate sshd config with `sshd -t`
- [ ] SSH key deployment: install user's public key from $SSH_PUBLIC_KEY env var
- [ ] fail2ban installed and enabled with sshd jail
- [ ] UFW configured with default-deny inbound and SSH explicitly allowed before enabling
- [ ] Renovate Bot configured to open automated PRs for new GitHub Release versions

### Out of Scope

- macOS bootstrap — macOS is already managed separately
- Multiple server roles with different configs — all servers get same setup
- Secrets stored in repo — always fetched at runtime
- Interactive wizard during bootstrap — breaks `curl | bash` pattern (stdin is a pipe)
- Rollback/undo mechanism — idempotent re-run is the recovery path
- Ansible / configuration management — pure bash is simpler and sufficient for personal use
- Compose files in this repo — live in a separate repo; bootstrap only installs Docker runtime

## Context

**Shipped v1.0 (2026-02-23):**
- 1,277 lines of bash across bootstrap.sh, 3 lib files, 3 installer scripts, and verify.sh
- Tech stack: pure bash 5.x, apt, GitHub Releases binary downloads, git, gitleaks
- All 14 shipped requirements validated by static analysis; 5 Phase 2 items (prompt rendering, plugin activation, tmux prefix, idempotency on live zsh) require real server to confirm
- Known pre-deploy action: replace `<YOUR_GITHUB_USER>` placeholder in bootstrap.sh:7

**Target OS:** Ubuntu LTS + Raspberry Pi OS (both Debian-based, different architectures)
**Shell stack on macOS:** zsh + oh-my-zsh + starship + tmux — servers should feel identical
**Tools on Linux:** apt for zsh/tmux; direct GitHub Releases downloads for everything else
**Public GitHub repo:** No sensitive data can be committed; secrets via env vars at runtime

## Constraints

- **Architecture**: Must support both x86_64 (Ubuntu VPS) and ARM (Raspberry Pi) — some tools need different install paths
- **Public repo**: Zero secrets in version control — all sensitive values fetched at runtime
- **Idempotency**: Bootstrap script must be safe to re-run (config updates, not just fresh installs)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Pure bash over chezmoi/Ansible | Zero bootstrapping dependency; simpler for single-user homelab | ✓ Good — straightforward execution, easy to read and debug |
| apt + GitHub Releases binary downloads over Homebrew | Homebrew ARM support on RPi is inconsistent | ✓ Good — clean, no unexpected dependencies |
| Single config profile (no roles) | All servers get same setup, simpler to maintain | ✓ Good — no complexity needed for personal use |
| Secrets via env vars at runtime only | Public repo, can't commit keys/tokens | ✓ Good — clean separation |
| tee redirection in bootstrap.sh (not log.sh) | lib files only define functions; entrypoint owns I/O setup | ✓ Good — clean library pattern |
| os_detect_arch normalizes aarch64 → arm64 | Linux reports aarch64, macOS reports arm64; canonical output matters | ✓ Good — all downstream code uses arm64 |
| DRY_RUN support via exported env var (not flag parsing) | No flag parsing in lib files | ✓ Good — consistent with lib design |
| DOTFILES_REPO uses placeholder | User must replace before publishing | — Pre-publish action required |
| gitleaks protect --staged --redact | Pinned version controls behavior of deprecated-but-functional flag | ✓ Good — works at v8.30.0 |
| diff -q for hook idempotency | Outdated hooks updated on re-run | ✓ Good — self-healing pre-commit |
| ZSH_THEME="" (empty string) | Named theme conflicts with starship dual-prompt | ✓ Good — starship renders cleanly |
| eval "$(starship init zsh)" last in .zshrc | oh-my-zsh resets $PROMPT if starship init precedes it | ✓ Good — correct render order |
| usermod -s for shell change (not chsh) | chsh has PAM issues on RPi OS Bookworm from root scripts | ✓ Good — works on both Ubuntu and RPi |
| _try_install soft-fail wrapper for CLI tools | One tool failure doesn't abort all remaining installs | ✓ Good — resilient bootstrap |
| Docker via official apt repo (not get.docker.com) | get.docker.com has hardcoded sleep 20 on re-run | ✓ Good — idempotent installs |
| raspbian maps to debian Docker repo | download.docker.com/linux/raspbian has no binary-arm64/ | ✓ Good — RPi installs work |
| docker run hello-world not in bootstrap | Group membership needs re-login; newgrp creates subshell breaking set -e | ✓ Good — verify.sh handles post-login checks |
| lazydocker flat archive (no subdirectory) | Binary at root of tar.gz; install -m 755 directly from tmpdir | ✓ Good — correct extraction pattern |
| verify.sh sources lib/versions.sh | Stays in sync when versions updated; no hardcoded strings | ✓ Good — single source of truth |
| _already_installed uses [[ -f ]] not [[ -x ]] | Binary presence check (not executability check) | ✓ Good — consistent with pattern |
| _already_installed in install-shell.sh (not lib/) | Install-script-internal helper; not a reusable library primitive | ✓ Good — correct placement |

---
*Last updated: 2026-02-23 after v1.0 milestone*
