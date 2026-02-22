# Feature Research

**Domain:** Server dotfiles / one-command bootstrap system
**Researched:** 2026-02-22
**Confidence:** MEDIUM (ecosystem patterns verified across multiple sources; specific tool behavior HIGH confidence, anti-feature recommendations MEDIUM based on community consensus)

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any credible server bootstrap system must have. Missing one = the system isn't trustworthy or usable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Idempotent execution | Re-running on an existing server must be safe — config updates, package already-installed checks, no double-appends to files | MEDIUM | Check-before-act pattern throughout: `command -v`, `dpkg -l`, `grep -q`, `[ -d ]`. Use `-f` flag for symlinks, `-p` for mkdir. This is the single most important correctness property. |
| OS/architecture detection | x86_64 (Ubuntu VPS) and ARM (Raspberry Pi) need different binary download URLs; some apt packages behave differently | LOW | `uname -m` returns `x86_64` or `aarch64`/`armv7l`. Required before any binary download. |
| Package installation (apt) | Installs core tools: zsh, tmux, ripgrep, fzf, fd, eza, bat, delta, neovim | LOW | `apt-get install -y` with `DEBIAN_FRONTEND=noninteractive`. Check `dpkg -l` or `command -v` before installing to avoid redundant work. |
| Config file deployment | Shell configs (.zshrc, .tmux.conf, starship.toml, aliases) must land in the right locations | LOW | Symlink preferred over copy — enables `git pull` + re-run to instantly propagate changes without re-running full bootstrap. |
| Docker + Docker Compose install | Expected on any modern server bootstrap — containers are standard | MEDIUM | Official Docker install method (`get.docker.com` convenience script or apt repository) handles ARM and x86_64 automatically. Must add user to `docker` group. Compose v2 is a Docker plugin now, not standalone binary. |
| SSH key deployment | Bootstrap must install the operator's public key into `~/.ssh/authorized_keys` | LOW | Create `~/.ssh/` with mode 700, `authorized_keys` with mode 600. Key value passed as env var or fetched from remote at bootstrap time — never stored in repo. |
| SSH hardening (sshd_config) | Disable password auth, disable root login, set strong ciphers | MEDIUM | Edit `/etc/ssh/sshd_config`. Validate with `sshd -t` before reloading. Restart `sshd` after. Required before exposing server to internet. Failure to validate = locked out. |
| Zero secrets in repo | Public repo — any credential in git history is permanently compromised | LOW | Secrets passed as env vars (`SSH_PUBLIC_KEY=...`) or fetched via password manager CLI (Bitwarden, 1Password) at bootstrap time. Never written to disk or repo. |
| Zsh as default shell | Target user expects zsh — `chsh -s $(which zsh)` required | LOW | Requires zsh installed first. Shell change takes effect on next login, not immediately. |
| oh-my-zsh install | Standard plugin/theme framework — expected alongside zsh | LOW | Install via official script. Must be idempotent: skip if `~/.oh-my-zsh` already exists. |
| Starship prompt | Cross-shell prompt installed via official binary installer | LOW | Architecture-aware installer handles ARM/x86. Must be idempotent: skip if `starship` already in PATH. |
| Meaningful progress output | Operator needs to know what's happening — silent bootstrap = opaque failure | LOW | `echo` status messages with clear section headers. On failure, show what failed. Do not suppress all output. |
| Error handling / fail fast | A failed step must stop the script — silent partial installs are dangerous | LOW | `set -euo pipefail` at top of every script. Check exit codes explicitly for critical steps (sshd restart, key deploy). |

### Differentiators (Competitive Advantage)

