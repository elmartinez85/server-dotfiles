#!/usr/bin/env bash
# scripts/install-shell.sh
# Sourced by bootstrap.sh — provides install_zsh, install_ohmyzsh, install_starship,
# install_tmux, install_zsh_plugins, deploy_dotfiles
# Do NOT execute directly.
# shellcheck source=lib/log.sh
# shellcheck source=lib/pkg.sh
if [[ -n "${_SCRIPT_INSTALL_SHELL_LOADED:-}" ]]; then return 0; fi
_SCRIPT_INSTALL_SHELL_LOADED=1

# ── Helper: _already_installed ─────────────────────────────────────────────────
# _already_installed <install_path> <label>
#
# Returns 0 (skip) if binary exists at install_path.
# On skip: logs inline skip message and appends label to _SUMMARY_SKIPPED.
# Returns 1 (proceed) if binary is absent.
#
# Use this helper for binary-download installers only.
# apt-managed tools (zsh, tmux) use pkg_installed instead.
_already_installed() {
  local install_path="$1"
  local label="$2"
  if [[ -f "$install_path" ]]; then
    log_info "${label} already installed — skipping"
    _SUMMARY_SKIPPED+=("${label}")
    return 0
  fi
  return 1
}

# ── Function 1: install_zsh ────────────────────────────────────────────────────
# Installs zsh via apt and sets it as the default shell for the target user.
# Target user: SUDO_USER (the real invoking user when bootstrap is run via sudo)
# or root if bootstrap is run directly as root.
# Uses usermod (not chsh) — chsh has PAM auth issues on RPi OS variants.
install_zsh() {
  log_step "Installing zsh and setting as default shell..."

  pkg_install zsh

  # Determine target user — bootstrap runs as root, but we want the default shell
  # set for the real user who invoked sudo (SUDO_USER), not root.
  local target_user="${SUDO_USER:-root}"
  local zsh_path
  zsh_path="$(command -v zsh)"

  # Ensure zsh is listed in /etc/shells — both usermod and chsh validate against it.
  # apt install zsh usually adds it but not guaranteed on all minimal images.
  if ! grep -qF "$zsh_path" /etc/shells; then
    echo "$zsh_path" >> /etc/shells
    log_info "Added ${zsh_path} to /etc/shells"
  fi

  # Check if zsh is already the default shell for the target user
  local current_shell
  current_shell="$(getent passwd "$target_user" | cut -d: -f7)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_info "zsh already default shell for ${target_user} — skipping"
    _SUMMARY_SKIPPED+=("zsh default shell")
    return 0
  fi

  usermod -s "$zsh_path" "$target_user"
  log_success "Default shell for ${target_user} set to ${zsh_path}"
  # Pitfall 5: shell change does NOT take effect in the current session.
  # Do NOT exec zsh here — bootstrap runs as root via sudo and mid-script
  # shell switch causes issues with set -eEuo pipefail.
  log_warn "New shell takes effect on next login — start a new SSH session"
  _SUMMARY_INSTALLED+=("zsh (default shell for ${target_user})")
}

# ── Function 2: install_ohmyzsh ────────────────────────────────────────────────
# Installs oh-my-zsh via the official unattended install script.
#
# CRITICAL: The official oh-my-zsh installer exits with error code 1 when
# ~/.oh-my-zsh already exists — it is NOT idempotent. Guard with a directory
# pre-check. The locked decision to "re-run anyway" is incorrect and is
# overridden by this research finding.
#
# KEEP_ZSHRC=yes is required — without it the installer overwrites the existing
# .zshrc with its template. Since deploy_dotfiles deploys the repo's .zshrc as
# a symlink, the installer must not touch it.
install_ohmyzsh() {
  log_step "Checking oh-my-zsh..."

  # Guard: the official oh-my-zsh installer exits with error code 1 when
  # ~/.oh-my-zsh already exists — it is NOT idempotent.
  # Only proceed with installation if the directory does NOT exist.
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
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
  else
    log_info "oh-my-zsh already installed (~/.oh-my-zsh exists) — skipping"
    _SUMMARY_SKIPPED+=("oh-my-zsh")
  fi
}

# ── Function 3: install_starship ───────────────────────────────────────────────
# Installs the starship prompt via the official install script.
# Idempotency: binary presence at /usr/local/bin/starship is the skip guard.
# Loose check only (no version comparison) — per CONTEXT.md locked decision.
install_starship() {
  local install_path="/usr/local/bin/starship"

  log_step "Checking starship..."

  if _already_installed "$install_path" "starship"; then
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install starship via official install script"
    return 0
  fi

  # arm64 Linux: musl build not available for aarch64 — use gnu instead
  local platform_flag=""
  [[ "$ARCH" == "arm64" ]] && platform_flag="--platform unknown-linux-gnu"
  # shellcheck disable=SC2086
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes ${platform_flag}

  log_success "starship installed at $(command -v starship)"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("starship")
}

# ── Function 4: install_tmux ───────────────────────────────────────────────────
# Installs tmux via apt.
# Idempotency: pkg_installed check BEFORE pkg_install determines correct summary bucket.
install_tmux() {
  log_step "Installing tmux..."

  if pkg_installed tmux; then
    log_info "tmux already installed — skipping"
    _SUMMARY_SKIPPED+=("tmux")
    return 0
  fi

  pkg_install tmux
  _SUMMARY_INSTALLED+=("tmux")
}

