# Phase 1: Foundation - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Repo skeleton, bootstrap entrypoint (`bootstrap.sh`), shared helper libraries, and a pre-commit hook that prevents secrets from reaching the repo. Shell environment, tool installation, and security hardening are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Bootstrap output style
- Verbose by default — every step logged as it happens
- Color-coded output with icons: green checkmarks for success, red for errors, yellow for warnings
- Full summary at end of run: everything installed/configured, what was skipped (already present), any warnings
- `--dry-run` flag supported to preview actions without making changes

### Error handling behavior
- Fail fast — exit immediately on first error with a clear message
- On failure, attempt full cleanup: reset to pre-bootstrap state (undo all changes from all runs, not just the current run)
- Log errors only to a file in addition to terminal output

### Repo structure and layout
- Organized by function: `scripts/`, `config/`, `lib/`, `hooks/`
- Bootstrap entrypoint: `bootstrap.sh` at repo root (`curl <url>/bootstrap.sh | bash`)
- Shared helper libs split by topic: `lib/log.sh`, `lib/os.sh`, `lib/pkg.sh`, etc.
- Repo cloned to `~/.dotfiles` on the target server

### Secret prevention
- Use **gitleaks** for secret detection (100+ built-in patterns)
- When a secret is detected during a commit: block the commit and show the full gitleaks report (file, line, matched rule)
- Scan full git history on first setup/install — not just new commits going forward

### Claude's Discretion
- Whether to invoke gitleaks via a standalone pre-commit hook script or the pre-commit framework — choose what best fits a zero-Python-dependency target environment

</decisions>

<specifics>
## Specific Ideas

- No specific references mentioned — open to standard approaches for all areas above

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-22*
