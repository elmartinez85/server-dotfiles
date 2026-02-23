# Phase 1: Foundation - Research

**Researched:** 2026-02-22
**Domain:** Bash bootstrap scripting, repo structure, secret scanning
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Bootstrap output style:** Verbose by default — every step logged as it happens; color-coded with icons (green checkmarks for success, red for errors, yellow for warnings); full summary at end; `--dry-run` flag supported
- **Error handling behavior:** Fail fast — exit immediately on first error with a clear message; on failure, attempt full cleanup (reset to pre-bootstrap state, undo all changes from all runs, not just the current run); log errors only to a file in addition to terminal output
- **Repo structure and layout:** Organized by function: `scripts/`, `config/`, `lib/`, `hooks/`; bootstrap entrypoint: `bootstrap.sh` at repo root; shared helper libs split by topic: `lib/log.sh`, `lib/os.sh`, `lib/pkg.sh`, etc.; repo cloned to `~/.dotfiles` on target server
- **Secret prevention:** Use gitleaks for secret detection (100+ built-in patterns); when a secret is detected during a commit: block the commit and show the full gitleaks report (file, line, matched rule); scan full git history on first setup/install — not just new commits going forward

### Claude's Discretion

- Whether to invoke gitleaks via a standalone pre-commit hook script or the pre-commit framework — choose what best fits a zero-Python-dependency target environment

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BOOT-01 | User can bootstrap a fresh server with a single `curl \| bash` command | curl-pipe-bash pattern, stdin/tty considerations, bootstrap.sh entrypoint design |
| BOOT-02 | Bootstrap script is idempotent — safe to re-run on an existing server without side effects | Idempotency patterns: pre-existence checks, safe flags (mkdir -p, ln -sfn), guard conditions |
| BOOT-03 | Bootstrap script detects OS architecture (x86_64 and ARM64) and installs appropriate binaries | `uname -m` case statement, aarch64 vs arm64 naming difference |
| BOOT-04 | Repository enforces a pre-commit hook to prevent secrets from being committed | gitleaks v8.30.0, standalone bash pre-commit hook (no Python/pre-commit framework), `gitleaks git` for history scan |
</phase_requirements>

---

## Summary

Phase 1 establishes the skeleton from which all future phases operate. There are four distinct technical problems: (1) a `curl | bash` bootstrap entrypoint that starts the repo clone and setup sequence, (2) idempotency so re-runs are safe, (3) architecture detection for binary selection, and (4) secret prevention via a gitleaks pre-commit hook. All four are well-understood problems with clear, lightweight solutions in pure bash — no external frameworks required.

The largest area of care is the error handling + cleanup contract: the user requires that a failed run undo ALL changes from ALL prior runs, not just the current run. This is more aggressive than typical "cleanup on failure" patterns and requires tracking a persistent state of what has been installed so it can be undone. A simple approach is a manifest file (e.g., `~/.dotfiles/.installed`) that records actions, read by the cleanup function.

The gitleaks discretion question resolves clearly: the standalone bash hook is the right choice. The `pre-commit` framework requires Python, which violates the zero-dependency constraint for the target server environment (bare Ubuntu/RPi). A pure bash script at `.git/hooks/pre-commit` using `gitleaks protect --staged` is the established pattern.

**Primary recommendation:** Use `set -eEuo pipefail` + `trap cleanup EXIT` for error handling; track installed state in a manifest file for full rollback; use `uname -m` case statement for arch detection; install gitleaks via direct GitHub Releases binary download and invoke via a standalone bash pre-commit hook.

---

## Standard Stack

### Core

| Tool/Pattern | Version | Purpose | Why Standard |
|---|---|---|---|
| bash | 5.x (system) | Script interpreter | Universally available on Ubuntu/RPi; zero install dependency |
| gitleaks | v8.30.0 | Secret detection in pre-commit hook and history scan | 100+ built-in patterns, single static binary, ARM64+amd64 releases, MIT licensed |
| `set -eEuo pipefail` | bash built-in | Fail fast + unset variable safety + pipeline error propagation | Industry standard for robust bash scripts |
| `trap ... EXIT/ERR` | bash built-in | Cleanup and error handler invocation | Runs on any exit path including signals |
| `uname -m` | coreutils | Architecture detection | Standard POSIX utility, available everywhere |

