#!/usr/bin/env bash
if [[ -n "${_LIB_PKG_LOADED:-}" ]]; then return 0; fi
_LIB_PKG_LOADED=1

_PKG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${_PKG_SCRIPT_DIR}/log.sh"

# Check if a package is installed (via dpkg)
pkg_installed() {
  local pkg="$1"
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
}

# Idempotent apt install — skips if already installed
pkg_install() {
  local pkg="$1"
  if pkg_installed "$pkg"; then
    log_info "${pkg} already installed — skipping"
    return 0
  fi
  log_step "Installing ${pkg}..."
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would run: apt-get install -y ${pkg}"
    return 0
  fi
  apt-get install -y "$pkg"
  log_success "${pkg} installed"
}
