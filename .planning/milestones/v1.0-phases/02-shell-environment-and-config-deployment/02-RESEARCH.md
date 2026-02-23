# Phase 2: Shell Environment and Config Deployment - Research

**Researched:** 2026-02-22
**Domain:** zsh, oh-my-zsh, starship, tmux, zsh plugins, symlink-based dotfile deployment
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Config repo structure:** Dotfiles live in a `dotfiles/` subfolder at the repo root. Four files only: `.zshrc`, `.zsh_aliases`, `.tmux.conf`, `starship.toml`. Symlinks are created at `$HOME/<filename>` pointing into `<repo>/dotfiles/<filename>`. The aliases file is named `.zsh_aliases` (symlinked to `$HOME/.zsh_aliases`, sourced from `.zshrc`).
- **oh-my-zsh install:** Official install script with `RUNZSH=no CHSH=no` env vars (unattended, no shell switch mid-script).
- **Plugins:** `zsh-autosuggestions` and `zsh-syntax-highlighting` — git clone into `~/.oh-my-zsh/custom/plugins/`, listed in `plugins=()` in `.zshrc`.
- **starship:** Official install script (`starship.rs/install.sh` with `--yes` flag).
- **tmux:** `apt install tmux` via package manager.
- **Idempotency — symlinks already exist (correct):** Skip with a log message — no re-linking.
- **Idempotency — backup collision (`~/.dotfiles.bak/` already has the file):** Timestamp the new backup (e.g., `.zshrc.2026-02-22`) so nothing is ever lost.
- **Idempotency — oh-my-zsh already installed (`~/.oh-my-zsh` exists):** Re-run the official install script anyway — it handles existing installs gracefully.
- **Idempotency — starship already installed (binary exists):** Re-run the official install script anyway — idempotent by design.

### Claude's Discretion

