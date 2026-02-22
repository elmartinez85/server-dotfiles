#!/usr/bin/env bash
# scripts/verify.sh — Run after re-login to confirm Phase 3 is complete
# Usage: bash ~/.dotfiles/scripts/verify.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source version store — do not hardcode versions here
# shellcheck source=lib/versions.sh
source "${DOTFILES_DIR}/lib/versions.sh"

PASS=0
FAIL=0

check_binary() {
  local name="$1"
  local version_cmd="$2"
  local expected_ver="$3"

  if ! command -v "$name" &>/dev/null; then
    echo "FAIL: ${name} not found in PATH"
    FAIL=$((FAIL + 1))
    return
  fi

  local ver
  ver="$(eval "$version_cmd" 2>/dev/null | head -1 || echo "unknown")"
  if [[ "$ver" == *"$expected_ver"* ]]; then
    echo "PASS: ${name} ${expected_ver}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${name} version mismatch (got: ${ver}, want: ${expected_ver})"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> Phase 3 Verification"
echo ""

# CLI tools
check_binary rg         "rg --version"         "$RIPGREP_VERSION"
check_binary fd         "fd --version"         "$FD_VERSION"
check_binary fzf        "fzf --version"        "$FZF_VERSION"
check_binary eza        "eza --version"        "$EZA_VERSION"
check_binary bat        "bat --version"        "$BAT_VERSION"
check_binary delta      "delta --version"      "$DELTA_VERSION"
check_binary nvim       "nvim --version"       "$NVIM_VERSION"

# Docker — requires docker group membership (re-login required)
echo ""
echo "==> Docker checks (require re-login for group membership)"

if docker run --rm hello-world &>/dev/null 2>&1; then
  echo "PASS: docker run hello-world (no sudo)"
  PASS=$((PASS + 1))
else
  echo "FAIL: docker run hello-world failed (did you re-login after bootstrap?)"
  FAIL=$((FAIL + 1))
fi

if docker compose version &>/dev/null 2>&1; then
  echo "PASS: docker compose version"
  PASS=$((PASS + 1))
else
  echo "FAIL: docker compose not available"
  FAIL=$((FAIL + 1))
fi

check_binary lazydocker "lazydocker --version" "$LAZYDOCKER_VERSION"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

[[ $FAIL -eq 0 ]]
