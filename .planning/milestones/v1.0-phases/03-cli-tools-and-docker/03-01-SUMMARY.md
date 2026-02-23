---
phase: 03-cli-tools-and-docker
plan: 01
subsystem: infra
tags: [bash, versions, version-store, gitleaks, cli-tools, docker]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: scripts/install-gitleaks.sh with hardcoded GITLEAKS_VERSION
provides:
  - lib/versions.sh with all nine pinned tool versions (gitleaks + 7 CLI tools + lazydocker)
  - install-gitleaks.sh updated to source lib/versions.sh
affects:
  - 03-02 (install-tools.sh must source lib/versions.sh)
  - 03-03 (install-docker.sh must source lib/versions.sh)
  - 04-renovate-bot (targets lib/versions.sh as single version file)

# Tech tracking
tech-stack:
  added: []
  patterns: [idempotency-guard, canonical-version-store, source-lib-pattern]

key-files:
  created:
    - lib/versions.sh
  modified:
    - scripts/install-gitleaks.sh

key-decisions:
  - "lib/versions.sh uses same idempotency guard pattern as lib/log.sh and lib/os.sh (_LIB_VERSIONS_LOADED guard)"
  - "Variables in lib/versions.sh are NOT exported — sourcing scripts assign as globals/locals as needed (matches existing lib/ convention)"
  - "GITLEAKS_INSTALL_PATH kept as module-level var in install-gitleaks.sh — only GITLEAKS_VERSION was removed (version sourced, path is not a version concern)"

patterns-established:
  - "Version store pattern: lib/versions.sh is the single source of truth — all install scripts source it, never hardcode versions"
  - "Idempotency guard: if [[ -n \"${_LIB_VERSIONS_LOADED:-}\" ]]; then return 0; fi pattern prevents double-source side effects"

requirements-completed: [MAINT-01]

# Metrics
duration: 1min
completed: 2026-02-22
---

# Phase 3 Plan 01: Version Store Summary

**lib/versions.sh created as canonical version store with all nine pinned versions; install-gitleaks.sh updated to source it, eliminating the only hardcoded version in the codebase**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-22T20:43:10Z
- **Completed:** 2026-02-22T20:44:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created lib/versions.sh with idempotency guard and all nine version variables across three labeled sections (Phase 1, Phase 3 CLI tools, Phase 3 Docker tools)
- Removed hardcoded GITLEAKS_VERSION from install-gitleaks.sh; replaced with source call to lib/versions.sh
- Phase 4 Renovate Bot now has a single file to target for automated version PRs

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/versions.sh** - `18c0ef1` (feat)
2. **Task 2: Update install-gitleaks.sh to source versions.sh** - `9f05142` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `lib/versions.sh` - Canonical version store: GITLEAKS_VERSION, RIPGREP_VERSION, FD_VERSION, FZF_VERSION, EZA_VERSION, BAT_VERSION, DELTA_VERSION, NVIM_VERSION, LAZYDOCKER_VERSION
- `scripts/install-gitleaks.sh` - Removed hardcoded GITLEAKS_VERSION; added source call to lib/versions.sh

## Decisions Made

- Used the same idempotency guard pattern (`_LIB_VERSIONS_LOADED`) as lib/log.sh and lib/os.sh for consistency
- Variables are NOT exported in lib/versions.sh — matches the existing lib/ convention where export happens in the caller if needed
- GITLEAKS_INSTALL_PATH kept as a module-level variable in install-gitleaks.sh since it is not a version concern and was already there

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- lib/versions.sh is ready to be sourced by install-tools.sh (Plan 02) and install-docker.sh (Plan 03)
- All nine version variables are available and verified
- No blockers for the next plan

---
## Self-Check: PASSED

- FOUND: lib/versions.sh
- FOUND: scripts/install-gitleaks.sh
- FOUND: .planning/phases/03-cli-tools-and-docker/03-01-SUMMARY.md
- FOUND commit: 18c0ef1 (feat: lib/versions.sh)
- FOUND commit: 9f05142 (feat: install-gitleaks.sh update)

---
*Phase: 03-cli-tools-and-docker*
*Completed: 2026-02-22*
