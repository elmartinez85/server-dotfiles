#!/usr/bin/env bash
# scripts/install-docker.sh
# Sourced by bootstrap.sh — provides install_docker_engine, verify_docker_running,
# add_user_to_docker_group, install_lazydocker
# Do NOT execute directly.
# shellcheck source=lib/log.sh
# shellcheck source=lib/versions.sh
if [[ -n "${_SCRIPT_INSTALL_DOCKER_LOADED:-}" ]]; then return 0; fi
_SCRIPT_INSTALL_DOCKER_LOADED=1

# Source canonical version store — provides LAZYDOCKER_VERSION
# shellcheck source=lib/versions.sh
source "${DOTFILES_DIR}/lib/versions.sh"

install_docker_engine() {
  log_step "Checking Docker Engine..."

  if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
    log_info "Docker already installed and running — skipping"
    _SUMMARY_SKIPPED+=("Docker Engine")
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install Docker Engine via official apt repository"
    return 0
  fi

  log_step "Installing Docker Engine via official apt repository..."

  local os_id docker_repo_distro version_codename
  os_id="$(. /etc/os-release && echo "$ID")"
  case "$os_id" in
    ubuntu)   docker_repo_distro="ubuntu" ;;
    debian)   docker_repo_distro="debian" ;;
    raspbian) docker_repo_distro="debian" ;;
    *)        docker_repo_distro="debian" ;;
  esac

  version_codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"

  apt-get update -qq
  apt-get install -y ca-certificates curl

  install -m 0755 -d /etc/apt/keyrings
  curl --fail --silent --show-error --location \
    "https://download.docker.com/linux/${docker_repo_distro}/gpg" \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Overwrite existing docker.list — idempotent
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$docker_repo_distro" "$version_codename" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  log_success "Docker Engine and Compose plugin installed"
  echo "file:/usr/bin/docker" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("Docker Engine")
  _SUMMARY_INSTALLED+=("docker compose plugin (DOCK-02)")
}

verify_docker_running() {
  log_step "Verifying Docker daemon is running..."
  if systemctl is-active --quiet docker; then
    log_success "Docker daemon is active"
  else
    log_warn "Docker daemon not active — attempting to enable and start..."
    systemctl enable --now docker || log_warn "Could not start Docker daemon — check journalctl -u docker"
    _SUMMARY_WARNINGS+=("Docker daemon required manual start — verify with: systemctl status docker")
  fi
}

add_user_to_docker_group() {
  local target_user="${SUDO_USER:-root}"
  log_step "Adding ${target_user} to docker group..."

  if ! getent group docker &>/dev/null; then
    groupadd docker
    log_info "Created docker group"
  fi

  if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
    log_info "${target_user} is already in the docker group — skipping"
    _SUMMARY_SKIPPED+=("docker group membership")
    return 0
  fi

  usermod -aG docker "$target_user"
  log_success "${target_user} added to docker group"
  log_warn "IMPORTANT: Docker group membership takes effect after re-login."
  log_warn "Run 'bash ~/.dotfiles/scripts/verify.sh' after opening a new SSH session."
  _SUMMARY_WARNINGS+=("docker group: re-login required before running docker commands as ${target_user}")
}

install_lazydocker() {
  local version="${LAZYDOCKER_VERSION}"
  local install_path="/usr/local/bin/lazydocker"

  log_step "Checking lazydocker ${version}..."

  if [[ -x "$install_path" ]]; then
    local installed_ver
    installed_ver="$("$install_path" --version 2>/dev/null | head -1 || echo "unknown")"
    if [[ "$installed_ver" == *"${version}"* ]]; then
      log_info "lazydocker ${version} already installed — skipping"
      _SUMMARY_SKIPPED+=("lazydocker ${version}")
      return 0
    fi
    log_info "lazydocker version mismatch — reinstalling"
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would install lazydocker ${version} (${ARCH})"
    return 0
  fi

  # lazydocker uses x86_64/arm64 matching $ARCH directly
  local url="https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${ARCH}.tar.gz"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    "$url" | tar -xz -C "$tmpdir"

  # lazydocker is a FLAT archive — binary is directly in $tmpdir (no subdirectory)
  install -m 755 "${tmpdir}/lazydocker" "$install_path"

  log_success "lazydocker ${version} installed at ${install_path}"
  echo "file:${install_path}" >> "$MANIFEST_FILE"
  _SUMMARY_INSTALLED+=("lazydocker ${version}")
}