- Script architecture (single install script vs. multiple sourced scripts)
- Log formatting and verbosity (should use lib/log.sh from Phase 1)
- zsh default shell change mechanism (`chsh` vs. editing `/etc/passwd`)
- Exact starship.toml configuration content

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SHELL-01 | User has zsh installed and set as the default shell after bootstrap | `pkg_install zsh` via lib/pkg.sh; `usermod -s $(which zsh) $TARGET_USER` for shell change; `/etc/shells` must list zsh path before chsh can work |
| SHELL-02 | User has oh-my-zsh installed via unattended install (no interactive prompts) | Official install script with `RUNZSH=no CHSH=no`; guard with `[ ! -d ~/.oh-my-zsh ]` because the installer **exits with error** if dir already exists (see Critical Pitfall #1) |
| SHELL-03 | User has starship prompt installed and active in zsh | Official install script with `-y` flag; `eval "$(starship init zsh)"` must be last line of `.zshrc` |
| SHELL-04 | User has tmux installed | `pkg_install tmux` — straightforward apt package |
| SHELL-05 | User has zsh-autosuggestions plugin active | `git clone --depth 1` into `${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions`; guard with `[ ! -d ... ]` |
| SHELL-06 | User has zsh-syntax-highlighting plugin active | `git clone --depth 1` into `${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting`; guard with `[ ! -d ... ]` |
| CONF-01 | zsh config (.zshrc and aliases) deployed to $HOME via symlinks from repo | Backup-then-symlink pattern; `dotfiles/.zshrc` → `$HOME/.zshrc`; `dotfiles/.zsh_aliases` → `$HOME/.zsh_aliases` |
| CONF-02 | tmux config (.tmux.conf) deployed to $HOME via symlinks from repo | Same backup-then-symlink pattern; `dotfiles/.tmux.conf` → `$HOME/.tmux.conf` |
| CONF-03 | starship config (starship.toml) deployed to $HOME/.config via symlinks from repo | `mkdir -p ~/.config`; `dotfiles/starship.toml` → `$HOME/.config/starship.toml` |
| CONF-04 | Pre-existing config files backed up to ~/.dotfiles.bak/ before symlinks are created | Backup to `~/.dotfiles.bak/`; timestamp collision handling (e.g., `.zshrc.2026-02-22`) |
| CONF-05 | zsh config on servers provides a similar shell experience to macOS (same aliases, same tools, same feel) | The `.zshrc` and `.zsh_aliases` content must be authored — not installed by a tool; "feels like macOS" = same aliases + starship prompt + same plugin behavior |
</phase_requirements>

---

## Summary

Phase 2 has two distinct problems: (1) installing the shell stack (zsh, oh-my-zsh, starship, tmux, two plugins), and (2) deploying four config files as symlinks from the repo. Both are well-understood tasks with clear, lightweight bash solutions.

The installation side requires careful idempotency logic. The most important finding is a **direct contradiction between the user's locked decision and reality for oh-my-zsh**: the user decided that re-running the official oh-my-zsh installer is safe because "it handles existing installs gracefully" — but it does not. The official `install.sh` explicitly exits with error code 1 when `~/.oh-my-zsh` already exists. The correct idempotency guard is a pre-check: `if [ ! -d ~/.oh-my-zsh ]` — only run the installer if the directory is absent. This is the community-standard pattern and must override the locked decision. The planner must handle this discrepancy.

The symlink deployment side is a straightforward backup-then-link sequence. The key pitfalls are backup collision handling (already addressed in locked decisions with timestamp suffixes) and the different target location for `starship.toml` (`$HOME/.config/` vs `$HOME/` for the other three files). The `dotfiles/` directory needs to be created in the repo — it does not exist yet.

**Primary recommendation:** Script architecture should follow the Phase 1 pattern: a single `scripts/install-shell.sh` sourced by `bootstrap.sh`, exporting three or four functions (`install_zsh_stack`, `deploy_dotfiles`, etc.). Use `lib/log.sh` and `lib/pkg.sh` from Phase 1 as-is. The starship installer's `-y` flag is confirmed. The oh-my-zsh installer requires a directory pre-check guard — do not re-run the installer when `~/.oh-my-zsh` exists.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| zsh | system apt (5.8+ on Ubuntu 22.04) | Shell interpreter | Required for oh-my-zsh and all plugins |
| oh-my-zsh | latest (no pin — official install script fetches master) | Plugin and theme management framework | De-facto standard zsh framework; manages plugin paths automatically |
| starship | latest via official install script | Cross-shell prompt | Single binary, fast, TOML config, ARM64-native |
| tmux | system apt (3.x on Ubuntu 22.04) | Terminal multiplexer | Standard apt package, no version complexity |
| zsh-autosuggestions | latest HEAD (shallow clone) | Fish-like command suggestions | Official oh-my-zsh custom plugin; git-cloned into ZSH_CUSTOM |
| zsh-syntax-highlighting | latest HEAD (shallow clone) | Fish-like syntax coloring | Official oh-my-zsh custom plugin; git-cloned into ZSH_CUSTOM |

### Supporting

| Tool/Pattern | Version | Purpose | When to Use |
|---|---|---|---|
| `ln -sfn` | coreutils | Idempotent symlink creation | Always; `-f` force-replaces, `-n` prevents linking into a directory if target is already a dir symlink |
| `mkdir -p` | coreutils | Idempotent directory creation | `~/.dotfiles.bak/`, `~/.config/` |
| `usermod -s` | shadow-utils | Change login shell non-interactively | Preferred over `chsh` for root-run scripts; no PAM prompt issues |
| `date +%Y-%m-%d` | coreutils | Timestamp suffix for backup collisions | Used when `~/.dotfiles.bak/<file>` already exists |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Official oh-my-zsh install script | `git clone` directly to `~/.oh-my-zsh` | Direct clone skips the template `.zshrc` generation; acceptable if `.zshrc` is fully managed by the repo |
| Official starship install script | GitHub Releases binary download | Direct download gives version pinning; install script always fetches latest — but since user chose install script, use it |
| `usermod -s` | `chsh -s $(which zsh) $USER` | `chsh` may prompt for PAM auth even as root on some RPi OS variants; `usermod` directly modifies `/etc/passwd` and never prompts |
| `chsh` | editing `/etc/passwd` directly | Direct edit is fragile; `usermod` or `chsh` are the correct tools |
| oh-my-zsh for plugin management | Manual `source` of plugin files | oh-my-zsh handles plugin load order, completion setup, and PATH; manual sourcing is error-prone |

---

## Architecture Patterns

### Recommended Project Structure (after Phase 2)

```
bootstrap.sh                   # Entrypoint (exists)
lib/
├── log.sh                     # (exists)
├── os.sh                      # (exists)
└── pkg.sh                     # (exists)
scripts/
├── install-gitleaks.sh        # (exists — Phase 1)
└── install-shell.sh           # NEW — Phase 2
dotfiles/                      # NEW — created in Phase 2
├── .zshrc                     # NEW — zsh config (sources .zsh_aliases, inits starship)
├── .zsh_aliases               # NEW — aliases shared with macOS feel
├── .tmux.conf                 # NEW — tmux config
└── starship.toml              # NEW — starship prompt config
```

Note: The `config/` directory at repo root exists (from Phase 1) but has only a `.gitkeep`. The `dotfiles/` subdirectory is distinct from `config/` and needs to be created as a new directory.

### Pattern 1: install-shell.sh Structure (follows Phase 1 pattern)

**What:** Single script sourced by `bootstrap.sh`, providing named functions. Follows the Phase 1 `install-gitleaks.sh` pattern exactly.
**When to use:** Always — consistent with Phase 1 architecture.

```bash
#!/usr/bin/env bash
# scripts/install-shell.sh
# Sourced by bootstrap.sh — provides install_zsh, install_ohmyzsh, install_starship,
# install_tmux, install_zsh_plugins, deploy_dotfiles
if [[ -n "${_SCRIPT_INSTALL_SHELL_LOADED:-}" ]]; then return 0; fi
_SCRIPT_INSTALL_SHELL_LOADED=1
```

Functions exposed:
- `install_zsh` — apt install + set default shell
- `install_ohmyzsh` — guarded install (skip if `~/.oh-my-zsh` exists)
- `install_starship` — `curl | sh -s -- -y`
- `install_tmux` — `pkg_install tmux`
- `install_zsh_plugins` — git clone for both plugins with directory guards
- `deploy_dotfiles` — backup-then-symlink for all four config files

### Pattern 2: oh-my-zsh Install with Correct Idempotency Guard

**What:** The official oh-my-zsh installer exits with error if `~/.oh-my-zsh` already exists. The correct guard is a directory pre-check.
**When to use:** Required — replaces the locked decision's assumption.

```bash
install_ohmyzsh() {
  log_step "Checking oh-my-zsh..."

  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh already installed (~/.oh-my-zsh exists) — skipping"
    _SUMMARY_SKIPPED+=("oh-my-zsh")
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install oh-my-zsh via official install script"
    return 0
  fi

  log_step "Installing oh-my-zsh (unattended)..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  log_success "oh-my-zsh installed"
  echo "file:${HOME}/.oh-my-zsh" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("oh-my-zsh")
}
```

`KEEP_ZSHRC=yes` is used because the repo's own `.zshrc` will be deployed as a symlink immediately after — the oh-my-zsh installer must not overwrite it.

### Pattern 3: Starship Install

**What:** Official install script with `-y` flag. Binary lands at `/usr/local/bin/starship` by default.
**Idempotency note:** The official script is idempotent when re-run — it overwrites the existing binary. The user's locked decision to "re-run anyway" is correct for starship.

```bash
install_starship() {
  log_step "Installing starship..."

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install starship via official install script"
    return 0
  fi

  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

  log_success "starship installed at $(command -v starship)"
  echo "file:/usr/local/bin/starship" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("starship")
}
```

For idempotency skip: if you want to avoid re-downloading on every run, check `command -v starship` first. If found, skip and add to `_SUMMARY_SKIPPED`. The user's decision says re-run anyway, so skip the guard or make it configurable.

### Pattern 4: zsh Plugin Installation

**What:** Shallow git clone into `ZSH_CUSTOM` plugins directory. Guard with directory existence check.
**When to use:** For both `zsh-autosuggestions` and `zsh-syntax-highlighting`.

```bash
install_zsh_plugins() {
  log_step "Installing zsh plugins..."

  local plugins_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"

  # zsh-autosuggestions
  if [[ -d "${plugins_dir}/zsh-autosuggestions" ]]; then
    log_info "zsh-autosuggestions already installed — skipping"
    _SUMMARY_SKIPPED+=("zsh-autosuggestions")
  else
    git clone --depth 1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "${plugins_dir}/zsh-autosuggestions"
    echo "file:${plugins_dir}/zsh-autosuggestions" >> "$MANIFEST_FILE"
    _SUMMARY_INSTALLED+=("zsh-autosuggestions")
    log_success "zsh-autosuggestions installed"
  fi

  # zsh-syntax-highlighting
  if [[ -d "${plugins_dir}/zsh-syntax-highlighting" ]]; then
    log_info "zsh-syntax-highlighting already installed — skipping"
    _SUMMARY_SKIPPED+=("zsh-syntax-highlighting")
  else
    git clone --depth 1 \
      https://github.com/zsh-users/zsh-syntax-highlighting \
      "${plugins_dir}/zsh-syntax-highlighting"
    echo "file:${plugins_dir}/zsh-syntax-highlighting" >> "$MANIFEST_FILE"
    _SUMMARY_INSTALLED+=("zsh-syntax-highlighting")
    log_success "zsh-syntax-highlighting installed"
  fi
}
```

### Pattern 5: Backup-Then-Symlink

**What:** Before creating a symlink, check if a real file exists at the target path. If it does, back it up to `~/.dotfiles.bak/`. Then create the symlink. If a symlink already points correctly, skip.
**Note on CONF-03:** `starship.toml` target is `$HOME/.config/starship.toml`, not `$HOME/starship.toml`.

```bash
deploy_dotfiles() {
  log_step "Deploying dotfiles as symlinks..."

  local dotfiles_dir="${DOTFILES_DIR}/dotfiles"
  local backup_dir="${HOME}/.dotfiles.bak"
  mkdir -p "$backup_dir"

  _deploy_symlink "${dotfiles_dir}/.zshrc"       "${HOME}/.zshrc"
  _deploy_symlink "${dotfiles_dir}/.zsh_aliases" "${HOME}/.zsh_aliases"
  _deploy_symlink "${dotfiles_dir}/.tmux.conf"   "${HOME}/.tmux.conf"

  mkdir -p "${HOME}/.config"
  _deploy_symlink "${dotfiles_dir}/starship.toml" "${HOME}/.config/starship.toml"
}

_deploy_symlink() {
  local src="$1"
  local dst="$2"
  local filename
  filename="$(basename "$dst")"

  # Case 1: symlink already exists and points to correct source — skip
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    log_info "${filename} symlink already correct — skipping"
    _SUMMARY_SKIPPED+=("${filename} symlink")
    return 0
  fi

  # Case 2: real file exists (not a symlink) — back it up
  if [[ -f "$dst" && ! -L "$dst" ]]; then
    local backup_path="${backup_dir}/${filename}"
    # Collision handling: timestamp suffix if backup already exists
    if [[ -f "$backup_path" ]]; then
      backup_path="${backup_dir}/${filename}.$(date +%Y-%m-%d)"
    fi
    mv "$dst" "$backup_path"
    log_info "Backed up ${filename} to ${backup_path}"
    echo "file:${backup_path}" >> "$MANIFEST_FILE"
  fi

  # Case 3: broken symlink or stale symlink — remove before re-linking
  if [[ -L "$dst" ]]; then
    rm -f "$dst"
  fi

  ln -sfn "$src" "$dst"
  log_success "Symlinked: ${dst} -> ${src}"
  echo "symlink:${dst}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("${filename} symlink")
}
```

### Pattern 6: Set zsh as Default Shell

**What:** After installing zsh, change the login shell of the target user.
**Why `usermod` over `chsh`:** `usermod -s` modifies `/etc/passwd` directly and never prompts for authentication, even when called from a root-run script. `chsh` may require PAM authentication on RPi OS variants.
**Key requirement:** zsh must be listed in `/etc/shells` before any shell-change tool will accept it. `apt install zsh` typically adds it; verify with `grep zsh /etc/shells`.

```bash
install_zsh() {
  log_step "Installing zsh and setting as default shell..."
  pkg_install zsh

  # Determine target user — bootstrap runs as root, but we want the
  # default shell set for SUDO_USER (the real user who invoked sudo)
  local target_user="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
  local zsh_path
  zsh_path="$(command -v zsh)"

  # Ensure zsh is listed in /etc/shells (apt install usually handles this)
  if ! grep -q "$zsh_path" /etc/shells; then
    echo "$zsh_path" >> /etc/shells
    log_info "Added ${zsh_path} to /etc/shells"
  fi

  # Check if already the default shell
  local current_shell
  current_shell="$(getent passwd "$target_user" | cut -d: -f7)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_info "zsh already default shell for ${target_user} — skipping"
    _SUMMARY_SKIPPED+=("zsh default shell")
    return 0
  fi

  usermod -s "$zsh_path" "$target_user"
  log_success "Default shell for ${target_user} set to ${zsh_path}"
  _SUMMARY_INSTALLED+=("zsh (default shell)")
}
```

### Pattern 7: .zshrc Content Structure

**What:** The `.zshrc` must enable oh-my-zsh with plugins, source `.zsh_aliases`, and initialize starship last.
**Critical ordering:** `eval "$(starship init zsh)"` MUST be the last line — it sets `$PROMPT`. Any subsequent prompt manipulation after it would override it.

```zsh
# dotfiles/.zshrc
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME=""   # Empty — starship replaces the theme system

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# Source aliases (Linux-only; "feels like macOS" via content, not conditionals)
[[ -f "${HOME}/.zsh_aliases" ]] && source "${HOME}/.zsh_aliases"

# Initialize starship — MUST BE LAST
eval "$(starship init zsh)"
```

### Pattern 8: starship.toml — Safe Default for Servers

**What:** A minimal `starship.toml` that works on headless servers without Nerd Fonts. Starship provides a `no-nerd-font` preset that is safe for all terminals.

```bash
# Apply the no-nerd-font preset as starting config
starship preset no-nerd-font -o ~/.config/starship.toml
```

Or include the file directly in the repo. Key setting for server context:

```toml
# dotfiles/starship.toml
"$schema" = 'https://starship.rs/config-schema.json'

[hostname]
ssh_only = false    # Show hostname always, not just over SSH
style = "bold green"
format = "[$hostname]($style) "

[username]
show_always = true
style_user = "bold blue"
format = "[$user]($style)@"
```

The exact content is Claude's discretion per CONTEXT.md. The key constraint: it must not use Nerd Font symbols (servers won't have them) and should show hostname/user for server context awareness.

