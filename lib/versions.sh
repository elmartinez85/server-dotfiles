#!/usr/bin/env bash
# lib/versions.sh
# Canonical version store for all pinned tool versions across all phases.
# Sourced by: install-gitleaks.sh, install-tools.sh, install-docker.sh
# Do NOT execute directly.
if [[ -n "${_LIB_VERSIONS_LOADED:-}" ]]; then return 0; fi
_LIB_VERSIONS_LOADED=1

# ── Phase 1: Secret prevention ────────────────────────────────────────────────

GITLEAKS_VERSION="8.30.0"

# ── Phase 3: CLI tools ────────────────────────────────────────────────────────

RIPGREP_VERSION="15.1.0"
FD_VERSION="10.3.0"
FZF_VERSION="0.68.0"
EZA_VERSION="0.23.4"
BAT_VERSION="0.26.1"
DELTA_VERSION="0.18.2"
NVIM_VERSION="0.11.6"

# ── Phase 3: Docker tools ─────────────────────────────────────────────────────

LAZYDOCKER_VERSION="0.24.4"
# Docker Engine version is managed by apt (always installs latest stable from pinned repo)