Features that make this bootstrap system great rather than just functional.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Update workflow (git pull + re-run) | Keeping configs in sync across servers is the hardest ongoing maintenance problem — idempotency enables `git pull && ./bootstrap.sh` as the update mechanism | LOW | The symlink approach makes this free: symlinks already point to repo, so `git pull` updates configs instantly. Re-run bootstrap to install any new tools. |
| Symlink strategy for configs | Symlinks (not copies) mean `git pull` propagates config changes without re-running bootstrap | LOW | Preferred over copying because edits to `~/.zshrc` are actually edits to the repo file. No drift between deployed and versioned configs. |
| Backup of pre-existing configs | When deploying to a server that already has dotfiles, back up originals before symlinking | LOW | Move existing files to `~/.dotfiles.bak/` with timestamp. Prevents data loss. Simple `mv` before `ln -sf`. |
| Fail2ban install | Brute-force protection for SSH — considered mandatory for internet-facing servers by security community | LOW | Install `fail2ban`, enable with `systemctl enable --now fail2ban`. Default config jails SSH automatically. Add UFW integration for port-scan detection (moderate complexity). |
| UFW firewall setup | Default-deny inbound with explicit allow for SSH port — defense in depth beyond sshd_config | LOW | `ufw default deny incoming`, `ufw allow ssh`, `ufw --force enable`. Straightforward but must allow SSH before enabling or will self-lock. |
| Non-interactive bootstrap (no prompts) | Piped via `curl | bash` — stdin is not a terminal, prompts break execution | MEDIUM | All configuration via env vars. Test with `bash -s` from file to catch interactive prompt regressions. This is the most common `curl | bash` failure mode. |
| Modular script structure | Individual modules (shell, docker, ssh) can be run independently for partial updates | MEDIUM | e.g., `./modules/docker.sh` runs only Docker install. Useful for updating one component without full re-bootstrap. Requires each module to be self-contained and idempotent. |
| macOS config compatibility | Server configs are the same files used on macOS — no mental context switching | LOW | zsh aliases, tmux.conf, starship.toml work cross-platform. Small number of OS-specific branches in .zshrc (e.g., `if [[ "$(uname)" == "Linux" ]]`). |
| Logging to file | Bootstrap output captured to `/var/log/bootstrap.log` alongside terminal output | LOW | `tee /var/log/bootstrap.log`. Useful for post-mortem if something fails after the session closes. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem attractive but introduce complexity that exceeds their value for this use case.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Multiple server roles / profiles | "Some servers need Docker, some don't" | Adds a role selection system, conditional logic throughout every module, and test matrix explosion. This project explicitly scopes to one config for all servers. | Keep one config. If a server genuinely needs less, just don't run the Docker module. Single-config simplicity is the stated goal. |
| Rollback / undo capability | "What if the bootstrap breaks something?" | True rollback requires snapshotting state before every change — filesystem snapshots (Timeshift/ZFS) or per-file backups. A bootstrap script is not the right layer for this. | Backup pre-existing dotfiles to `~/.dotfiles.bak/` before symlinking (cheap insurance). For system-level rollback, use OS snapshots (DigitalOcean Droplet snapshots, Timeshift). The bootstrap itself is idempotent — re-run to fix. |
| Ansible / configuration management framework | "Proper infrastructure automation should use Ansible" | Massive dependency for a personal homelab tool. Requires Python, inventory files, playbook structure, vault for secrets. The problem is solvable with well-written bash. | Well-structured idempotent bash scripts achieve the same outcome with zero external dependencies. Only migrate to Ansible when managing 10+ servers with divergent configs. |
| Interactive menu / wizard | "Let me choose what to install" | Breaks `curl | bash` pattern — stdin is connected to curl output, not terminal. Interactive prompts silently hang or fail. | Drive all choices via environment variables set before running the bootstrap. |
| Auto-update daemon / cron job | "Servers should stay up-to-date automatically" | Unattended git pulls and config changes on production servers is risky — a bad commit updates all servers at once. | Manual update workflow: `git pull && ./bootstrap.sh`. Explicit and auditable. |
| Secrets stored in encrypted files in repo | "It would be convenient to keep secrets in the repo" | Encrypted secrets in git (git-crypt, ansible-vault) have key management overhead and historical exposure risk. `git log --all` of a public repo is permanent. | Secrets fetched at bootstrap time from password manager CLI (Bitwarden `bw`, 1Password `op`) or passed as env vars. Nothing sensitive ever touches the repo. |
| Dotfile manager tool (chezmoi, yadm, dotbot) | "Use a proper dotfiles manager instead of scripts" | Adds a dependency that must be installed before dotfiles can be deployed (bootstrapping problem). Also complicates the `curl | bash` entry point. | A well-structured git repo + symlinks + a short idempotent bash installer is simpler, has no external dependencies, and is fully transparent. |
| Windows/WSL support | "Might be useful someday" | Completely different toolchain, package manager, and filesystem semantics. The project targets Ubuntu + Raspberry Pi — adding WSL doubles test surface. | Out of scope. macOS is already managed separately. |

## Feature Dependencies