### Anti-Patterns to Avoid

- **Running the oh-my-zsh installer when `~/.oh-my-zsh` exists:** It exits with error code 1, breaking the bootstrap. Use a directory pre-check guard.
- **`ZSH_THEME` set to a named theme when using starship:** Will result in two prompts fighting each other. Set `ZSH_THEME=""` or omit the theme line.
- **`eval "$(starship init zsh)"` before oh-my-zsh source:** oh-my-zsh's `source` call resets prompt variables. Starship init must come after `source "$ZSH/oh-my-zsh.sh"`.
- **`ln -s` without `-f`:** Fails if symlink target already exists. Always use `ln -sfn`.
- **Hardcoded `${HOME}/.oh-my-zsh/custom` for plugins:** Should use `${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}` in case user has customized `ZSH_CUSTOM`.
- **Not running `mkdir -p ~/.config` before symlinking starship.toml:** `~/.config` may not exist on a minimal fresh server.
- **Setting default shell with `chsh` as root without checking PAM:** On RPi OS, `chsh` may prompt even as root. Use `usermod -s`.
- **Not adding zsh to `/etc/shells` before calling `usermod -s` or `chsh`:** Both tools validate that the target shell is listed in `/etc/shells`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| zsh plugin management | Manual `source` in `.zshrc` | oh-my-zsh plugin system | oh-my-zsh handles completion setup, `fpath`, and load order correctly |
| Prompt customization | Custom `PS1`/`PROMPT` in `.zshrc` | starship | PS1 construction with git status, language version display, etc. is 500+ lines of bash; starship is a compiled binary |
| Shell framework | Custom function loading | oh-my-zsh `plugins=()` array | Already deployed; plugin discovery, update mechanism, and `fpath` setup are non-trivial |
| Config backup system | Custom timestamping logic | Date-stamped file move | Simple `mv` + `date` is sufficient; no need for a rotation system |

