# Server Dotfiles

## What This Is

A one-command bootstrap system for fresh Ubuntu and Raspberry Pi servers. Run a single curl command on a new machine and walk away — it installs your preferred shell environment (zsh + oh-my-zsh + starship + tmux), modern CLI tools (ripgrep, fzf, fd, eza, bat, delta, neovim), Docker/Compose, and SSH hardening. Shell configs are shared with macOS so servers feel immediately familiar.

Built for personal VPS and homelab use. Multiple servers get identical configs.

## Core Value

One command turns a bare Ubuntu/RPi server into a fully-configured, familiar environment — no manual steps.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Bootstrap script runs via `curl | bash` on a fresh server
- [ ] Installs zsh, oh-my-zsh, starship, and tmux
- [ ] Installs modern CLI tools: ripgrep, fzf, fd, eza, bat, delta, neovim
- [ ] Deploys shell configs (.zshrc, aliases, tmux.conf, starship.toml) compatible with macOS
- [ ] Installs Docker and Docker Compose
- [ ] SSH hardening: disables password auth, configures sshd
- [ ] SSH key deployment: installs user's public key
- [ ] Secrets fetched at bootstrap time (env vars / password manager), never stored in repo
- [ ] Works on Ubuntu (x86_64) and Raspberry Pi (ARM)
- [ ] Idempotent: safe to run multiple times on the same server

### Out of Scope

- macOS bootstrap — macOS is already managed separately
- Multiple server roles with different configs — all servers get same setup
- Secrets stored in repo — always fetched at runtime

## Context

- Target OS: Ubuntu LTS + Raspberry Pi OS (both Debian-based, but different architectures)
- Shell stack on macOS: zsh + oh-my-zsh + starship + tmux — servers should feel identical
- Tools on macOS installed via Homebrew; Linux will use apt + direct binary downloads
- Public GitHub repo — no sensitive data can be committed
- Secrets strategy: pass via environment variables or pull from password manager CLI at bootstrap time

## Constraints

- **Architecture**: Must support both x86_64 (Ubuntu VPS) and ARM (Raspberry Pi) — some tools need different install paths
- **Public repo**: Zero secrets in version control — all sensitive values fetched at runtime
- **Idempotency**: Bootstrap script must be safe to re-run (config updates, not just fresh installs)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Secrets fetched at bootstrap time | Public repo, can't commit keys/tokens | — Pending |
| apt + binary downloads over Homebrew for Linux | Homebrew ARM support on RPi is inconsistent | — Pending |
| Single config profile (no roles) | All servers get same setup, simpler to maintain | — Pending |

---
*Last updated: 2026-02-22 after initialization*
