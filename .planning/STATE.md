# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-22)

**Core value:** One command turns a bare Ubuntu/RPi server into a fully-configured, familiar environment — no manual steps.
**Current focus:** Phase 3 - CLI Tools and Docker

## Current Position

Phase: 3 of 4 (CLI Tools and Docker)
Plan: 2 of 3 in current phase
Status: In progress
Last activity: 2026-02-22 — Completed 03-02 (scripts/install-tools.sh with seven CLI tool installers)

Progress: [████████░░] 58%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: 1.5 min
- Total execution time: 0.15 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 4 min | 1.3 min |
| 02-shell-environment-and-config-deployment | 2 | 8 min | 4 min |
| 03-cli-tools-and-docker | 2 | 2 min | 1 min |

**Recent Trend:**
- Last 5 plans: 01-03 (1 min), 02-01 (5 min), 02-02 (3 min), 03-01 (1 min), 03-02 (1 min)
- Trend: establishing baseline

*Updated after each plan completion*
| Phase 01-foundation P01 | 2 | 2 tasks | 6 files |
| Phase 01-foundation P02 | 1 | 1 task | 1 file |
| Phase 01-foundation P03 | 1 | 2 tasks | 2 files |
| Phase 02-shell P01 | 2 | 2 tasks | 4 files |
| Phase 02-shell P02 | 3 | 2 tasks | 2 files |
| Phase 03-cli P01 | 1 | 2 tasks | 2 files |
| Phase 03-cli P02 | 1 | 1 task | 1 file |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Setup]: Pure bash + GNU Stow chosen over chezmoi/Ansible — zero bootstrapping dependency, simpler for single-user homelab
- [Setup]: apt + direct GitHub Releases binary downloads chosen over Homebrew — inconsistent ARM support on RPi
- [Setup]: Secrets via env vars at runtime only — public repo, zero secrets in version control
- [01-01]: tee redirection belongs in bootstrap.sh entrypoint, not in log.sh — lib files only define functions
- [01-01]: os_detect_arch normalizes both aarch64 (Linux) and arm64 (macOS) to canonical arm64 output
- [01-01]: DRY_RUN support added to pkg_install via exported env var — no flag parsing in lib files
- [01-02]: DOTFILES_REPO uses <YOUR_GITHUB_USER> placeholder — user must replace before publishing
- [01-02]: trap cleanup EXIT (not ERR) — cleanup checks $? to distinguish success from failure
- [01-02]: Manifest entry format is type:payload (file:, hook:, symlink:) — future phase scripts append lines in this format
- [01-02]: _SUMMARY_INSTALLED/SKIPPED/WARNINGS are global bash arrays — phase scripts append to accumulate summary
- [01-03]: gitleaks protect --staged --redact used (deprecated since v8.19.0 but functional in v8.30.0; pinned version controls surprises)
- [01-03]: gitleaks git --source used for history scan (not deprecated gitleaks detect)
- [01-03]: trap RETURN pattern used inside install_gitleaks() for tmpdir cleanup
- [01-03]: diff -q used for hook idempotency — ensures outdated hooks get updated on re-run
- [02-01]: ZSH_THEME must be empty string — named theme causes dual-prompt conflict with starship
- [02-01]: eval "$(starship init zsh)" must be the last executable line — oh-my-zsh resets $PROMPT if placed before source oh-my-zsh.sh
- [02-01]: Double quotes required around $(starship init zsh) since starship v1.17.0
- [02-01]: ssh_only = false in starship.toml — always show hostname on servers, not just over SSH
- [02-01]: .zsh_aliases references Phase 3 binaries (eza, bat, rg) — safe, zsh resolves at invocation time not source time
- [02-01]: Plain "git:" text used for git_branch symbol — no Nerd Font required on headless servers
- [02-02]: oh-my-zsh install uses directory pre-check guard (! -d ~/.oh-my-zsh) — official installer exits 1 if dir exists; locked decision to re-run is incorrect
- [02-02]: usermod -s used for shell change (not chsh) — chsh has PAM issues on RPi OS Bookworm when run from root scripts
- [02-02]: KEEP_ZSHRC=yes passed to oh-my-zsh installer — prevents installer from overwriting .zshrc before deploy_dotfiles creates the symlink
- [02-02]: install order is zsh -> oh-my-zsh -> plugins -> starship -> tmux -> deploy_dotfiles — oh-my-zsh must precede plugin clones
- [02-02]: starship.toml symlink target is ~/.config/starship.toml — mkdir -p ~/.config required on minimal servers
- [03-01]: lib/versions.sh variables NOT exported — sourcing scripts assign as globals/locals as needed (matches existing lib/ convention)
- [03-01]: GITLEAKS_INSTALL_PATH kept as module-level var in install-gitleaks.sh — only GITLEAKS_VERSION was removed (path is not a version concern)
- [03-01]: lib/versions.sh idempotency guard pattern (_LIB_VERSIONS_LOADED) matches lib/log.sh and lib/os.sh convention
- [03-02]: _try_install soft-fail wrapper chosen — one tool download failure does not abort all remaining installs (bootstrap.sh has set -eEuo pipefail)
- [03-02]: ripgrep/fd/bat/delta use separate libc case (musl for x86_64, gnu for arm64) — not in _arch_for_tool since libc varies per arch
- [03-02]: delta URL uses no 'v' prefix: ${version} not v${version} — unique among seven tools

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 3]: delta 0.18.2 aarch64-unknown-linux-gnu.tar.gz confirmed present on GitHub Releases (low risk for Bookworm glibc 2.35+)
- [Phase 3 RESOLVED]: Neovim ARM64 install method confirmed — use tarball (nvim-linux-arm64.tar.gz), not AppImage (avoids FUSE dependency)
- [Phase 4]: Confirm sshd service name on RPi OS Bookworm — may be `ssh` not `sshd`
- [Phase 4]: Verify UFW sequence on Ubuntu 24.04 fresh install

## Session Continuity

Last session: 2026-02-22
Stopped at: Completed 03-02-PLAN.md (scripts/install-tools.sh with seven CLI tool installers)
Resume file: None