**Key insight:** The complexity in this phase is in the sequencing and idempotency, not in the tools themselves. All the actual shell features are provided by oh-my-zsh, starship, and the two plugins — none of these should be replicated by hand.

---

## Common Pitfalls

### Pitfall 1: oh-my-zsh Installer Exits With Error if `~/.oh-my-zsh` Exists [CRITICAL]

**What goes wrong:** The locked decision states "re-run the official install script anyway — it handles existing installs gracefully." This is incorrect. The installer explicitly calls `exit 1` when `~/.oh-my-zsh` exists.
**Why it happens:** A common misunderstanding; the installer is not idempotent.
**How to avoid:** Guard with `if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then` before running the installer. This is the community-standard pattern for bootstrap scripts.
**Warning signs:** Bootstrap fails on second run with message: "The $ZSH folder already exists."
**Impact on planning:** The planner MUST use a directory pre-check guard. The locked decision's "re-run anyway" approach is not implementable and must be overridden.

### Pitfall 2: oh-my-zsh Installer Overwrites `.zshrc`

**What goes wrong:** Running the oh-my-zsh installer without `KEEP_ZSHRC=yes` will back up the existing `.zshrc` to `.zshrc.pre-oh-my-zsh` and create a new one from the oh-my-zsh template.
**Why it happens:** The installer generates a template `.zshrc` by default.
**How to avoid:** Always pass `KEEP_ZSHRC=yes` when calling the installer. Since the repo manages its own `.zshrc`, the installer must not touch it.
**Warning signs:** After bootstrap, `.zshrc` is the oh-my-zsh template instead of the repo's version.