### Supporting

| Tool/Pattern | Version | Purpose | When to Use |
|---|---|---|---|
| `tee` | coreutils | Dual output (terminal + log file) | Used in log.sh to write to both stdout and log file |
| `git rev-parse --git-dir` | git built-in | Locate .git/hooks/ reliably | Used in hook installer; handles submodules and worktrees |
| ANSI escape codes | terminal standard | Color output in log.sh | When stdout is a TTY (`[ -t 1 ]`) |
| `command -v` | bash built-in | Check if a binary is available | Idempotency guard and dependency check |
| `mkdir -p` | coreutils | Idempotent directory creation | Always use instead of bare `mkdir` |

### Alternatives Considered (and Rejected)

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| Standalone bash hook | `pre-commit` framework | Requires Python — violates zero-dependency constraint for bare servers |
| Direct binary install | `apt install gitleaks` | Apt package may lag behind; no version pinning control |
| Manual arch switch | `dpkg --print-architecture` | Returns Debian naming (amd64) not upstream naming; `uname -m` is more universal |
| Manifest-tracked rollback | OS snapshots only | User explicitly requested bootstrap-level cleanup, not OS-level |

**No installation command** — this phase is pure bash and git tooling; gitleaks is a single binary copied to `/usr/local/bin/` or `~/.local/bin/`.

---

## Architecture Patterns

### Recommended Project Structure

```
bootstrap.sh              # Entrypoint — curl | bash target
lib/
├── log.sh                # Logging: log_info, log_success, log_warn, log_error, log_step
├── os.sh                 # OS/arch detection: detect_arch, detect_os, require_root
└── pkg.sh                # Package helpers: pkg_installed, pkg_install (idempotent apt wrapper)
scripts/
├── install-gitleaks.sh   # Installs gitleaks binary; sets up pre-commit hook
└── (future phases)
hooks/
└── pre-commit            # Source-controlled hook script (copied to .git/hooks/ on install)
config/                   # (empty in phase 1; used from phase 2 onward)
```

Notes:
- `bootstrap.sh` at repo root is the `curl | bash` target (per user decision)
- `lib/` contains sourced helper libraries, never executed directly
- `hooks/` contains the versioned hook scripts; separate from `.git/hooks/` (which is not version-controlled)
- The bootstrap installs itself by cloning the repo to `~/.dotfiles`, then invoking the phase scripts in order

### Pattern 1: Bash Library Sourcing with Guard Against Double-Source

**What:** Each `lib/*.sh` file declares a guard variable to prevent re-execution if sourced multiple times.
**When to use:** Always, in every lib file.

```bash
# lib/log.sh
if [[ -n "${_LIB_LOG_LOADED:-}" ]]; then return 0; fi
_LIB_LOG_LOADED=1

# --- implementation follows ---
```

All functions in `lib/log.sh` use the `log_` prefix; functions in `lib/os.sh` use `os_`; functions in `lib/pkg.sh` use `pkg_`. This is the bash namespace convention because bash has no native namespacing.

Source from scripts like:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/log.sh"
source "${SCRIPT_DIR}/../lib/os.sh"
```

### Pattern 2: Fail Fast with Full Cleanup via trap EXIT

**What:** Bootstrap sets `set -eEuo pipefail` at the top, registers a cleanup function via `trap`, and the cleanup function reads from a persistent manifest to undo all installed state.
**When to use:** `bootstrap.sh` and any script that modifies system state.

```bash
#!/usr/bin/env bash
set -eEuo pipefail

