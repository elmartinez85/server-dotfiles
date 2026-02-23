#!/usr/bin/env bash
# scripts/install-tools.sh
# Sourced by bootstrap.sh — provides install_ripgrep, install_fd, install_fzf,
# install_eza, install_bat, install_delta, install_nvim
# Do NOT execute directly.
# shellcheck source=lib/log.sh
# shellcheck source=lib/versions.sh
if [[ -n "${_SCRIPT_INSTALL_TOOLS_LOADED:-}" ]]; then return 0; fi
_SCRIPT_INSTALL_TOOLS_LOADED=1

# Source canonical version store — provides RIPGREP_VERSION, FD_VERSION, etc.
# shellcheck source=lib/versions.sh
source "${DOTFILES_DIR}/lib/versions.sh"

# ── Helper: _arch_for_tool ─────────────────────────────────────────────────────
# Maps os.sh canonical ARCH (x86_64 or arm64) to tool-specific URL naming.
# Usage: local arch; arch="$(_arch_for_tool ripgrep)"
#
# CRITICAL — getting this wrong causes a 404 at download time.
# Each tool uses different naming conventions in their GitHub Release URLs:
#   fzf:                    amd64 / arm64
#   eza, ripgrep, fd, bat, delta: x86_64 / aarch64
#   nvim, lazydocker:       x86_64 / arm64 (matches $ARCH directly)
_arch_for_tool() {
  local tool="$1"
  case "$tool" in
    fzf)
      # fzf uses amd64/arm64 (not x86_64/aarch64)
      case "$ARCH" in x86_64) echo "amd64" ;; arm64) echo "arm64" ;; esac ;;
    eza|ripgrep|fd|bat|delta)
      # these use x86_64/aarch64
      case "$ARCH" in x86_64) echo "x86_64" ;; arm64) echo "aarch64" ;; esac ;;
    nvim|lazydocker)
      # nvim and lazydocker use x86_64/arm64 (matching $ARCH directly)
      echo "$ARCH" ;;
  esac
}

# ── Helper: _try_install ───────────────────────────────────────────────────────
# Runs an install function. On failure: logs warning, appends to _SUMMARY_WARNINGS,
# continues. Docker Engine is NOT soft-failed (in install-docker.sh, not here).
#
# bootstrap.sh calls: _try_install install_ripgrep (not install_ripgrep directly)
# This is required because set -eEuo pipefail is active in bootstrap.sh — any
# non-zero return from a direct call would abort the entire bootstrap.
_try_install() {
  local fn="$1"
  if ! "$fn"; then
    log_warn "WARNING: ${fn} failed — continuing bootstrap. Check logs."
    _SUMMARY_WARNINGS+=("${fn} failed — tool may not be available")
  fi
}

# ── Function 1: install_ripgrep ────────────────────────────────────────────────
# Installs ripgrep (rg) from GitHub Releases.
# URL structure: ripgrep-{ver}-{arch}-unknown-linux-{libc}.tar.gz
# x86_64: arch=x86_64, libc=musl  (statically linked, better portability)
# arm64:  arch=aarch64, libc=gnu
# Binary path in archive: ripgrep-{ver}-{arch}-unknown-linux-{libc}/rg
install_ripgrep() {
  local version="${RIPGREP_VERSION}"
  local install_path="/usr/local/bin/rg"

  log_step "Checking ripgrep ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "ripgrep ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("ripgrep ${version}")
      return 0
    fi
    log_info "ripgrep version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install ripgrep ${version} (${ARCH})"
    return 0
  fi

  # Architecture mapping: x86_64 uses musl, arm64 uses gnu (different libc per arch)
  local arch libc
  arch="$(_arch_for_tool ripgrep)"  # x86_64 or aarch64
  case "$ARCH" in x86_64) libc="musl" ;; arm64) libc="gnu" ;; esac
  local subdir="ripgrep-${version}-${arch}-unknown-linux-${libc}"
  local url="https://github.com/BurntSushi/ripgrep/releases/download/${version}/${subdir}.tar.gz"

  log_step "Downloading ripgrep ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/${subdir}/rg" "$install_path"

  log_success "ripgrep ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("ripgrep ${version}")
}