### Pitfall 3: `eval "$(starship init zsh)"` Placement in `.zshrc`

**What goes wrong:** If starship init is called before `source "$ZSH/oh-my-zsh.sh"`, oh-my-zsh will reset the `$PROMPT` variable and starship's prompt disappears.
**Why it happens:** oh-my-zsh sources a theme file during its own init, which sets `$PROMPT`.
**How to avoid:** `eval "$(starship init zsh)"` must be the last line in `.zshrc`. Set `ZSH_THEME=""` to disable oh-my-zsh's theme system.
**Warning signs:** A plain `%` or oh-my-zsh default prompt appears instead of starship.

### Pitfall 4: starship.toml Location Differs from Other Config Files

**What goes wrong:** Symlinking `starship.toml` to `$HOME/starship.toml` instead of `$HOME/.config/starship.toml`. Starship will use defaults silently.
**Why it happens:** Three of the four config files go to `$HOME`; starship is the exception.
**How to avoid:** Target is always `$HOME/.config/starship.toml`. Also requires `mkdir -p $HOME/.config` since fresh servers may not have this directory.
**Warning signs:** Custom starship prompt config is ignored; default prompt displayed.

### Pitfall 5: Default Shell Change Does Not Take Effect in the Current Session

**What goes wrong:** After `usermod -s $(which zsh) $USER`, the current terminal session still uses bash.
**Why it happens:** `usermod` changes the login shell for future sessions only. The current process's shell does not change.
**How to avoid:** This is expected behavior. The bootstrap should log a clear success message and instruct the user to start a new SSH session. Do not attempt to `exec zsh` inside the bootstrap — the bootstrap runs as root via `sudo`, and switching shells mid-script may cause unexpected behavior with `set -eEuo pipefail`.
**Warning signs:** User reports "it didn't work" immediately after bootstrap because they're still in the old session.

