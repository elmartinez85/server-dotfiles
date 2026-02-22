---
phase: 01-foundation
plan: 03
subsystem: infra
tags: [bash, gitleaks, git-hooks, secret-scanning, security]

# Dependency graph
requires:
  - phase: 01-01
    provides: "lib/ directory structure, hooks/ directory, scripts/ directory (from repo skeleton)"
provides:
  - "hooks/pre-commit: source-controlled gitleaks pre-commit hook using gitleaks protect --staged --redact"
  - "scripts/install-gitleaks.sh: install_gitleaks(), install_pre_commit_hook(), scan_git_history() functions for sourcing by bootstrap.sh"
affects: [01-02-PLAN.md (bootstrap.sh sources this script), all future phases that commit to the repo]

# Tech tracking
tech-stack:
  added: [gitleaks 8.30.0 (static binary, no dependencies), curl with built-in --retry]
  patterns: [double-source guard in installer script, idempotency via binary version check and diff comparison, trap RETURN for tmpdir cleanup, git rev-parse --git-dir for portable hook path resolution]

key-files:
  created:
    - hooks/pre-commit
    - scripts/install-gitleaks.sh
  modified: []

key-decisions:
  - "gitleaks protect --staged --redact used for pre-commit (deprecated/hidden since v8.19.0 but confirmed functional in v8.30.0; pinned version controls surprises)"
  - "gitleaks git --source used for history scan (modern replacement for deprecated gitleaks detect)"
  - "ARCH variable consumed from bootstrap.sh env — not re-detected in install-gitleaks.sh"
  - "trap RETURN used for tmpdir cleanup inside install_gitleaks() — cleaner than explicit cleanup on every exit path"
  - "diff -q used for hook idempotency check — ensures re-running bootstrap updates an outdated hook"
  - "Download URL format: gitleaks_${GITLEAKS_VERSION}_linux_${ARCH}.tar.gz (matches GitHub Releases naming convention)"

patterns-established:
  - "Pattern: Double-source guard using _SCRIPT_*_LOADED variable (same convention as lib/*.sh files)"
  - "Pattern: GITLEAKS_VERSION pinned at top of file — single location to update for version bumps"
  - "Pattern: Idempotency via binary version string check before downloading (not just file existence)"
  - "Pattern: Manifest entries written in two formats: file:/path and hook:name:/path"
  - "Pattern: Functions append to _SUMMARY_INSTALLED and _SUMMARY_SKIPPED arrays declared in bootstrap.sh"

requirements-completed: [BOOT-04]

# Metrics
duration: 1min
completed: 2026-02-22
---

# Phase 1 Plan 03: Gitleaks Secret Prevention Summary

**Standalone bash pre-commit hook and idempotent gitleaks 8.30.0 installer with history scan — zero Python, zero framework, pure static binary**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-22T15:14:08Z
- **Completed:** 2026-02-22T15:15:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- hooks/pre-commit provides source-controlled gitleaks hook using `gitleaks protect --staged --redact`, blocking commits on secret detection with a clear user-actionable error message
- scripts/install-gitleaks.sh exports three functions (install_gitleaks, install_pre_commit_hook, scan_git_history) sourced by bootstrap.sh — not executed directly
- install_gitleaks() is fully idempotent: skips if gitleaks binary version string matches pinned 8.30.0
- install_pre_commit_hook() is idempotent via diff comparison — ensures outdated hooks get updated on re-run
- scan_git_history() uses `gitleaks git --source` (not deprecated `gitleaks detect`) for one-time history audit
- All three functions respect DRY_RUN and write manifest entries on successful install

## Task Commits

Each task was committed atomically:

1. **Task 1: Create hooks/pre-commit source-controlled hook** - `7cb1791` (feat)
2. **Task 2: Create scripts/install-gitleaks.sh installer** - `e64933f` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `hooks/pre-commit` - Source-controlled gitleaks pre-commit hook; copied to .git/hooks/pre-commit by bootstrap.sh; uses `gitleaks protect --staged --redact` and `command -v gitleaks`; marked executable
- `scripts/install-gitleaks.sh` - Sourced installer script; provides install_gitleaks(), install_pre_commit_hook(), scan_git_history(); double-source guard; GITLEAKS_VERSION pinned to 8.30.0

## Download URL Template

```
https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${ARCH}.tar.gz
```

Where `ARCH` is exported by bootstrap.sh (x86_64 or arm64), and `GITLEAKS_VERSION` is `8.30.0`.

## Manifest Entry Formats

Two formats written to `$MANIFEST_FILE` (path exported by bootstrap.sh):
- **Binary install:** `file:/usr/local/bin/gitleaks`
- **Hook install:** `hook:pre-commit:/path/to/.git/hooks/pre-commit`

These formats are available for future phases to extend (e.g., a cleanup/uninstall phase could parse them).

## Note on gitleaks protect Deprecation

`gitleaks protect --staged` was hidden/deprecated in v8.19.0 but remains functional in v8.30.0. The pinned version (`8.30.0`) controls surprises from upstream changes. If gitleaks removes this command in a future version, the pin is the only place to update and test.

For history scanning, `gitleaks detect` (the old command) is replaced by `gitleaks git --source .` — this plan uses the modern form.

## Decisions Made
- `gitleaks protect --staged --redact` confirmed functional in v8.30.0 despite deprecation notice — used because it is the correct staged-changes scanner
- `gitleaks git --source` used for history scan (not deprecated `gitleaks detect`)
- ARCH variable inherited from bootstrap.sh environment — install-gitleaks.sh does not re-detect arch
- `trap RETURN` pattern used inside install_gitleaks() for tmpdir cleanup — reliable regardless of how function exits
- `diff -q` used for hook idempotency — ensures an outdated hook gets replaced on re-run, not just skipped because the file exists

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- hooks/pre-commit and scripts/install-gitleaks.sh are ready to be referenced by bootstrap.sh (Plan 02)
- bootstrap.sh must export: ARCH, MANIFEST_FILE, DOTFILES_DIR, DRY_RUN, _SUMMARY_INSTALLED, _SUMMARY_SKIPPED before sourcing install-gitleaks.sh
- No blockers for Plan 02

---
*Phase: 01-foundation*
*Completed: 2026-02-22*

## Self-Check: PASSED

- FOUND: hooks/pre-commit
- FOUND: scripts/install-gitleaks.sh
- FOUND: .planning/phases/01-foundation/01-03-SUMMARY.md
- FOUND: commit 7cb1791 (Task 1: hooks/pre-commit)
- FOUND: commit e64933f (Task 2: scripts/install-gitleaks.sh)
