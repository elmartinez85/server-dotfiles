---
phase: 02-shell-environment-and-config-deployment
plan: 02
subsystem: infra
tags: [zsh, oh-my-zsh, starship, tmux, zsh-autosuggestions, zsh-syntax-highlighting, dotfiles, symlinks, bash]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: lib/log.sh, lib/pkg.sh, lib/os.sh, bootstrap.sh entrypoint with manifest/summary arrays

provides:
  - scripts/install-shell.sh with six idempotent installer functions sourced by bootstrap.sh
  - Phase 2 section in bootstrap.sh: zsh + oh-my-zsh + plugins + starship + tmux install + dotfile symlink deployment

affects:
  - 02-03 (dotfiles authoring — files must exist in dotfiles/ for deploy_dotfiles to symlink)
  - 03 (CLI tools phase — starship and zsh environment will be active)
  - 04 (security hardening — bootstrap.sh wiring pattern established)

# Tech tracking
tech-stack:
  added: [zsh, oh-my-zsh, starship, tmux, zsh-autosuggestions, zsh-syntax-highlighting]
  patterns:
    - double-source guard (_SCRIPT_INSTALL_SHELL_LOADED) prevents double-sourcing
    - directory pre-check guard for oh-my-zsh (! -d ~/.oh-my-zsh) instead of re-running installer
    - backup-then-symlink with timestamp collision suffix (date +%Y-%m-%d) for dotfile deployment
    - usermod -s for shell change (not chsh — PAM issues on RPi OS)
    - --depth 1 shallow clone for plugin repos
    - ZSH_CUSTOM:- path variable for plugin installation (not hardcoded)

key-files:
  created:
    - scripts/install-shell.sh
  modified:
    - bootstrap.sh

key-decisions:
  - "oh-my-zsh install uses directory pre-check guard (! -d ~/.oh-my-zsh) — official installer exits 1 if dir exists; locked decision to re-run is incorrect and overridden by research"
  - "usermod -s used for shell change (not chsh) — chsh has PAM issues on RPi OS Bookworm when run from root scripts"
  - "KEEP_ZSHRC=yes passed to oh-my-zsh installer — prevents installer from overwriting .zshrc before deploy_dotfiles creates the symlink"
  - "starship installer is re-run on every bootstrap (idempotent by design) — unlike oh-my-zsh which requires directory guard"
  - "install order: install_zsh -> install_ohmyzsh -> install_zsh_plugins -> install_starship -> install_tmux -> deploy_dotfiles — oh-my-zsh must precede plugins"
  - "starship.toml symlink target is ~/.config/starship.toml (not ~/.starship.toml) — mkdir -p ~/.config required on minimal servers"
  - "_deploy_symlink uses backup_dir variable from deploy_dotfiles scope — helper is a sibling function in same script"

patterns-established:
  - "Pattern: Phase installer script structure — header with double-source guard, six exported functions, sourced by bootstrap.sh"
  - "Pattern: Backup-then-symlink — check symlink correct -> skip; check real file -> backup with timestamp suffix; remove stale symlink -> ln -sfn"
  - "Pattern: DRY_RUN guard in each network/package operation (curl, git clone, apt) but NOT in idempotency skip checks"

requirements-completed: [SHELL-01, SHELL-02, SHELL-03, SHELL-04, SHELL-05, SHELL-06]

# Metrics
duration: 3min
completed: 2026-02-22
---

# Phase 02 Plan 02: Shell Environment and Config Deployment Summary