```
[OS/Architecture Detection]
    └──required by──> [Package Installation (apt)]
    └──required by──> [Binary Downloads (starship, modern CLI tools)]
    └──required by──> [Docker Install]

[Package Installation (apt)]
    └──required by──> [Zsh Install]
                          └──required by──> [oh-my-zsh Install]
                                               └──required by──> [Starship Install]
                                               └──required by──> [Config Deployment (.zshrc, aliases)]

[SSH Key Deployment]
    └──required before──> [SSH Hardening (disable password auth)]
    (hardening without a deployed key = permanent lockout)

[SSH Hardening (sshd -t validation)]
    └──required before──> [sshd restart]

[Docker Install]
    └──requires──> [User added to docker group]

[Config Deployment]
    └──enhances──> [Update Workflow]
    (symlinks make git pull instantly propagate changes)

[Backup of pre-existing configs]
    └──required before──> [Config Deployment]
    (prevents data loss when re-deploying to configured server)

[Fail2ban]
    └──enhances──> [SSH Hardening]
    (defense in depth)

[UFW Firewall]
    └──requires──> [SSH allow rule set BEFORE ufw enable]
    (self-lockout risk)
    └──enhances──> [SSH Hardening]
    └──enhances──> [Fail2ban]
```

### Dependency Notes

- **SSH Key Deployment must precede SSH Hardening:** Disabling password auth before the operator's key is in `authorized_keys` = permanent lockout. This ordering is non-negotiable.
- **sshd -t validation must precede sshd restart:** A malformed sshd_config that silently fails until the next restart is a classic lockout vector.
- **UFW allow SSH before ufw enable:** `ufw --force enable` activates immediately. If SSH isn't in the allow list, the session drops.
- **Backup before symlink:** Running bootstrap on a server with existing dotfiles will overwrite them silently if backup step is skipped.
- **Architecture detection before binary downloads:** Starship, fd, ripgrep, bat, eza, delta — all provide separate ARM and x86_64 binaries. Wrong architecture = silent install of non-functional binary.

## MVP Definition

### Launch With (v1)

Minimum viable: one command turns a bare server into a familiar, secure environment.

- [ ] Idempotent bash entry point (`bootstrap.sh`) with `set -euo pipefail` and progress output
- [ ] OS/architecture detection (`uname -m`)
- [ ] apt package install: zsh, tmux, ripgrep, fzf, fd-find, bat, neovim, git, curl, wget
- [ ] Starship prompt install (architecture-aware binary installer)
- [ ] oh-my-zsh install (idempotent: skip if `~/.oh-my-zsh` exists)
- [ ] Config deployment via symlinks: `.zshrc`, `aliases.zsh`, `.tmux.conf`, `starship.toml`
- [ ] Backup pre-existing configs to `~/.dotfiles.bak/`
- [ ] Docker + Docker Compose install (official apt repository method, handles ARM/x86)
- [ ] User added to `docker` group
- [ ] SSH public key deployment to `~/.ssh/authorized_keys` (key value from env var)
- [ ] SSH hardening: disable password auth, disable root login, validate with `sshd -t`, restart sshd
- [ ] Zero secrets in repo — all sensitive values via env vars

### Add After Validation (v1.x)

- [ ] Fail2ban install + enable — add once base bootstrap is confirmed working; brute-force protection matters for internet-facing servers
- [ ] UFW firewall setup — add alongside fail2ban; both are security layers that belong together
- [ ] Modular structure (separate scripts per concern) — add when the monolithic bootstrap exceeds ~200 lines and becomes hard to maintain
- [ ] `eza`, `bat`, `delta` installs — modern CLI tool replacements; defer if apt versions aren't available on ARM, handle binary fallback
- [ ] Logging to `/var/log/bootstrap.log` — useful for debugging, but not blocking

### Future Consideration (v2+)