# ── Function 2: install_fd ─────────────────────────────────────────────────────
# Installs fd from GitHub Releases.
# URL structure: fd-v{ver}-{arch}-unknown-linux-{libc}.tar.gz
# x86_64: arch=x86_64, libc=musl; arm64: arch=aarch64, libc=gnu
# Binary path in archive: fd-v{ver}-{arch}-unknown-linux-{libc}/fd
install_fd() {
  local version="${FD_VERSION}"
  local install_path="/usr/local/bin/fd"

  log_step "Checking fd ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "fd ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("fd ${version}")
      return 0
    fi
    log_info "fd version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install fd ${version} (${ARCH})"
    return 0
  fi

  # Architecture mapping: x86_64 uses musl, arm64 uses gnu (same split as ripgrep)
  local arch libc
  arch="$(_arch_for_tool fd)"  # x86_64 or aarch64
  case "$ARCH" in x86_64) libc="musl" ;; arm64) libc="gnu" ;; esac
  local subdir="fd-v${version}-${arch}-unknown-linux-${libc}"
  local url="https://github.com/sharkdp/fd/releases/download/v${version}/${subdir}.tar.gz"

  log_step "Downloading fd ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/${subdir}/fd" "$install_path"

  log_success "fd ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("fd ${version}")
}

# ── Function 3: install_fzf ────────────────────────────────────────────────────
# Installs fzf from GitHub Releases.
# URL structure: fzf-{ver}-linux_{fzf_arch}.tar.gz
# fzf uses amd64/arm64 naming (NOT x86_64/aarch64) — requires mapping from $ARCH
# Tarball structure: FLAT — binary 'fzf' is directly in $tmpdir (no subdirectory)
install_fzf() {
  local version="${FZF_VERSION}"
  local install_path="/usr/local/bin/fzf"

  log_step "Checking fzf ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "fzf ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("fzf ${version}")
      return 0
    fi
    log_info "fzf version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install fzf ${version} (${ARCH})"
    return 0
  fi

  # fzf uses amd64/arm64 naming (not x86_64/aarch64)
  local fzf_arch
  fzf_arch="$(_arch_for_tool fzf)"  # amd64 or arm64
  local url="https://github.com/junegunn/fzf/releases/download/v${version}/fzf-${version}-linux_${fzf_arch}.tar.gz"

  log_step "Downloading fzf ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  # fzf is a flat archive — binary is directly in $tmpdir (no subdirectory)
  install -m 755 "${tmpdir}/fzf" "$install_path"

  log_success "fzf ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("fzf ${version}")
}

# ── Function 4: install_eza ────────────────────────────────────────────────────
# Installs eza from GitHub Releases.
# URL structure: eza_{arch}-unknown-linux-gnu.tar.gz
# x86_64: arch=x86_64; arm64: arch=aarch64
# Tarball structure: FLAT — binary './eza' directly in $tmpdir
install_eza() {
  local version="${EZA_VERSION}"
  local install_path="/usr/local/bin/eza"

  log_step "Checking eza ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "eza ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("eza ${version}")
      return 0
    fi
    log_info "eza version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install eza ${version} (${ARCH})"
    return 0
  fi

  # eza uses x86_64/aarch64 naming
  local arch
  arch="$(_arch_for_tool eza)"  # x86_64 or aarch64
  local url="https://github.com/eza-community/eza/releases/download/v${version}/eza_${arch}-unknown-linux-gnu.tar.gz"

  log_step "Downloading eza ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  # eza is a flat archive — binary './eza' is directly in $tmpdir
  install -m 755 "${tmpdir}/eza" "$install_path"

  log_success "eza ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("eza ${version}")
}

