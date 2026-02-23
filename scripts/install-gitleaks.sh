#!/usr/bin/env bash
# scripts/install-gitleaks.sh
# Sourced by bootstrap.sh — provides install_gitleaks, install_pre_commit_hook, scan_git_history
# Do NOT execute directly.
if [[ -n "${_SCRIPT_INSTALL_GITLEAKS_LOADED:-}" ]]; then return 0; fi
_SCRIPT_INSTALL_GITLEAKS_LOADED=1

# Source canonical version store — provides GITLEAKS_VERSION
# shellcheck source=lib/versions.sh
source "${DOTFILES_DIR}/lib/versions.sh"

GITLEAKS_INSTALL_PATH="/usr/local/bin/gitleaks"

install_gitleaks() {
  log_step "Checking gitleaks ${GITLEAKS_VERSION}..."

  # Idempotency: skip if already installed at the correct version
  if [[ -x "$GITLEAKS_INSTALL_PATH" ]]; then
    local installed_ver
    installed_ver="$("$GITLEAKS_INSTALL_PATH" version 2>/dev/null || echo "unknown")"
    if [[ "$installed_ver" == *"${GITLEAKS_VERSION}"* ]]; then
      log_info "gitleaks ${GITLEAKS_VERSION} already installed — skipping"
      _SUMMARY_SKIPPED+=("gitleaks ${GITLEAKS_VERSION}")
      return 0
    fi
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install gitleaks ${GITLEAKS_VERSION} (${ARCH}) to ${GITLEAKS_INSTALL_PATH}"
    return 0
  fi

  # gitleaks uses x64/arm64 naming (not x86_64)
  local gl_arch
  case "$ARCH" in
    x86_64) gl_arch="x64" ;;
    *)      gl_arch="$ARCH" ;;
  esac
  local url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${gl_arch}.tar.gz"
  log_step "Downloading gitleaks ${GITLEAKS_VERSION} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  # Clean up temp dir on function return regardless of outcome
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/gitleaks" "$GITLEAKS_INSTALL_PATH"

  log_success "gitleaks ${GITLEAKS_VERSION} installed at ${GITLEAKS_INSTALL_PATH}"
  echo "file:${GITLEAKS_INSTALL_PATH}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("gitleaks ${GITLEAKS_VERSION}")
}

install_pre_commit_hook() {
  log_step "Installing pre-commit hook..."

  local hook_src="${DOTFILES_DIR}/hooks/pre-commit"
  local git_dir
  git_dir="$(git -C "$DOTFILES_DIR" rev-parse --git-dir)"
  local hook_dst="${git_dir}/hooks/pre-commit"

  # Idempotency: skip if hook already installed and matches source
  if [[ -f "$hook_dst" ]] && diff -q "$hook_src" "$hook_dst" >/dev/null 2>&1; then
    log_info "pre-commit hook already installed and up to date — skipping"
    _SUMMARY_SKIPPED+=("pre-commit hook")
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would copy ${hook_src} to ${hook_dst}"
    return 0
  fi

  mkdir -p "${git_dir}/hooks"
  cp "$hook_src" "$hook_dst"
  chmod +x "$hook_dst"

  log_success "pre-commit hook installed at ${hook_dst}"
  echo "hook:pre-commit:${hook_dst}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("pre-commit hook (gitleaks)")
}

scan_git_history() {
  log_step "Scanning full git history for secrets (one-time check)..."

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would run: gitleaks git --source ${DOTFILES_DIR} --verbose"
    return 0
  fi

  if ! gitleaks git --source "$DOTFILES_DIR" --verbose; then
    log_error "Secrets detected in git history. See gitleaks report above."
    log_error "Remove the secrets, rewrite history (git filter-repo or BFG), then re-run bootstrap."
    return 1
  fi

  log_success "No secrets found in git history"
  _SUMMARY_INSTALLED+=("gitleaks history scan (clean)")
}