MANIFEST_FILE="${HOME}/.dotfiles/.installed"
CLEANUP_STACK=()

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Bootstrap failed. Cleaning up all installed state..."
    # Read manifest in reverse order and undo each step
    if [[ -f "$MANIFEST_FILE" ]]; then
      mapfile -t steps < "$MANIFEST_FILE"
      local i
      for (( i=${#steps[@]}-1; i>=0; i-- )); do
        undo_step "${steps[$i]}" || true
      done
      rm -f "$MANIFEST_FILE"
    fi
  fi
}
trap cleanup EXIT
```

The manifest file records completed actions in a simple format (e.g., `file:/usr/local/bin/gitleaks`, `hook:pre-commit`). The `undo_step` function interprets each prefix and reverses the action. This satisfies the "undo ALL changes from ALL runs" requirement because the manifest persists across runs.

### Pattern 3: Idempotency Guards

**What:** Before any action, check if it is already done. If done, skip with a log message.
**When to use:** Every install/configure step.

```bash
# Install a binary only if not already present at the right version
install_gitleaks() {
  local target_version="$1"
  local install_path="/usr/local/bin/gitleaks"

  if [[ -x "$install_path" ]]; then
    local installed_version
    installed_version="$("$install_path" version 2>/dev/null || echo "unknown")"
    if [[ "$installed_version" == *"${target_version}"* ]]; then
      log_info "gitleaks ${target_version} already installed — skipping"
      return 0
    fi
  fi
  # ... proceed with install
}
```

Key idempotent bash patterns:
- `mkdir -p` — never errors if directory exists
- `ln -sfn` — force-replace symlink safely
- `rm -f` — no error if file absent
- `command -v binary` — check if installed before installing
- `grep -q "pattern" file` — check before appending to config files
- `[ -f "/path" ]`, `[ -d "/path" ]`, `[ -x "$(command -v bin)" ]` — state checks

### Pattern 4: Architecture Detection

**What:** `uname -m` returns the machine hardware name. Linux ARM64 servers return `aarch64`; macOS ARM returns `arm64`. Both map to the same gitleaks binary name (`arm64`).

```bash
# lib/os.sh
os_detect_arch() {
  local raw
  raw="$(uname -m)"
  case "$raw" in
    x86_64)         echo "x86_64" ;;
    aarch64|arm64)  echo "arm64" ;;
    *)
      log_error "Unsupported architecture: $raw"
      return 1
      ;;
  esac
}
```

Export this as `ARCH` at bootstrap start:
```bash
ARCH="$(os_detect_arch)"
export ARCH
```

Then use `$ARCH` everywhere binary URLs are constructed (gitleaks, and all future tool installs in later phases).

### Pattern 5: Colored Logging with TTY Detection

**What:** Colors are only emitted when stdout is a terminal. When piped (e.g., `curl | bash` scenario where output may be captured), ANSI codes are suppressed.

```bash
# lib/log.sh
if [[ -t 1 ]]; then
  _RED="\033[0;31m"
  _GREEN="\033[0;32m"
  _YELLOW="\033[0;33m"
  _BLUE="\033[0;34m"
  _BOLD="\033[1m"
  _RESET="\033[0m"
else
  _RED="" _GREEN="" _YELLOW="" _BLUE="" _BOLD="" _RESET=""
fi

log_info()    { echo -e "${_BLUE}  [INFO]${_RESET} $*"; }
log_success() { echo -e "${_GREEN}  [OK]${_RESET} $*"; }
log_warn()    { echo -e "${_YELLOW}  [WARN]${_RESET} $*"; }
log_error()   { echo -e "${_RED}  [ERROR]${_RESET} $*" >&2; }
log_step()    { echo -e "${_BOLD}==> $*${_RESET}"; }
```

Dual output (terminal + log file):
```bash
LOG_FILE="${HOME}/.dotfiles/bootstrap.log"
# At top of bootstrap.sh, after setup:
exec > >(tee -a "$LOG_FILE") 2>&1
```

This redirects all subsequent output through `tee`, so terminal output and log file are always in sync. Errors go to log because `2>&1` funnels stderr into the same stream.

### Pattern 6: --dry-run Flag

**What:** Parse `--dry-run` from `$@` at the top of bootstrap.sh. Pass `DRY_RUN=true` as an exported variable. Each action-performing function checks the flag before executing.

```bash
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done
export DRY_RUN

# In action functions:
run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would run: $*"
    return 0
  fi
  "$@"
}
```

### Pattern 7: Gitleaks Standalone Pre-Commit Hook

**What:** A pure bash script at `.git/hooks/pre-commit` that runs `gitleaks protect --staged --redact`. No Python, no `pre-commit` framework.

```bash
#!/usr/bin/env bash
# hooks/pre-commit — source-controlled; installed by bootstrap