# ── Function 5: install_zsh_plugins ───────────────────────────────────────────
# Installs both zsh plugins via shallow git clone into ZSH_CUSTOM/plugins/.
#
# Uses ${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom} (NOT hardcoded path).
# Uses --depth 1 (mandatory — zsh-syntax-highlighting repo is large; full
# clone is slow on RPi — Pitfall 6).
# Must be called after install_ohmyzsh since plugins clone into its custom dir.
install_zsh_plugins() {
  log_step "Installing zsh plugins..."

  local plugins_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"

  # zsh-autosuggestions
  if [[ -d "${plugins_dir}/zsh-autosuggestions" ]]; then
    log_info "zsh-autosuggestions already installed — skipping"
    _SUMMARY_SKIPPED+=("zsh-autosuggestions")
  else
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
      log_info "[DRY RUN] Would clone zsh-autosuggestions into ${plugins_dir}"
    else
      git clone --depth 1 \
        https://github.com/zsh-users/zsh-autosuggestions \
        "${plugins_dir}/zsh-autosuggestions"
      echo "file:${plugins_dir}/zsh-autosuggestions" >> "$MANIFEST_FILE"
      _SUMMARY_INSTALLED+=("zsh-autosuggestions")
      log_success "zsh-autosuggestions installed"
    fi
  fi

  # zsh-syntax-highlighting
  if [[ -d "${plugins_dir}/zsh-syntax-highlighting" ]]; then
    log_info "zsh-syntax-highlighting already installed — skipping"
    _SUMMARY_SKIPPED+=("zsh-syntax-highlighting")
  else
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
      log_info "[DRY RUN] Would clone zsh-syntax-highlighting into ${plugins_dir}"
    else
      git clone --depth 1 \
        https://github.com/zsh-users/zsh-syntax-highlighting \
        "${plugins_dir}/zsh-syntax-highlighting"
      echo "file:${plugins_dir}/zsh-syntax-highlighting" >> "$MANIFEST_FILE"
      _SUMMARY_INSTALLED+=("zsh-syntax-highlighting")
      log_success "zsh-syntax-highlighting installed"
    fi
  fi
}

# ── Helper: _deploy_symlink ────────────────────────────────────────────────────
# _deploy_symlink src dst
#
# Case 1 — symlink already correct (readlink dst == src): skip.
# Case 2 — real file at dst (not a symlink): back it up to ~/.dotfiles.bak/
#           with timestamp collision handling, then link.
# Case 3 — broken or stale symlink at dst: remove and re-link.
# Final   — ln -sfn src dst; write symlink manifest entry.
_deploy_symlink() {
  local src="$1"
  local dst="$2"
  local filename
  filename="$(basename "$dst")"

  # Case 1: symlink already exists and points to the correct source — skip
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    log_info "${filename} symlink already correct — skipping"
    _SUMMARY_SKIPPED+=("${filename} symlink")
    return 0
  fi

  # Case 2: real file exists (not a symlink) — back it up before replacing
  if [[ -f "$dst" && ! -L "$dst" ]]; then
    local backup_path="${backup_dir}/${filename}"
    # Timestamp suffix prevents collision if backup already exists
    if [[ -f "$backup_path" ]]; then
      backup_path="${backup_dir}/${filename}.$(date +%Y-%m-%d)"
    fi
    mv "$dst" "$backup_path"
    log_info "Backed up ${filename} to ${backup_path}"
    echo "file:${backup_path}" >> "$MANIFEST_FILE"
  fi

  # Case 3: broken or stale symlink at dst — remove before re-linking
  if [[ -L "$dst" ]]; then
    rm -f "$dst"
  fi

  ln -sfn "$src" "$dst"
  log_success "Symlinked: ${dst} -> ${src}"
  echo "symlink:${dst}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("${filename} symlink")
}

# ── Function 6: deploy_dotfiles ────────────────────────────────────────────────
# Deploys the four dotfiles from the repo as symlinks into $HOME.
# Pre-existing real files are backed up to ~/.dotfiles.bak/ before symlinking.
#
# Symlink targets:
#   dotfiles/.zshrc       -> $HOME/.zshrc
#   dotfiles/.zsh_aliases -> $HOME/.zsh_aliases
#   dotfiles/.tmux.conf   -> $HOME/.tmux.conf
#   dotfiles/starship.toml -> $HOME/.config/starship.toml  (NOTE: .config subdir!)
#
# Must be called last — dotfiles reference all previously installed tools.
deploy_dotfiles() {
  log_step "Deploying dotfiles as symlinks..."

  local dotfiles_dir="${DOTFILES_DIR}/dotfiles"
  local backup_dir="${HOME}/.dotfiles.bak"
  mkdir -p "$backup_dir"

  _deploy_symlink "${dotfiles_dir}/.zshrc"       "${HOME}/.zshrc"
  _deploy_symlink "${dotfiles_dir}/.zsh_aliases" "${HOME}/.zsh_aliases"
  _deploy_symlink "${dotfiles_dir}/.tmux.conf"   "${HOME}/.tmux.conf"

  # starship.toml goes to ~/.config/starship.toml — different from the other three
  # Pitfall 4: NOT $HOME/starship.toml
  mkdir -p "${HOME}/.config"
  _deploy_symlink "${dotfiles_dir}/starship.toml" "${HOME}/.config/starship.toml"

  log_success "Dotfiles deployment complete"
}
