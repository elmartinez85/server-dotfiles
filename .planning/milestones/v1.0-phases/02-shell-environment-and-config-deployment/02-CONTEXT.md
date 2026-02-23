# Phase 2: Shell Environment and Config Deployment - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Install zsh + oh-my-zsh + starship + tmux + zsh plugins on a fresh Linux server, then deploy
four config files as symlinks from the cloned repo into $HOME. After this phase runs, the server
shell feels familiar (same aliases, same tools, same starship prompt as macOS) but all scripts
are Linux-only — no macOS conditionals or cross-platform compatibility required.

</domain>

<decisions>
## Implementation Decisions

### Config repo structure
- Dotfiles live in a `dotfiles/` subfolder at the repo root
- Four files only: `.zshrc`, `.zsh_aliases`, `.tmux.conf`, `starship.toml`
- Symlinks are created at `$HOME/<filename>` pointing into `<repo>/dotfiles/<filename>`
- The aliases file is named `.zsh_aliases` (symlinked to `$HOME/.zsh_aliases`, sourced from `.zshrc`)

### Plugin installation source
- **oh-my-zsh**: official install script with `RUNZSH=no CHSH=no` env vars (unattended, no shell switch mid-script)
- **zsh-autosuggestions** and **zsh-syntax-highlighting**: git clone into `~/.oh-my-zsh/custom/plugins/`, listed in `plugins=()` in `.zshrc`
- **starship**: official install script (`starship.rs/install.sh` with `--yes` flag)
- **tmux**: `apt install tmux` via package manager

### Idempotency and re-run behavior
- **Symlinks already exist (correct)**: skip with a log message — no re-linking
- **Backup collision** (`~/.dotfiles.bak/` already has the file): timestamp the new backup (e.g., `.zshrc.2026-02-22`) so nothing is ever lost
- **oh-my-zsh already installed** (`~/.oh-my-zsh` exists): skip the installer — the official oh-my-zsh installer exits with error code 1 when `~/.oh-my-zsh` already exists (it does NOT handle existing installs gracefully)
- **starship already installed** (binary exists): re-run the official install script anyway — idempotent by design

### Claude's Discretion
- Script architecture (single install script vs. multiple sourced scripts)
- Log formatting and verbosity (should use lib/log.sh from Phase 1)
- zsh default shell change mechanism (`chsh` vs. editing `/etc/passwd`)
- Exact starship.toml configuration content

</decisions>

<specifics>
## Specific Ideas

- The "feels like macOS" goal is about familiarity — same aliases, same prompt look, same tools — not about running identical configs on both systems
- Phase 1 provides `lib/log.sh` — Phase 2 scripts should source and use it for consistent log output

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-shell-environment-and-config-deployment*
*Context gathered: 2026-02-22*