set -euo pipefail

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks not found. Run bootstrap to install it." >&2
  exit 1
fi

gitleaks protect --staged --redact
```

The bootstrap copies this from `hooks/pre-commit` to `.git/hooks/pre-commit` and marks it executable:
```bash
HOOK_DIR="$(git rev-parse --git-dir)/hooks"
cp "${DOTFILES_DIR}/hooks/pre-commit" "${HOOK_DIR}/pre-commit"
chmod +x "${HOOK_DIR}/pre-commit"
```

**Full history scan** (run once on first setup, not on every commit):
```bash
gitleaks git --source . --verbose
```

Note: `gitleaks detect` and `gitleaks protect` are deprecated in v8.19.0+ (hidden from `--help`). The replacement commands are `gitleaks git` (replaces `detect`) and `gitleaks protect` (still valid for staged check, but flag behavior changed). The pre-commit hook using `gitleaks protect --staged --redact` still works as of v8.30.0. For new scripts, prefer `gitleaks git` for history scans.

### Anti-Patterns to Avoid

- **`mkdir` without `-p`:** Fails if directory exists — breaks idempotency.
- **`ln -s` without `-f`:** Fails if symlink target already exists.
- **Appending to config files without grep guard:** Creates duplicate entries on re-run.
- **`set -e` without `set -E`:** Error traps in functions don't propagate to the parent trap. Always pair as `set -eEuo pipefail`.
- **`trap cleanup ERR` only:** Won't fire on `exit 0`. Use `trap cleanup EXIT` and check `$?` inside the function.
- **Hardcoded `aarch64` string for ARM:** Linux uses `aarch64`, macOS uses `arm64`. Use a case statement to normalize both to a single canonical value.
- **`#!/bin/bash` shebang:** Prefer `#!/usr/bin/env bash` for portability; some minimal systems put bash in `/usr/local/bin/`.
- **`echo` for error messages without `>&2`:** Error messages must go to stderr so they aren't captured by stdout redirection.
- **Checking for gitleaks with `which`:** `which` is not POSIX and behaves inconsistently. Use `command -v gitleaks`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secret pattern detection | Custom regex list | gitleaks v8.30.0 | 100+ maintained patterns, entropy analysis, git-aware; custom regex misses most real-world secret formats |
| Retry on download failure | Custom retry loop | `curl --retry 3 --retry-delay 2` | curl has built-in retry with exponential options; don't reimplement |
| Pre-commit framework | Shell orchestrator for multiple hooks | Standalone bash script (this phase only has gitleaks) | Pre-commit framework adds Python dependency; single-hook case doesn't need orchestration |
| Color detection | Parse $TERM manually | `[ -t 1 ]` TTY check | Simple and correct; $TERM parsing is fragile |

**Key insight:** The secret detection problem is deceptively complex — entropy-based detection, thousands of real-world patterns, git history traversal. gitleaks solves all of this; anything hand-rolled will miss common patterns within days of deployment.

---

## Common Pitfalls

### Pitfall 1: `curl | bash` Breaks stdin

**What goes wrong:** When `curl <url> | bash` runs, bash's stdin is the curl output (the script), not the terminal. Any `read` prompts inside the script hang forever or receive EOF immediately.
**Why it happens:** Bash receives the script over stdin, so stdin is not the user's keyboard.
**How to avoid:** Never use `read` inside bootstrap.sh. All configuration must come from environment variables or flags. The `--dry-run` flag is passed as a shell argument, not a prompt. If interactive input is ever needed, detect the pipe condition with `[ -t 0 ]` and error out with a clear message explaining that stdin is piped.
**Warning signs:** Any `read -p` or interactive prompt in the bootstrap path.

### Pitfall 2: `uname -m` Returns `aarch64` on Linux, `arm64` on macOS

