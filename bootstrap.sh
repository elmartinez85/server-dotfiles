#!/usr/bin/env bash
# bootstrap.sh — Usage: curl <url>/bootstrap.sh | bash
# Or with dry-run: curl <url>/bootstrap.sh | bash -s -- --dry-run
set -eEuo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/<YOUR_GITHUB_USER>/server-dotfiles.git"
DOTFILES_DIR="${HOME}/.dotfiles"
LOG_FILE="${DOTFILES_DIR}/bootstrap.log"
MANIFEST_FILE="${DOTFILES_DIR}/.installed"

# ── Flags ────────────────────────────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done
export DRY_RUN

# ── Bootstrap summary tracking ───────────────────────────────────────────────
_SUMMARY_INSTALLED=()
_SUMMARY_SKIPPED=()
_SUMMARY_WARNINGS=()

# ── Repo clone (before libs can be sourced) ───────────────────────────────────
if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
  echo "==> Cloning server-dotfiles to ${DOTFILES_DIR}..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> ${DOTFILES_DIR} already exists — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only || true
fi

# ── Source libs ───────────────────────────────────────────────────────────────
# shellcheck source=lib/log.sh
source "${DOTFILES_DIR}/lib/log.sh"
# shellcheck source=lib/os.sh
source "${DOTFILES_DIR}/lib/os.sh"
# shellcheck source=lib/pkg.sh
source "${DOTFILES_DIR}/lib/pkg.sh"

# ── Logging setup — dual output to terminal and log file ─────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Cleanup / rollback function ────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Bootstrap failed (exit ${exit_code}). Reverting all installed state..."
    if [[ -f "$MANIFEST_FILE" ]]; then
      local steps=()
      mapfile -t steps < "$MANIFEST_FILE"
      local i
      for (( i=${#steps[@]}-1; i>=0; i-- )); do
        _undo_step "${steps[$i]}" || true
      done
      rm -f "$MANIFEST_FILE"
    fi
    log_error "Cleanup complete. See ${LOG_FILE} for details."
  else
    _print_summary
  fi
}
trap cleanup EXIT

# ── Undo dispatcher ────────────────────────────────────────────────────────────
_undo_step() {
  local entry="$1"
  local type="${entry%%:*}"
  local payload="${entry#*:}"
  case "$type" in
    file)
      if [[ -f "$payload" ]]; then
        rm -f "$payload"
        log_info "Removed: ${payload}"
      fi
      ;;
    hook)
      # Format: hook:pre-commit:/path/to/.git/hooks/pre-commit
      local hook_path="${payload#*:}"
      if [[ -f "$hook_path" ]]; then
        rm -f "$hook_path"
        log_info "Removed hook: ${hook_path}"
      fi
      ;;
    symlink)
      if [[ -L "$payload" ]]; then
        rm -f "$payload"
        log_info "Removed symlink: ${payload}"
      fi
      ;;
    *)
      log_warn "Unknown manifest entry type '${type}' — skipping undo for: ${entry}"
      ;;
  esac
}

# ── Summary printer ────────────────────────────────────────────────────────────
_print_summary() {
  echo ""
  log_step "Bootstrap Complete"
  if [[ ${#_SUMMARY_INSTALLED[@]} -gt 0 ]]; then
    log_success "Installed:"
    for item in "${_SUMMARY_INSTALLED[@]}"; do
      echo "    - ${item}"
    done
  fi
  if [[ ${#_SUMMARY_SKIPPED[@]} -gt 0 ]]; then
    log_info "Skipped (already present):"
    for item in "${_SUMMARY_SKIPPED[@]}"; do
      echo "    - ${item}"
    done
  fi
  if [[ ${#_SUMMARY_WARNINGS[@]} -gt 0 ]]; then
    log_warn "Warnings:"
    for item in "${_SUMMARY_WARNINGS[@]}"; do
      echo "    ! ${item}"
    done
  fi
}

# ── Root check ─────────────────────────────────────────────────────────────────
os_require_root

# ── Architecture detection ─────────────────────────────────────────────────────
ARCH="$(os_detect_arch)"
export ARCH
log_step "Starting bootstrap (arch: ${ARCH}, dry-run: ${DRY_RUN})"
log_info "Log file: ${LOG_FILE}"

# ── Phase scripts ──────────────────────────────────────────────────────────────
# Phase 1: Foundation (secret prevention)
# shellcheck source=scripts/install-gitleaks.sh
source "${DOTFILES_DIR}/scripts/install-gitleaks.sh"
install_gitleaks
install_pre_commit_hook
scan_git_history

# Phase 2: Shell environment and config deployment
# Ordering rationale — dependency order is mandatory:
#   1. install_zsh        — install zsh + set default shell (foundation for all below)
#   2. install_ohmyzsh    — install oh-my-zsh framework (plugins clone into its custom dir)
#   3. install_zsh_plugins — clone zsh-autosuggestions + zsh-syntax-highlighting into oh-my-zsh/custom/plugins/
#   4. install_starship   — install starship binary (independent; placed after plugins for logical grouping)
#   5. install_tmux       — install tmux package (fully independent)
#   6. deploy_dotfiles    — create symlinks last (dotfiles reference all the above)
# shellcheck source=scripts/install-shell.sh
source "${DOTFILES_DIR}/scripts/install-shell.sh"
install_zsh
install_ohmyzsh
install_zsh_plugins
install_starship
install_tmux
deploy_dotfiles

# Phase 3: CLI tools and Docker
# Ordering rationale:
#   1. install-tools.sh — seven CLI tools, each soft-failed via _try_install
#      (one bad binary download does not abort the entire bootstrap)
#   2. install-docker.sh — Docker Engine (hard-fail: required infrastructure),
#      then lazydocker (soft-fail: optional TUI tool)
# shellcheck source=scripts/install-tools.sh
source "${DOTFILES_DIR}/scripts/install-tools.sh"
_try_install install_ripgrep
_try_install install_fd
_try_install install_fzf
_try_install install_eza
_try_install install_bat
_try_install install_delta
_try_install install_nvim

# shellcheck source=scripts/install-docker.sh
source "${DOTFILES_DIR}/scripts/install-docker.sh"
install_docker_engine
verify_docker_running
add_user_to_docker_group
_try_install install_lazydocker

# Phase 4: Security hardening (source scripts/install-security.sh)

log_success "Bootstrap finished successfully."
