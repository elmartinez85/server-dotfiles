---
phase: 03-cli-tools-and-docker
plan: 02
subsystem: infra
tags: [bash, ripgrep, fd, fzf, eza, bat, delta, neovim, cli-tools, github-releases, architecture-mapping]

# Dependency graph
requires:
  - phase: 03-cli-tools-and-docker
    plan: 01
    provides: lib/versions.sh with RIPGREP_VERSION, FD_VERSION, FZF_VERSION, EZA_VERSION, BAT_VERSION, DELTA_VERSION, NVIM_VERSION
  - phase: 01-foundation
    provides: lib/log.sh (log_step, log_info, log_success, log_warn), lib/os.sh ($ARCH), bootstrap.sh globals ($MANIFEST_FILE, _SUMMARY_INSTALLED, _SUMMARY_SKIPPED, _SUMMARY_WARNINGS)
provides:
  - scripts/install-tools.sh with seven installer functions (install_ripgrep, install_fd, install_fzf, install_eza, install_bat, install_delta, install_nvim)
  - _arch_for_tool helper mapping $ARCH to per-tool GitHub Release URL naming conventions
  - _try_install soft-fail wrapper for bootstrap.sh to call tool installers without aborting on failure
affects:
  - 03-03 (install-docker.sh can reuse _try_install pattern)
  - bootstrap.sh wiring (source + _try_install calls per tool)

# Tech tracking
tech-stack:
  added: []
  patterns: [github-releases-binary-install, arch-mapping-helper, soft-fail-wrapper, flat-vs-subdir-archive-extraction]

key-files:
  created:
    - scripts/install-tools.sh
  modified: []

key-decisions:
  - "_try_install soft-fail wrapper chosen for per-tool failures: one bad download does not abort all remaining installs (Pitfall 8)"
  - "ripgrep/fd/bat/delta use separate libc case statement (musl for x86_64, gnu for arm64) — not handled by _arch_for_tool since libc differs per arch"
  - "delta URL has no 'v' prefix: uses ${version} not v${version} — unique among the seven tools"
  - "install_nvim uses $ARCH directly (not _arch_for_tool) since nvim naming matches canonical x86_64/arm64"
  - "fzf uses _arch_for_tool which maps x86_64 -> amd64 (fzf-specific naming convention)"
  - "fzf and eza are flat archives: binary at $tmpdir/{name}, not $tmpdir/{subdir}/{name}"

patterns-established:
  - "Arch mapping helper: _arch_for_tool centralizes per-tool URL naming differences; called once per function to avoid inline case duplication"
  - "Soft-fail pattern: _try_install wraps install functions so set -eEuo pipefail in bootstrap.sh does not abort on single tool failure"
  - "Flat vs subdir archive: flat archives (fzf, eza) install from ${tmpdir}/binary; subdir archives (rg, fd, bat, delta, nvim) install from ${tmpdir}/${subdir}/binary"

requirements-completed: [TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05, TOOL-06, TOOL-07]

# Metrics
duration: 1min
completed: 2026-02-22
---

# Phase 3 Plan 02: CLI Tools Installer Summary

**Seven GitHub Releases binary installers for ripgrep, fd, fzf, eza, bat, delta, and neovim with architecture-aware URL mapping, idempotency, DRY_RUN support, and soft-fail error handling**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-22T20:46:35Z
- **Completed:** 2026-02-22T20:47:54Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created scripts/install-tools.sh (409 lines) with all seven install functions sourcing lib/versions.sh for version numbers
- Implemented _arch_for_tool helper mapping $ARCH (x86_64/arm64) to tool-specific URL naming (fzf uses amd64/arm64, ripgrep/fd/bat/delta use x86_64/aarch64, nvim uses $ARCH directly)
- Implemented _try_install soft-fail wrapper so one tool download failure does not abort the entire bootstrap under set -eEuo pipefail
- Correctly handled flat archives (fzf: `fzf`, eza: `./eza`) vs subdirectory archives (rg, fd, bat, delta: `{subdir}/{name}`, nvim: `nvim-linux-{ARCH}/bin/nvim`)
- Applied musl/gnu libc split for x86_64/arm64 on ripgrep, fd, bat, and delta
- Used tarball (not AppImage) for neovim — avoids FUSE dependency on headless servers

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/install-tools.sh with seven CLI tool installer functions** - `7c9d42d` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `scripts/install-tools.sh` - Seven CLI tool installers with _arch_for_tool helper and _try_install soft-fail wrapper; sourced by bootstrap.sh

## Decisions Made

- Used `_try_install` soft-fail wrapper (not direct calls) so each tool's failure is caught and appended to `_SUMMARY_WARNINGS` rather than aborting bootstrap — aligns with the soft-fail recommendation in RESEARCH.md Pitfall 8
- Kept libc mapping (musl/gnu) in a separate case statement within each function rather than extending _arch_for_tool — the libc split is a download decision, not just an arch naming decision, and mixing it into _arch_for_tool would obscure intent
- delta uses `${version}` (not `v${version}`) in the release URL — documented prominently in a code comment since this is the only tool that deviates from the v-prefix pattern
- install_nvim uses `$ARCH` directly rather than calling `_arch_for_tool nvim` — the result is identical but the direct reference is clearer about nvim's URL convention matching the canonical arch names

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- scripts/install-tools.sh is ready to be sourced and wired into bootstrap.sh
- Plan 03 (install-docker.sh) can reuse the _try_install pattern from this file
- All seven TOOL-0x requirements are satisfied
- No blockers for the next plan

---
## Self-Check: PASSED

- FOUND: scripts/install-tools.sh
- FOUND: .planning/phases/03-cli-tools-and-docker/03-02-SUMMARY.md
- FOUND commit: 7c9d42d (feat(03-02): create scripts/install-tools.sh)

---
*Phase: 03-cli-tools-and-docker*
*Completed: 2026-02-22*