**What goes wrong:** A case statement with only `arm64)` misses Linux ARM64 servers, which report `aarch64`.
**Why it happens:** Linux kernel convention uses `aarch64`; macOS Apple Silicon uses `arm64`. Both refer to the same ISA.
**How to avoid:** Always handle both in the case statement: `aarch64|arm64) echo "arm64" ;;`
**Warning signs:** The gitleaks download URL construction failing on RPi/Ubuntu ARM servers.

### Pitfall 3: Cleanup Runs on Success Too

**What goes wrong:** `trap cleanup EXIT` fires on every exit, including successful completion. If the cleanup function unconditionally deletes installed files, it undoes successful work.
**Why it happens:** EXIT trap fires regardless of exit code.
**How to avoid:** Inside the cleanup function, check `$?` (captured before any cleanup commands alter it): `local exit_code=$?`. Only perform destructive cleanup if `exit_code -ne 0`.
**Warning signs:** Installed files disappearing after a successful run.

### Pitfall 4: gitleaks detect/protect Deprecation

**What goes wrong:** Scripts using `gitleaks detect` or `gitleaks protect` without awareness of deprecation may break if those commands are eventually removed.
**Why it happens:** v8.19.0 deprecated and hid these commands from help menus.
**How to avoid:** For history scanning, use `gitleaks git --source .` (the modern replacement for `gitleaks detect`). For pre-commit staged scanning, `gitleaks protect --staged` still works as of v8.30.0 — but document this dependency and monitor releases.
**Warning signs:** `gitleaks --help` not showing `detect` or `protect` subcommands.

### Pitfall 5: The Manifest File Location

**What goes wrong:** The manifest tracking installed state is placed inside `.git/` or `/tmp/`, making it non-persistent across re-runs or easy to accidentally delete.
**Why it happens:** Choosing a convenient path without thinking about persistence and visibility.
**How to avoid:** Place the manifest at `~/.dotfiles/.installed` (inside the cloned repo directory). It is gitignored (add to `.gitignore`). It persists across runs and is tied to the dotfiles installation.
**Warning signs:** Cleanup on failure failing to undo actions from a previous run.

### Pitfall 6: gitleaks Binary Architecture Mismatch

**What goes wrong:** Downloading the `linux_x64` gitleaks binary on an ARM64 server produces a binary that fails with `Exec format error`.
**Why it happens:** Architecture not detected before constructing the download URL.
**How to avoid:** Always detect `ARCH` before constructing download URLs. Construct the gitleaks filename as: `gitleaks_${GITLEAKS_VERSION}_linux_${ARCH}.tar.gz` where `ARCH` is the normalized value from `os_detect_arch()`.
**Warning signs:** `Exec format error` when running gitleaks after install.

---

## Code Examples

Verified patterns from official sources and verified search results:

### bootstrap.sh Skeleton

```bash
#!/usr/bin/env bash
# bootstrap.sh — curl <url>/bootstrap.sh | bash
set -eEuo pipefail

DOTFILES_REPO="https://github.com/<user>/server-dotfiles.git"
DOTFILES_DIR="${HOME}/.dotfiles"
LOG_FILE="${DOTFILES_DIR}/bootstrap.log"
MANIFEST_FILE="${DOTFILES_DIR}/.installed"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in --dry-run) DRY_RUN=true ;; esac
done
export DRY_RUN

# Source libs (after repo is cloned)
# shellcheck source=lib/log.sh
source "${DOTFILES_DIR}/lib/log.sh"
source "${DOTFILES_DIR}/lib/os.sh"
source "${DOTFILES_DIR}/lib/pkg.sh"

# Redirect all output through tee to log file
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Bootstrap failed (exit $exit_code). Reverting installed state..."
    # ... read manifest in reverse and undo
  fi
}
trap cleanup EXIT

ARCH="$(os_detect_arch)"
export ARCH

log_step "Starting bootstrap (arch: ${ARCH}, dry-run: ${DRY_RUN})"
# ... source and run phase scripts
```

### gitleaks Binary Download

