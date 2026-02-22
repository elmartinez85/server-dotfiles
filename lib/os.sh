#!/usr/bin/env bash
if [[ -n "${_LIB_OS_LOADED:-}" ]]; then return 0; fi
_LIB_OS_LOADED=1

# Source log lib if not already loaded (guard prevents double-source)
_OS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${_OS_SCRIPT_DIR}/log.sh"

os_detect_arch() {
  local raw
  raw="$(uname -m)"
  case "$raw" in
    x86_64)         echo "x86_64" ;;
    aarch64|arm64)  echo "arm64"  ;;
    *)
      log_error "Unsupported architecture: ${raw}. Supported: x86_64, aarch64/arm64"
      return 1
      ;;
  esac
}

os_require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_error "This script must be run as root (or via sudo)."
    log_error "Re-run: sudo bash bootstrap.sh"
    exit 1
  fi
}