### Pitfall 6: Plugin Clone Fails Without `--depth 1` on Slow Connections

**What goes wrong:** Full `git clone` of zsh-syntax-highlighting can be slow on RPi (the repo is large with full history).
**Why it happens:** Full clone pulls all history; shallow clone pulls only the latest commit.
**How to avoid:** Always use `--depth 1` for plugin clones. No history is needed — only the working tree.
**Warning signs:** Bootstrap takes several minutes just for plugin installation.

### Pitfall 7: zsh Path Not in `/etc/shells`

**What goes wrong:** `usermod -s /usr/bin/zsh ...` or `chsh -s /usr/bin/zsh` fails with "invalid shell."
**Why it happens:** Both tools validate the target shell against `/etc/shells`. On some minimal images, `apt install zsh` may not add the path automatically.
**How to avoid:** After `apt install zsh`, verify `grep -q "$(which zsh)" /etc/shells`. If absent, append it.
**Warning signs:** `usermod: no changes` or `chsh: invalid shell` error despite zsh being installed.

---

## Code Examples

Verified patterns from official sources:

### oh-my-zsh Unattended Install (Verified against ohmyzsh/ohmyzsh install.sh)

```bash
# Source: https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
# RUNZSH=no  — don't exec zsh after install
# CHSH=no    — don't call chsh (we handle shell change separately)
# KEEP_ZSHRC=yes — don't overwrite .zshrc (we deploy our own)
RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Alternative using the `--unattended` flag (equivalent to `RUNZSH=no CHSH=no`):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  "" --unattended --keep-zshrc
```