```bash
# scripts/install-gitleaks.sh
GITLEAKS_VERSION="8.30.0"
GITLEAKS_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${ARCH}.tar.gz"
INSTALL_PATH="/usr/local/bin/gitleaks"

install_gitleaks() {
  if [[ -x "$INSTALL_PATH" ]] && "$INSTALL_PATH" version 2>/dev/null | grep -q "$GITLEAKS_VERSION"; then
    log_info "gitleaks ${GITLEAKS_VERSION} already installed — skipping"
    return 0
  fi

  log_step "Installing gitleaks ${GITLEAKS_VERSION} (${ARCH})"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    "$GITLEAKS_URL" | tar -xz -C "$tmpdir"

  install -m 755 "${tmpdir}/gitleaks" "$INSTALL_PATH"
  log_success "gitleaks installed at ${INSTALL_PATH}"
  echo "file:${INSTALL_PATH}" >> "$MANIFEST_FILE"
}
```

### Pre-Commit Hook Installation

```bash
install_pre_commit_hook() {
  local hook_src="${DOTFILES_DIR}/hooks/pre-commit"
  local hook_dst
  hook_dst="$(git -C "$DOTFILES_DIR" rev-parse --git-dir)/hooks/pre-commit"

  if [[ -f "$hook_dst" ]]; then
    log_info "pre-commit hook already installed — skipping"
    return 0
  fi

  cp "$hook_src" "$hook_dst"
  chmod +x "$hook_dst"
  log_success "pre-commit hook installed"
  echo "hook:pre-commit:${hook_dst}" >> "$MANIFEST_FILE"
}
```

### Full History Scan (run once on first setup)

```bash
scan_git_history() {
  log_step "Scanning full git history for secrets..."
  if ! gitleaks git --source "$DOTFILES_DIR" --verbose; then
    log_error "Secrets found in git history. See above for details."
    log_error "Remove the secrets, rewrite history, then re-run bootstrap."
    return 1
  fi
  log_success "No secrets found in git history"
}
```

### Architecture Detection

```bash
# lib/os.sh
os_detect_arch() {
  local raw
  raw="$(uname -m)"
  case "$raw" in
    x86_64)         echo "x86_64" ;;
    aarch64|arm64)  echo "arm64" ;;
    *)
      log_error "Unsupported architecture: ${raw}. Supported: x86_64, aarch64/arm64"
      return 1
      ;;
  esac
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `gitleaks detect` for history | `gitleaks git` | v8.19.0 (2023) | `detect` hidden in help; use `gitleaks git` for new scripts |
| `gitleaks protect` for pre-commit | `gitleaks protect --staged` | v8.19.0 | Command still works; `protect` hidden but functional as of v8.30.0 |
| `#!/bin/bash` shebang | `#!/usr/bin/env bash` | Long established | Portability: bash may not be at `/bin/bash` on all systems |
| `set -e` alone | `set -eEuo pipefail` | Long established | `-E` propagates ERR traps into functions; `-u` catches unset vars; `pipefail` catches pipe failures |
| `which gitleaks` | `command -v gitleaks` | Long established | `which` not POSIX; `command -v` is portable and reliable |

**Deprecated/outdated:**
- `gitleaks detect`: Deprecated v8.19.0, hidden from help. Still executes but should not be used in new scripts.
- `gitleaks protect` (without `--staged`): Deprecated behavior; always use `--staged` for pre-commit use case.
- Bash 3.x compatibility targeting: Ubuntu 20.04+ and RPi OS Bookworm ship bash 5.x. No need to write bash 3-compatible code.

---

## Open Questions

1. **gitleaks protect vs gitleaks git for pre-commit**
   - What we know: `gitleaks protect --staged` is confirmed working in v8.30.0 for checking staged changes. `gitleaks detect` was deprecated in v8.19.0 but `protect` was not clearly deprecated.
   - What's unclear: Whether `gitleaks protect --staged` will be removed in a future v8.x release, or whether it will persist long-term.
   - Recommendation: Use `gitleaks protect --staged --redact` in the pre-commit hook for now. Pin to a specific version (`GITLEAKS_VERSION`) so surprises are controlled. Add a comment in the hook noting the deprecation status.

2. **Full cleanup requirement: scope of "all runs"**
   - What we know: User requires cleanup to undo all changes from all runs, not just the current run. The manifest file pattern enables this.
   - What's unclear: The exact scope — does "all changes" include changes made before the repo was cloned (e.g., packages installed by `apt` before the clone)? This is a planning question, not a research gap.
   - Recommendation: The planner should define a clear scope boundary. For Phase 1, the only installed artifact is the gitleaks binary and the pre-commit hook — both are trivially reversible. Document the manifest entry format precisely so future phases can extend it.

