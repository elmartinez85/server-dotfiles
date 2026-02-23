---
phase: 03-cli-tools-and-docker
plan: 04
subsystem: infra
tags: [bash, verify, bootstrap, docker, cli-tools, integration, post-relogin]

# Dependency graph
requires:
  - phase: 03-cli-tools-and-docker
    plan: 01
    provides: lib/versions.sh with all TOOL and LAZYDOCKER version variables
  - phase: 03-cli-tools-and-docker
    plan: 02
    provides: scripts/install-tools.sh with seven install functions and _try_install soft-fail wrapper
  - phase: 03-cli-tools-and-docker
    plan: 03
    provides: scripts/install-docker.sh with install_docker_engine, verify_docker_running, add_user_to_docker_group, install_lazydocker
provides:
  - scripts/verify.sh — operator runs after re-login to confirm all Phase 3 binaries and Docker group membership are working
  - bootstrap.sh Phase 3 wiring — sources install-tools.sh and install-docker.sh, calls all eleven Phase 3 functions with correct soft-fail/hard-fail strategy
affects:
  - Phase 4 (install-security.sh wiring will follow same source + call pattern below the Phase 4 placeholder)

# Tech tracking
tech-stack:
  added: []
  patterns: [post-relogin-verification-script, hard-fail-vs-soft-fail-strategy, bootstrap-wiring-pattern]

key-files:
  created:
    - scripts/verify.sh
  modified:
    - bootstrap.sh

key-decisions:
  - "verify.sh sources lib/versions.sh rather than hardcoding versions — stays in sync automatically when lib/versions.sh is updated"
  - "verify.sh uses BASH_SOURCE[0]-relative SCRIPT_DIR detection — works regardless of the operator's current working directory"
  - "install_docker_engine called without _try_install (hard-fail) — Docker Engine is core infrastructure; bootstrap aborting on Docker failure is correct behavior"
  - "install_lazydocker wrapped in _try_install (soft-fail) — it is a convenience TUI tool; a failed download must not block the rest of bootstrap"
  - "verify.sh does not exit on first failure — accumulates PASS/FAIL counts and reports all results before exiting 1 if any failed"

patterns-established:
  - "Post-relogin verification pattern: separate verify.sh that the operator runs manually after bootstrap completes, covering items that require group re-login (docker run without sudo)"
  - "Hard-fail vs soft-fail wiring: critical infrastructure (Docker Engine) called directly; optional tools called via _try_install"
  - "shellcheck source= directives on all source lines in bootstrap.sh — matches existing Phase 1/2 pattern"

requirements-completed: [TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05, TOOL-06, TOOL-07, DOCK-01, DOCK-02, DOCK-03, DOCK-04]

# Metrics
duration: 1min
completed: 2026-02-22
---

# Phase 3 Plan 04: Bootstrap Wiring and Post-Relogin Verification Summary

**scripts/verify.sh sourcing lib/versions.sh to check all seven CLI tools and three Docker items (hello-world, compose, lazydocker) after re-login; bootstrap.sh Phase 3 block sources install-tools.sh and install-docker.sh with correct hard-fail/soft-fail strategy**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-22T20:53:34Z
- **Completed:** 2026-02-22T20:54:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created scripts/verify.sh (75 lines) that sources lib/versions.sh, uses check_binary helper, tests all seven CLI tools by version string match, and tests docker run hello-world + docker compose version + lazydocker binary; exits 0 only if all pass
- Wired Phase 3 into bootstrap.sh by replacing the placeholder comment with source + call blocks for install-tools.sh (seven _try_install calls) and install-docker.sh (install_docker_engine hard-fail, verify_docker_running, add_user_to_docker_group, _try_install install_lazydocker)
- Phase 4 placeholder comment preserved intact

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/verify.sh — operator post-relogin verification** - `784bef1` (feat)
2. **Task 2: Wire Phase 3 scripts into bootstrap.sh** - `87ebfd9` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `scripts/verify.sh` - Operator post-relogin verification: sources lib/versions.sh, check_binary helper, 7 CLI tools + docker run hello-world + docker compose version + lazydocker; exits 0 only if all pass
- `bootstrap.sh` - Phase 3 wiring: source install-tools.sh + seven _try_install calls; source install-docker.sh + install_docker_engine (hard-fail) + verify_docker_running + add_user_to_docker_group + _try_install install_lazydocker

## Decisions Made

- verify.sh uses `BASH_SOURCE[0]`-relative path detection for DOTFILES_DIR — the script may be run from any working directory after re-login, so DOTFILES_DIR cannot be assumed from `$HOME`
- verify.sh accumulates PASS/FAIL counts rather than exiting on first failure — operators need to see all results in one pass to know exactly what needs attention post-relogin
- install_docker_engine is a hard-fail call (no _try_install wrapper) — if Docker Engine fails to install, bootstrap should abort under set -eEuo pipefail since subsequent phases may depend on Docker
- install_lazydocker is wrapped in _try_install — it is a convenience TUI overlay, not core infrastructure; a network blip downloading it must not prevent bootstrap completion

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 is fully complete: lib/versions.sh, install-tools.sh, install-docker.sh, verify.sh, and bootstrap.sh wiring are all in place
- The operator can now run `bash ~/.dotfiles/bootstrap.sh` to provision a server, then re-login and run `bash ~/.dotfiles/scripts/verify.sh` to confirm all tools
- Phase 4 (Security hardening) can add `source "${DOTFILES_DIR}/scripts/install-security.sh"` immediately below the Phase 4 placeholder comment in bootstrap.sh
- All TOOL-0x and DOCK-0x requirements are satisfied

---
## Self-Check: PASSED

- FOUND: scripts/verify.sh
- FOUND: bootstrap.sh
- FOUND: .planning/phases/03-cli-tools-and-docker/03-04-SUMMARY.md
- FOUND commit: 784bef1 (feat(03-04): create scripts/verify.sh)
- FOUND commit: 87ebfd9 (feat(03-04): wire Phase 3 CLI tools and Docker into bootstrap.sh)

---
*Phase: 03-cli-tools-and-docker*
*Completed: 2026-02-22*