### Starship Unattended Install (Verified against starship/starship install.sh)

```bash
# Source: https://raw.githubusercontent.com/starship/starship/master/install/install.sh
# -y / --yes — skip confirmation prompt
# Installs to /usr/local/bin/starship by default
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
```

### Plugin Clone Pattern (Verified against zsh-users/zsh-autosuggestions INSTALL.md)

```bash
# Source: https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md
git clone --depth 1 \
  https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

git clone --depth 1 \
  https://github.com/zsh-users/zsh-syntax-highlighting \
  "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
```

### .zshrc Core Structure

```zsh
# Source: verified against starship.rs/guide/ for init placement
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME=""   # Disable oh-my-zsh themes — starship replaces them

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# Aliases (Linux-specific; "feels like macOS" via content)
[[ -f "${HOME}/.zsh_aliases" ]] && source "${HOME}/.zsh_aliases"

# Starship must be LAST — sets $PROMPT
eval "$(starship init zsh)"
```

### Starship Init in .zshrc — Quoting Note (v1.17.0+)

```zsh
# Source: starship/starship issue #5667
# Double quotes required since v1.17.0
eval "$(starship init zsh)"   # correct
# eval $(starship init zsh)   # broken in v1.17.0+
```

### usermod Shell Change

```bash
# Source: verified pattern from multiple Linux admin references
# usermod is preferred over chsh in non-interactive/root contexts
local zsh_path
zsh_path="$(command -v zsh)"
grep -qF "$zsh_path" /etc/shells || echo "$zsh_path" >> /etc/shells
usermod -s "$zsh_path" "$TARGET_USER"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| oh-my-zsh with named theme | oh-my-zsh with `ZSH_THEME=""` + starship | When starship adopted | Theme and starship fight over `$PROMPT`; must disable theme |
| `eval $(starship init zsh)` | `eval "$(starship init zsh)"` | starship v1.17.0 (2023) | Unquoted eval breaks in v1.17.0+; always use double quotes |
| Full `git clone` for plugins | `git clone --depth 1` | Long established | Depth-1 shallow clone is standard for plugin installs where history is unnecessary |
| `chsh -s /bin/zsh` | `usermod -s $(which zsh) $USER` | Long established for scripts | `chsh` has PAM interaction issues in non-interactive root scripts; `usermod` is direct |

**Deprecated/outdated:**
- Named oh-my-zsh themes when using starship: setting a theme name alongside starship causes duplicate prompt rendering.
- oh-my-zsh `--unattended` without `--keep-zshrc`: Still sets `RUNZSH=no CHSH=no` but will overwrite `.zshrc`.

---

## Open Questions

1. **SUDO_USER vs TARGET_USER for shell change**
   - What we know: Bootstrap runs as root (enforced by `os_require_root`). The real user who will SSH in is likely the user who invoked `sudo`. `SUDO_USER` captures this. If bootstrap is run directly as root (not via sudo), `SUDO_USER` is unset.
   - What's unclear: Which user's shell should be changed on a fresh server where root runs directly?
   - Recommendation: The planner should define `TARGET_USER` as `${SUDO_USER:-root}` and log it clearly. If setting root's default shell to zsh, this is fine for a homelab server where root is the primary user.

2. **dotfiles/ directory vs config/ directory**
   - What we know: The repo has a `config/` directory (empty, gitkeep). The CONTEXT.md says dotfiles go in `dotfiles/` at the repo root. These are two different directories.
   - What's unclear: Whether `config/` should remain (future use) or be repurposed. The ROADMAP says `config/` is "used from phase 2 onward."
   - Recommendation: Create `dotfiles/` as a new directory for the four config files. Leave `config/` for potential future use (it's empty and gitkeep'd). The planner should create both `dotfiles/` and the four files within it.

3. **bootstrap.sh Phase 2 invocation pattern**
   - What we know: bootstrap.sh currently sources `scripts/install-gitleaks.sh` and calls three functions. Phase 2 comment says: `# Phase 2: Shell environment (source scripts/install-shell.sh)`.
   - What's unclear: Whether Phase 2 functions should be called in one block or if there are ordering constraints between them.
   - Recommendation: The ordering matters — install zsh → install oh-my-zsh → install plugins → install starship → install tmux → deploy dotfiles. The planner should confirm this sequence because oh-my-zsh must exist before plugin clones target `~/.oh-my-zsh/custom/plugins/`.