3. **Install path for gitleaks: `/usr/local/bin/` vs `~/.local/bin/`**
   - What we know: `/usr/local/bin/` requires root. `~/.local/bin/` does not but requires the path to be in `$PATH`.
   - What's unclear: Whether the bootstrap always runs as root (fresh server setups often do).
   - Recommendation: The planner should pick `/usr/local/bin/` for system-wide access (consistent with later tool installs in Phase 3 like ripgrep, fd, etc.) and document the root assumption. Add a `require_root` check in `lib/os.sh` that fails fast with a clear error if not running as root.

---

## Sources

### Primary (HIGH confidence)

- [gitleaks GitHub releases page](https://github.com/gitleaks/gitleaks/releases) — confirmed v8.30.0 as latest release (2025-11-26), Linux binary filenames for amd64 and arm64
- [gitleaks GitHub repository README](https://github.com/gitleaks/gitleaks) — command deprecation note (detect/protect hidden since v8.19.0), `gitleaks git` as modern replacement, `git log -p` scanning mechanism
- [d4b.dev: Gitleaks Pre-Commit Hook (2026-02-01)](https://www.d4b.dev/blog/2026-02-01-gitleaks-pre-commit-hook) — verified standalone bash hook pattern, `gitleaks protect --staged --redact`, hook installation via `git rev-parse --git-dir`
- [arslan.io: How to write idempotent Bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — verified idempotency patterns: `mkdir -p`, `ln -sfn`, `command -v`, `[ -f ]` / `[ -d ]` checks
- [d4b.dev: Shell script colours (2025-06-23)](https://www.d4b.dev/blog/2025-06-23-shell-script-colours) — verified TTY detection pattern `[ -t 1 ]`, ANSI color code structure, log function signatures
- [How to Trap Errors in Bash Scripts — HowToGeek](https://www.howtogeek.com/bash-error-handling-patterns-i-use-in-every-script/) — verified `set -eEuo pipefail`, `trap cleanup ERR/EXIT`, `set -E` for function trap inheritance
- [bash-rollback GitHub](https://github.com/siilike/bash-rollback) — LIFO stack rollback pattern; confirms feasibility of undo-stack approach in pure bash

### Secondary (MEDIUM confidence)

- [Arch Linux gitleaks package](https://archlinux.org/packages/extra/x86_64/gitleaks/) — confirmed v8.30.0 package version (cross-reference for latest version)
- [lost-in-it.com: Modular Bash library patterns](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) — function prefix naming conventions (`log_`, `os_`), double-source guard pattern, `local` variables for namespace isolation
- [oneuptime.com: Secret Scanning with gitleaks (2026-01-25)](https://oneuptime.com/blog/post/2026-01-25-secret-scanning-gitleaks/view) — `gitleaks detect --source . --verbose` for full history scan, binary install via GitHub releases
- Multiple verified WebSearch results for `uname -m` architecture detection confirming `aarch64` on Linux ARM64 vs `arm64` on macOS — cross-referenced against kustomize issue #4696 showing real-world aarch64/amd64 mismatch consequences

### Tertiary (LOW confidence)

- WebSearch community results on `curl | bash` stdin behavior (TTY detection, `-t 0` test) — multiple consistent sources, pattern is well-established even though no single official spec was verified

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — gitleaks version verified against GitHub releases; bash patterns verified against official bash manual and multiple authoritative sources
- Architecture patterns: HIGH — all patterns derived from official bash documentation and verified working implementations
- Pitfalls: HIGH — all pitfalls derived from verified technical behavior (POSIX specs, gitleaks changelog, bash manual)
- Gitleaks deprecation status: MEDIUM — deprecation noted in README; exact future of `protect --staged` not explicitly documented as permanent vs. temporary

**Research date:** 2026-02-22
**Valid until:** 2026-08-22 (180 days — gitleaks releases frequently but v8.x API is stable; bash patterns are permanent)
