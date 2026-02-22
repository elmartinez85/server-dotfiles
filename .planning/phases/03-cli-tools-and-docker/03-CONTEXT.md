# Phase 3: CLI Tools and Docker - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Install seven modern CLI tools (rg, fd, fzf, eza, bat, delta, nvim) and Docker Engine with Compose plugin and lazydocker — the tooling layer that makes the server workstation-class. Shell environment and config deployment are Phase 2. SSH hardening and automated version updates are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Version pinning strategy
- Create `lib/versions.sh` (alongside log.sh, os.sh, pkg.sh) as the canonical version store
- Covers ALL pinned tools across phases — not just Phase 3 tools — so Phase 4 Renovate Bot setup has a complete file
- After each tool install, verify the installed binary's version matches the pinned version in versions.sh
- Idempotency: skip install if binary exists AND version matches pinned version; reinstall if version differs or binary is missing

### Binary install method
- All seven CLI tools installed from GitHub Releases (direct binary download) — consistent approach, no apt dependency, reproducible across distros
- Binaries land in `/usr/local/bin` (system-wide, all users)
- nvim installed as AppImage — single self-contained file, symlinked to `/usr/local/bin/nvim`
- Docker install method: Claude's discretion (use the most appropriate method for idempotent, reproducible server setup)

### Installer organization
- Split into two files: `scripts/install-tools.sh` (seven CLI tools) and `scripts/install-docker.sh` (Docker Engine + Compose + lazydocker)
- Individual function per tool: `install_ripgrep()`, `install_fd()`, `install_fzf()`, `install_eza()`, `install_bat()`, `install_delta()`, `install_nvim()`, `install_lazydocker()`
- Wired into `bootstrap.sh` the same way as `install-shell.sh` — direct source + function call

### Failure handling
- Claude's discretion on fail-fast vs collect-and-report (pick the most practical approach for server provisioning)

### Docker group membership and re-login
- Add bootstrap user to docker group, log a clear message that re-login is required, continue bootstrap
- Do NOT attempt `docker run hello-world` inside bootstrap — group membership won't be active yet
- Instead: verify Docker daemon is running with `systemctl is-active docker` as the in-bootstrap check

### Post-install verification
- Create `scripts/verify.sh` — operator runs this after re-login
- Verifies: `rg`, `fd`, `fzf`, `eza`, `bat`, `delta`, `nvim` (version check), `docker run hello-world`, `docker compose version`, `lazydocker` launches
- Reports pass/fail per tool

### Claude's Discretion
- Docker install method (official apt repo vs convenience script — pick what's most idempotent and secure)
- Failure handling strategy for individual tool install failures
- Exact AppImage mount/symlink approach for nvim

</decisions>

<specifics>
## Specific Ideas

- `lib/versions.sh` should be comprehensive — all tools across all phases — so Phase 4 can wire up Renovate Bot against a single file without needing to hunt down versions embedded in install scripts

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-cli-tools-and-docker*
*Context gathered: 2026-02-22*