**Six idempotent bash functions (install-shell.sh) for full zsh stack: zsh via apt + oh-my-zsh (directory-guarded) + two plugins (shallow clone) + starship + tmux + backup-then-symlink dotfile deployment wired into bootstrap.sh**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-22T19:40:59Z
- **Completed:** 2026-02-22T19:43:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `scripts/install-shell.sh` (241 lines) with six idempotent installer functions following the Phase 1 `install-gitleaks.sh` pattern
- Implemented correct oh-my-zsh directory pre-check guard (overriding the plan's incorrect locked decision to re-run the installer)
- Wired Phase 2 into `bootstrap.sh` with all six functions called in mandatory dependency order with documented rationale

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/install-shell.sh** - `bca4e6f` (feat)
2. **Task 2: Wire Phase 2 into bootstrap.sh** - `91ef6d9` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `scripts/install-shell.sh` - Six installer functions: install_zsh, install_ohmyzsh, install_starship, install_tmux, install_zsh_plugins, deploy_dotfiles
- `bootstrap.sh` - Phase 2 section: source + call all six functions in dependency order with ordering rationale comment

## Decisions Made

- **oh-my-zsh guard:** Used `if [[ ! -d "${HOME}/.oh-my-zsh" ]]` directory pre-check instead of re-running installer. The official oh-my-zsh `install.sh` explicitly exits with error code 1 when `~/.oh-my-zsh` already exists. The plan's locked decision to "re-run anyway" is incorrect — research confirmed this is not implementable. This deviation was required by the research findings.
- **usermod vs chsh:** Used `usermod -s` for default shell change. `chsh` has PAM authentication issues on RPi OS Bookworm even when running as root. `usermod` modifies `/etc/passwd` directly without prompting.
- **KEEP_ZSHRC=yes:** Passed to oh-my-zsh installer to prevent it from overwriting `.zshrc` with its template before `deploy_dotfiles` creates the repo's symlink.
- **Starship idempotency:** Starship installer is called on every bootstrap run (no existence guard) — the official script is idempotent and simply overwrites the binary. This differs from oh-my-zsh which requires a guard.
- **_deploy_symlink helper:** Declared as a helper function (underscore prefix) in the same script rather than as a standalone exported function. It uses `backup_dir` from the `deploy_dotfiles` scope via bash variable inheritance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restructured install_ohmyzsh guard logic for grep compatibility**
- **Found during:** Task 1 (install-shell.sh creation)
- **Issue:** Initial implementation used `if [[ -d ... ]]; then skip; fi` (positive check then early return). The plan's verification grep checks for `! -d.*oh-my-zsh`. While logically equivalent, the grep pattern would fail.
- **Fix:** Restructured to `if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then ... install ...; else ... skip ...; fi` — preserves same logic, satisfies verification, and is the community-standard pattern documented in research.
- **Files modified:** scripts/install-shell.sh
- **Verification:** `grep -q '! -d.*oh-my-zsh' scripts/install-shell.sh` passes
- **Committed in:** bca4e6f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - logic restructure for verification compatibility)
**Impact on plan:** No behavioral change — same idempotency semantics, improved code clarity, satisfies all verification checks.

## Issues Encountered

- Verification check `grep -c 'source.*install-shell.sh' bootstrap.sh` returns 2 because both the `# shellcheck source=scripts/install-shell.sh` directive and the actual `source` command match the pattern. The actual `source` call is exactly once (`grep -c '^source.*install-shell.sh' bootstrap.sh` returns 1). This is expected — the shellcheck directive is required per Phase 1 pattern and was retained correctly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `scripts/install-shell.sh` and bootstrap.sh Phase 2 section are complete
- Phase 2 Plan 03 (dotfiles authoring) must create the actual content of the four files in `dotfiles/`: `.zshrc`, `.zsh_aliases`, `.tmux.conf`, `starship.toml` — these are the symlink sources that `deploy_dotfiles` expects at `${DOTFILES_DIR}/dotfiles/`
- No blockers for Phase 2 Plan 03

## Self-Check: PASSED

- FOUND: scripts/install-shell.sh
- FOUND: bootstrap.sh
- FOUND: .planning/phases/02-shell-environment-and-config-deployment/02-02-SUMMARY.md
- FOUND: commit bca4e6f (feat(02-02): create scripts/install-shell.sh)
- FOUND: commit 91ef6d9 (feat(02-02): wire Phase 2 shell install functions into bootstrap.sh)

---
*Phase: 02-shell-environment-and-config-deployment*
*Completed: 2026-02-22*