# ── Function 5: install_bat ────────────────────────────────────────────────────
# Installs bat from GitHub Releases.
# URL structure: bat-v{ver}-{arch}-unknown-linux-{libc}.tar.gz
# x86_64: arch=x86_64, libc=musl; arm64: arch=aarch64, libc=gnu
# Binary path in archive: bat-v{ver}-{arch}-unknown-linux-{libc}/bat
install_bat() {
  local version="${BAT_VERSION}"
  local install_path="/usr/local/bin/bat"

  log_step "Checking bat ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "bat ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("bat ${version}")
      return 0
    fi
    log_info "bat version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install bat ${version} (${ARCH})"
    return 0
  fi

  # Architecture mapping: x86_64 uses musl, arm64 uses gnu (same split as ripgrep/fd)
  local arch libc
  arch="$(_arch_for_tool bat)"  # x86_64 or aarch64
  case "$ARCH" in x86_64) libc="musl" ;; arm64) libc="gnu" ;; esac
  local subdir="bat-v${version}-${arch}-unknown-linux-${libc}"
  local url="https://github.com/sharkdp/bat/releases/download/v${version}/${subdir}.tar.gz"

  log_step "Downloading bat ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/${subdir}/bat" "$install_path"

  log_success "bat ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("bat ${version}")
}

# ── Function 6: install_delta ──────────────────────────────────────────────────
# Installs delta (git-delta) from GitHub Releases.
# URL structure: delta-{ver}-{arch}-unknown-linux-{libc}.tar.gz
# x86_64: arch=x86_64, libc=musl; arm64: arch=aarch64, libc=gnu
# NOTE: delta version has NO 'v' prefix in the URL (unlike other tools)
# Binary path in archive: delta-{ver}-{arch}-unknown-linux-{libc}/delta
install_delta() {
  local version="${DELTA_VERSION}"
  local install_path="/usr/local/bin/delta"

  log_step "Checking delta ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "delta ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("delta ${version}")
      return 0
    fi
    log_info "delta version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install delta ${version} (${ARCH})"
    return 0
  fi

  # Architecture mapping: x86_64 uses musl, arm64 uses gnu (same split as ripgrep/fd/bat)
  local arch libc
  arch="$(_arch_for_tool delta)"  # x86_64 or aarch64
  case "$ARCH" in x86_64) libc="musl" ;; arm64) libc="gnu" ;; esac
  local subdir="delta-${version}-${arch}-unknown-linux-${libc}"
  # NOTE: delta uses NO 'v' prefix in download URL — use ${version} not v${version}
  local url="https://github.com/dandavison/delta/releases/download/${version}/${subdir}.tar.gz"

  log_step "Downloading delta ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/${subdir}/delta" "$install_path"

  log_success "delta ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("delta ${version}")
}

# ── Function 7: install_nvim ───────────────────────────────────────────────────
# Installs neovim from GitHub Releases tarball (NOT AppImage).
# AppImage requires FUSE which is unavailable on many headless servers.
# Tarball has no runtime deps beyond glibc.
#
# URL structure: nvim-linux-{ARCH}.tar.gz  (uses $ARCH directly: x86_64 or arm64)
# Binary path in archive: nvim-linux-{ARCH}/bin/nvim
install_nvim() {
  local version="${NVIM_VERSION}"
  local install_path="/usr/local/bin/nvim"

  log_step "Checking nvim ${version}..."

  # Idempotency: skip if binary exists AND version matches
  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "nvim ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("nvim ${version}")
      return 0
    fi
    log_info "nvim version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install nvim ${version} (${ARCH})"
    return 0
  fi

  # nvim uses x86_64/arm64 naming — $ARCH matches directly (no mapping needed)
  # Tarball: nvim-linux-{ARCH}/bin/nvim
  local url="https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-${ARCH}.tar.gz"

  log_step "Downloading nvim ${version} for linux/${ARCH}..."

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/nvim-linux-${ARCH}/bin/nvim" "$install_path"

  log_success "nvim ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("nvim ${version}")
}