---

## Sources

### Primary (HIGH confidence)

- [ohmyzsh/ohmyzsh install.sh](https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh) — confirmed: `RUNZSH=no`, `CHSH=no`, `KEEP_ZSHRC=yes`, `--unattended`, `--keep-zshrc` flags; confirmed installer exits with `exit 1` when `~/.oh-my-zsh` already exists (not idempotent)
- [starship/starship install.sh](https://raw.githubusercontent.com/starship/starship/master/install/install.sh) — confirmed: `-y`/`--yes` flag; default install to `/usr/local/bin/`; ARM64 support
- [starship.rs/guide/](https://starship.rs/guide/) — confirmed: `eval "$(starship init zsh)"` as the zsh init command
- [zsh-users/zsh-autosuggestions INSTALL.md](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md) — confirmed: clone path `${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions`
- [zsh-users/zsh-syntax-highlighting INSTALL.md](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md) — confirmed: same clone path pattern

### Secondary (MEDIUM confidence)

- [starship.rs/presets/ — no-nerd-font preset](https://starship.rs/presets/) — confirmed: `starship preset no-nerd-font -o ~/.config/starship.toml` command; safe for servers without Nerd Fonts
- [starship/starship issue #5667](https://github.com/starship/starship/issues/5667) — confirmed: double-quote requirement for `eval "$(starship init zsh)"` since v1.17.0
- [Raspberry Pi Forums — chsh vs usermod](https://forums.raspberrypi.com/viewtopic.php?t=231086) — confirmed: `chsh` has PAM issues on RPi OS; `usermod` is reliable; multiple community reports consistent with this finding
- WebSearch results on `usermod -s` vs `chsh` — consistent across multiple Linux admin sources; `usermod` modifies `/etc/passwd` directly without authentication prompts

### Tertiary (LOW confidence)

- WebSearch results on `/etc/shells` requirement for `usermod -s` — multiple consistent sources but not verified against a single authoritative man page; behavior is long-established Linux convention

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against official install scripts and official docs
- Architecture patterns: HIGH — based on Phase 1 established patterns plus verified official sources
- oh-my-zsh idempotency pitfall: HIGH — verified directly from install.sh source code (installer calls `exit 1`)
- Pitfalls: HIGH for oh-my-zsh and starship ordering (official sources); MEDIUM for usermod/chsh RPi behavior (community reports)
- starship.toml content: LOW — content is Claude's discretion; recommendations based on starship docs but the "right" config depends on user preference

**Research date:** 2026-02-22
**Valid until:** 2026-08-22 (180 days — oh-my-zsh and starship release frequently but install script APIs are stable; zsh plugin URLs are stable)