- [ ] neovim config deployment — neovim itself is table stakes, but a full `init.lua` config is a separate concern with its own plugin install step; defer until shell env is stable
- [ ] Secrets fetched from Bitwarden/1Password CLI — more ergonomic than env vars for multi-server setups; adds CLI dependency at bootstrap time; validate simpler env-var approach first
- [ ] `git clone` of dotfiles repo inside bootstrap — enables pure `curl | bash` with no pre-staged repo; adds complexity (git auth for private repo); validate public repo workflow first

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Idempotent execution | HIGH | MEDIUM | P1 |
| OS/architecture detection | HIGH | LOW | P1 |
| apt package install | HIGH | LOW | P1 |
| Zsh + oh-my-zsh + starship | HIGH | LOW | P1 |
| Config symlinks | HIGH | LOW | P1 |
| Docker + Compose | HIGH | MEDIUM | P1 |
| SSH key deployment | HIGH | LOW | P1 |
| SSH hardening (sshd_config) | HIGH | MEDIUM | P1 |
| Backup pre-existing configs | HIGH | LOW | P1 |
| Error handling (set -euo pipefail) | HIGH | LOW | P1 |
| Fail2ban | HIGH | LOW | P2 |
| UFW firewall | HIGH | LOW | P2 |
| Modular script structure | MEDIUM | MEDIUM | P2 |
| Logging to file | MEDIUM | LOW | P2 |
| eza/bat/delta modern CLI tools | MEDIUM | MEDIUM | P2 |
| neovim config | MEDIUM | HIGH | P3 |
| Secrets from password manager CLI | MEDIUM | MEDIUM | P3 |
| Multiple server roles | LOW | HIGH | Anti-feature |
| Rollback / undo | LOW | HIGH | Anti-feature |
| Ansible migration | LOW | HIGH | Anti-feature |
| Interactive wizard | LOW | HIGH | Anti-feature |

## Competitor Feature Analysis

| Feature | chezmoi | yadm | holman/dotfiles (bash) | This Project |
|---------|---------|------|----------------------|--------------|
| Idempotency | Via tool design | Via git checkout | Manual, per-script | Manual, `set -euo pipefail` + check-before-act |
| Architecture detection | N/A (manages configs only) | N/A | N/A | `uname -m` — essential for binary downloads |
| Package installation | External (Brewfile, apt script) | External script | Per-topic `.sh` files | Single apt block + binary installers |
| Config deployment | Template engine + `chezmoi apply` | Git checkout to `$HOME` | Symlinks via Ruby script | Direct `ln -sf` |
| Secrets management | 1Password/Bitwarden CLI integration | `git-crypt` encryption | Not handled | Env vars at bootstrap time |
| SSH hardening | Not included | Not included | Not included | Core feature — sshd_config + key deployment |
| Docker install | Not included | Not included | Not included | Core feature |
| Update workflow | `chezmoi update` (pull + apply) | `yadm pull` | `git pull` + re-run bootstrap | `git pull` + re-run `bootstrap.sh` |
| Bootstrap dependency | Requires chezmoi installed | Requires yadm installed | Requires Ruby | Requires only bash + curl/git |
| `curl \| bash` compatible | No (interactive setup) | No (interactive setup) | No | Yes — non-interactive design |

**Key observation:** Existing tools (chezmoi, yadm) solve the config-sync problem elegantly but are not designed for the server bootstrap use case — they require themselves to be installed first (bootstrapping problem), and they don't include package installation, Docker, or SSH hardening. A purpose-built bash script for this use case is the right approach and avoids all tool-as-dependency problems.

## Sources

- [dotfiles.github.io Bootstrap Repositories](https://dotfiles.github.io/bootstrap/) — community catalog of bootstrap approaches
- [chezmoi Comparison Table](https://www.chezmoi.io/comparison-table/) — feature matrix across dotfile managers (HIGH confidence — official docs)
- [How to write idempotent Bash scripts — arslan.io](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — idempotency techniques (MEDIUM confidence — widely cited, multiple HN threads agree)
- [The Dangers of curl | bash — lukespademan.com](https://lukespademan.com/blog/the-dangers-of-curlbash/) — stdin/prompt failure in piped execution
- [SSH Hardening Guides — sshaudit.com](https://www.sshaudit.com/hardening_guides.html) — current sshd_config recommendations (MEDIUM confidence — well-maintained, updated 2025)
- [How To Harden OpenSSH on Ubuntu — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-harden-openssh-on-ubuntu-20-04) — practical hardening steps
- [Docker on Raspberry Pi OS — Official Docs](https://docs.docker.com/engine/install/raspberry-pi-os/) — ARM Docker install (HIGH confidence — official)
- [How To Protect SSH with Fail2Ban on Ubuntu — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-ubuntu-20-04) — fail2ban setup
- [symlink dotfiles — Arch Wiki](https://wiki.archlinux.org/title/Dotfiles) — symlink vs copy patterns
- [Why use chezmoi? — chezmoi official](https://www.chezmoi.io/why-use-chezmoi/) — framing of dotfile management problems

---
*Feature research for: server dotfiles / one-command bootstrap (Ubuntu + Raspberry Pi)*
*Researched: 2026-02-22*
