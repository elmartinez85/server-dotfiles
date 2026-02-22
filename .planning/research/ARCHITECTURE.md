# Architecture Research

**Domain:** Server dotfiles and one-command bootstrap system
**Researched:** 2026-02-22
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INVOCATION LAYER                                  │
│   curl -fsSL https://raw.githubusercontent.com/.../bootstrap.sh     │
│                   | bash -s -- [env vars]                            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                    BOOTSTRAP ENTRYPOINT                              │
│                     bootstrap.sh / install.sh                        │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│   │ Detect arch  │  │  Clone repo  │  │   Source install modules  │  │
│   │ uname -m     │  │  git clone   │  │   install/*.sh            │  │
│   └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                    INSTALL MODULES LAYER                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │   apt/   │ │  shell/  │ │  tools/  │ │  docker/ │ │  ssh/    │  │
│  │packages  │ │  zsh,omz │ │  cli     │ │  engine  │ │  harden  │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                    CONFIG DEPLOYMENT LAYER                           │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │   Symlink runner: stow packages OR ln -sf loop              │   │
│   │   repo/zsh/.zshrc  →  ~/.zshrc                              │   │
│   │   repo/tmux/.tmux.conf  →  ~/.tmux.conf                     │   │
│   │   repo/starship/starship.toml  →  ~/.config/starship.toml   │   │
│   └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                    SECRETS LAYER (runtime only)                      │
│   ┌──────────────────────────┐  ┌──────────────────────────────┐   │
│   │  Env vars at invocation  │  │  Password manager CLI (pass, │   │
│   │  SSH_PUBLIC_KEY=...      │  │  1Password, Bitwarden CLI)   │   │
│   │  GITHUB_USER=...         │  │  fetched, applied, discarded │   │
│   └──────────────────────────┘  └──────────────────────────────┘   │
│   Nothing written to repo. Nothing persisted in plaintext.          │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| bootstrap.sh | Entry point; orchestrates everything | Single bash file, curl-safe, sets -e, detects arch, clones repo, calls modules |
| install/packages.sh | apt dependencies, base packages | apt-get install with idempotency checks (`dpkg -l | grep -q`) |
| install/shell.sh | zsh, oh-my-zsh, starship install | Checks `command -v zsh`, downloads omz install script, installs starship binary |
| install/tools.sh | Modern CLI tools (ripgrep, fzf, fd, eza, bat, delta, neovim) | apt for some; arch-conditional binary downloads for others |
| install/docker.sh | Docker Engine + Compose plugin | Official Docker apt repo; idempotent key/repo add pattern |
| install/ssh.sh | SSH hardening, authorized_keys deploy | sed on sshd_config; sshd -t validation before reload; key from env var |
| config/ or topic dirs | Config files (.zshrc, .tmux.conf, etc.) | Source of truth; symlinked to $HOME by deploy step |
| lib/ or bin/ | Shared functions used by install modules | Logging helpers (info/success/fail), arch detection, idempotency guards |

## Recommended Project Structure

The **topics-based layout** (pioneered by holman/dotfiles) is the dominant convention for personal dotfiles with multiple tool configs. It groups files by the tool they configure, not by their destination path. This makes it easy to add/remove a tool without touching other configs.

```
server-dotfiles/
├── bootstrap.sh              # Entrypoint: curl | bash lands here
│                             # Clones repo, detects arch, runs modules
│
├── install/                  # Idempotent install modules, sourced by bootstrap
│   ├── packages.sh           # apt base packages (git, curl, build-essential)
│   ├── shell.sh              # zsh + oh-my-zsh + starship + tmux
│   ├── tools.sh              # ripgrep, fzf, fd, eza, bat, delta, neovim
│   ├── docker.sh             # Docker Engine + Compose plugin
│   └── ssh.sh                # SSH hardening + authorized_keys from env var
│
├── lib/                      # Shared shell functions (not executed directly)
│   ├── logging.sh            # info(), success(), fail() with color output
│   ├── platform.sh           # arch detection (ARCH, IS_ARM, IS_X86), OS checks
│   └── idempotent.sh         # command_exists(), file_contains(), apt_installed()
│
├── zsh/                      # Stow package: zsh configs
│   ├── .zshrc                # Main zshrc; sources platform-specific file
│   ├── .zsh_aliases          # Shared aliases (macOS + Linux compatible)
│   ├── .zshrc.linux          # Linux-only additions (sourced conditionally)
│   └── .zshrc.darwin         # macOS-only additions (sourced conditionally)
│
├── tmux/                     # Stow package: tmux config
│   └── .tmux.conf
│
├── starship/                 # Stow package: starship prompt config
│   └── .config/
│       └── starship/
│           └── starship.toml
│
├── git/                      # Stow package: git config (non-sensitive parts)
│   └── .gitconfig
│
├── neovim/                   # Stow package: neovim config
│   └── .config/
│       └── nvim/
│           └── init.lua
│
├── script/                   # Development helper scripts (not part of bootstrap)
│   ├── lint.sh               # shellcheck all *.sh files
│   └── test.sh               # Run in Docker for local testing
│
└── .github/
    └── workflows/
        └── ci.yml            # shellcheck + test on push
```

### Structure Rationale

- **bootstrap.sh at root:** The curl-pipe-bash invocation (`curl | bash`) fetches a single file. Placing the entrypoint at root makes the URL clean and the intent obvious. It then clones the full repo and delegates.
- **install/ directory:** Each module is independently sourceable and testable. This prevents one 800-line monolith that becomes unmaintainable. Each file has exactly one job.
- **lib/ directory:** Shared functions (logging, arch detection, idempotency guards) are sourced by install modules. This eliminates copy-paste between modules and makes the guards consistent.
- **Topics-based config dirs (zsh/, tmux/, etc.):** Each directory is a GNU Stow package. `stow zsh` from the repo root creates all symlinks for zsh configs. Topics map 1:1 to tools, making it clear what configs belong where.
- **Stow-compatible layout:** Files inside a topic dir mirror the path they'd live at under `$HOME`. So `zsh/.zshrc` symlinks to `~/.zshrc`. `starship/.config/starship/starship.toml` symlinks to `~/.config/starship/starship.toml`. No mental mapping required.
- **script/ dir:** Local dev tooling (linting, Docker-based test runs) kept separate from the actual bootstrap. Never executed during a real install.

## Architectural Patterns

### Pattern 1: Module Sourcing with Shared Lib

**What:** The entrypoint sources `lib/` functions first, then calls each `install/*.sh` module in order. Modules use shared functions instead of inline guards.

**When to use:** Always. This is the correct pattern for multi-module bash systems.

**Trade-offs:** Slightly more files than a monolith, but vastly easier to test modules individually and debug failures.

**Example:**
```bash
# bootstrap.sh (entrypoint)
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
REPO_URL="https://github.com/user/server-dotfiles.git"

# Source shared functions
source "$DOTFILES_DIR/lib/logging.sh"
source "$DOTFILES_DIR/lib/platform.sh"
source "$DOTFILES_DIR/lib/idempotent.sh"

info "Detected architecture: $ARCH"

# Run install modules in order
source "$DOTFILES_DIR/install/packages.sh"
source "$DOTFILES_DIR/install/shell.sh"
source "$DOTFILES_DIR/install/tools.sh"
source "$DOTFILES_DIR/install/docker.sh"
source "$DOTFILES_DIR/install/ssh.sh"

success "Bootstrap complete."
```

### Pattern 2: Architecture-Conditional Binary Download

**What:** `uname -m` detects the CPU arch. Tool downloads use a `case` statement to select the correct binary URL. This is required for tools distributed as pre-built binaries (starship, fd, eza, delta).

**When to use:** Any tool that ships architecture-specific binaries — which is most modern CLI tools distributed via GitHub Releases.

**Trade-offs:** URLs must be kept current when tools release new versions. Pin versions explicitly; don't use "latest" in production bootstrap scripts.

**Example:**
```bash
# lib/platform.sh
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_TAG="x86_64-unknown-linux-musl" ;;
  aarch64) ARCH_TAG="aarch64-unknown-linux-musl" ;;
  armv7l)  ARCH_TAG="armv7-unknown-linux-musleabihf" ;;
  *)
    fail "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# install/tools.sh — using ARCH_TAG
install_starship() {
  if command_exists starship; then
    info "starship already installed, skipping"
    return
  fi
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
}

install_ripgrep() {
  if command_exists rg; then return; fi
  local version="14.1.1"
  local url="https://github.com/BurntSushi/ripgrep/releases/download/${version}/ripgrep-${version}-${ARCH_TAG}.tar.gz"
  curl -fsSL "$url" | tar -xz --strip-components=1 -C /usr/local/bin/ ripgrep-${version}-${ARCH_TAG}/rg
}
```

### Pattern 3: Idempotency Guards

**What:** Every install action checks whether its outcome already exists before running. The guard pattern is: "check, skip if satisfied, install if not." This makes the bootstrap safe to re-run.

**When to use:** Every single install action. Non-negotiable for a re-runnable bootstrap.

**Trade-offs:** More verbose than unconditional installs. Worth every line.

**Example:**
```bash
# lib/idempotent.sh
command_exists() { command -v "$1" &>/dev/null; }

apt_installed() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }

file_contains() { grep -qF "$2" "$1" 2>/dev/null; }

line_in_file() {
  local line="$1" file="$2"
  if ! file_contains "$file" "$line"; then
    echo "$line" >> "$file"
  fi
}

# install/shell.sh — idempotent zsh install
install_zsh() {
  if command_exists zsh; then
    info "zsh already installed"
    return
  fi
  apt-get install -y zsh
}

set_default_shell() {
  if [[ "$SHELL" == "$(command -v zsh)" ]]; then
    info "zsh already default shell"
    return
  fi
  chsh -s "$(command -v zsh)" "$USER"
}
```

### Pattern 4: Symlink Deployment via GNU Stow

**What:** After install modules run, a symlink step links config files from the cloned repo into `$HOME`. GNU Stow reads each topic directory and symlinks files to mirror the path they'd occupy under `$HOME`.

**When to use:** Always, for config file deployment. Stow is available in apt on Debian/Ubuntu. Alternatively, a simple `ln -sf` loop works if stow feels like overkill.

**Trade-offs:** Stow requires stow to be installed first (add to packages.sh). The benefit is zero manual symlink path logic — the directory layout is the documentation.

**Example:**
```bash
# In bootstrap.sh, after install modules:
deploy_configs() {
  cd "$DOTFILES_DIR"
  # Stow each topic directory (skip non-config dirs)
  for pkg in zsh tmux starship git neovim; do
    stow --restow --target="$HOME" "$pkg"
    success "Deployed $pkg configs"
  done
}
```

### Pattern 5: Secrets Injection via Environment Variables

**What:** Sensitive values (SSH public key, any tokens) are never in the repo. They are passed as environment variables when the bootstrap is invoked, consumed during the run, and discarded.

**When to use:** For any value that cannot be public. SSH public key for authorized_keys deployment is the primary case here.

**Trade-offs:** The user must have the values ready at invocation time. For automation, a password manager CLI (pass, 1Password CLI, Bitwarden CLI) can be piped into the env.

**Example:**
```bash
# Invocation with env var injection:
SSH_PUBLIC_KEY="ssh-ed25519 AAAA..." \
  curl -fsSL https://raw.githubusercontent.com/user/server-dotfiles/main/bootstrap.sh | bash

# install/ssh.sh — consumes env var, never writes to disk:
deploy_ssh_key() {
  if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
    info "SSH_PUBLIC_KEY not set, skipping authorized_keys deployment"
    return
  fi
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if ! file_contains "$HOME/.ssh/authorized_keys" "$SSH_PUBLIC_KEY"; then
    echo "$SSH_PUBLIC_KEY" >> "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    success "SSH public key deployed"
  else
    info "SSH public key already present"
  fi
}
```

### Pattern 6: Platform-Conditional zsh Config Sourcing

**What:** A single `.zshrc` is the source of truth for both macOS and Linux. Platform-specific sections (paths, aliases, tool invocations that differ by OS) live in separate files that `.zshrc` conditionally sources using `$OSTYPE`.

**When to use:** When sharing shell configs between macOS and Linux servers (exactly this project's use case).

**Trade-offs:** `$OSTYPE` is available in both bash and zsh. Using it is lighter than spawning `uname` as a subshell. The main risk is forgetting to test both files when making changes.

**Example:**
```bash
# zsh/.zshrc — shared config sourced on both macOS and Linux

# Source platform-specific config
case "$OSTYPE" in
  darwin*)
    [[ -f "$ZDOTDIR/.zshrc.darwin" ]] && source "$ZDOTDIR/.zshrc.darwin"
    ;;
  linux*)
    [[ -f "$ZDOTDIR/.zshrc.linux" ]] && source "$ZDOTDIR/.zshrc.linux"
    ;;
esac

# Platform-specific ls alias
case "$OSTYPE" in
  darwin*) alias ls='ls -G' ;;
  linux*)  alias ls='ls --color=auto' ;;
esac
```

## Data Flow

### Bootstrap Flow (curl to configured server)

```
User runs: SSH_PUBLIC_KEY="..." curl -fsSL [url]/bootstrap.sh | bash
    │
    ▼
bootstrap.sh downloads and executes
    │
    ├─ 1. Detect: uname -m → ARCH (x86_64 or aarch64)
    │
    ├─ 2. Clone: git clone [repo] → $HOME/.dotfiles
    │
    ├─ 3. Source: lib/logging.sh, lib/platform.sh, lib/idempotent.sh
    │
    ├─ 4. Run install modules (in order):
    │      packages.sh  → apt install base packages
    │      shell.sh     → zsh, oh-my-zsh, starship, tmux
    │      tools.sh     → ripgrep, fzf, fd, eza, bat, delta, neovim
    │                     (arch-conditional binary downloads)
    │      docker.sh    → Docker Engine + Compose plugin via official apt repo
    │      ssh.sh       → Read $SSH_PUBLIC_KEY → write to authorized_keys
    │                     Modify sshd_config → validate → reload sshd
    │
    ├─ 5. Deploy configs:
    │      stow zsh tmux starship git neovim
    │      repo/zsh/.zshrc       → symlink → ~/.zshrc
    │      repo/tmux/.tmux.conf  → symlink → ~/.tmux.conf
    │      repo/starship/.config/starship/starship.toml → symlink → ~/.config/starship/starship.toml
    │
    └─ 6. Done. Shell is now zsh. Re-login to activate.
```

### Config Update Flow (subsequent runs)

```
On existing server: curl [url]/bootstrap.sh | bash  (re-run)
    │
    ▼
bootstrap.sh detects repo already cloned
    │
    ├─ git pull (update configs)
    │
    ├─ Run install modules — idempotency guards skip already-installed tools
    │
    ├─ stow --restow — updates symlinks if config files changed
    │
    └─ Only net-new or changed items actually run
```

### Config File Deployment Detail

```
REPO (source of truth)          $HOME (destination)
────────────────────            ────────────────────
~/.dotfiles/
  zsh/
    .zshrc           ──────────► ~/.zshrc (symlink)
    .zsh_aliases     ──────────► ~/.zsh_aliases (symlink)
    .zshrc.linux     ──────────► ~/.zshrc.linux (symlink)
  tmux/
    .tmux.conf       ──────────► ~/.tmux.conf (symlink)
  starship/
    .config/
      starship/
        starship.toml ─────────► ~/.config/starship/starship.toml (symlink)

Edit in repo → git push → git pull on server → stow --restow → live immediately
```

## Build Order (What Must Exist Before What)

This order is not arbitrary — each step has dependencies on the previous:

```
1. PACKAGES (apt base)
   ├─ Provides: git, curl, wget, stow, build-essential, ca-certificates
   └─ Required by: all subsequent steps

2. SHELL (zsh + oh-my-zsh + starship + tmux)
   ├─ Provides: the shell environment itself
   ├─ Depends on: git (oh-my-zsh uses git), curl
   └─ Required by: config deployment (configs assume zsh is installed)

3. TOOLS (ripgrep, fzf, fd, eza, bat, delta, neovim)
   ├─ Provides: modern CLI tooling
   ├─ Depends on: curl, ARCH detection from lib/platform.sh
   └─ Required by: nothing critical (can run after config deploy too)

4. DOCKER (Engine + Compose)
   ├─ Provides: container runtime
   ├─ Depends on: ca-certificates, curl, apt repo setup
   └─ Required by: nothing in this bootstrap

5. SSH HARDENING (sshd_config + authorized_keys)
   ├─ Provides: key-only SSH access
   ├─ Depends on: $SSH_PUBLIC_KEY env var, SSH key already deployed BEFORE disabling passwords
   └─ WARNING: Run LAST. If this runs before key is deployed, you get locked out.

6. CONFIG DEPLOYMENT (stow)
   ├─ Provides: symlinked dotfiles in $HOME
   ├─ Depends on: stow installed (step 1), repo cloned, tools installed (configs reference them)
   └─ Can run after step 2, but running after step 3 ensures configs for tools are useful
```

**Critical ordering constraint:** SSH hardening (step 5) must run after the SSH public key is verified in `~/.ssh/authorized_keys`. The script must validate that the key is present and that `sshd -t` passes before restarting the SSH daemon. Failure here causes permanent lockout.

## Multi-Architecture Installation Strategy

### Detection

```bash
ARCH=$(uname -m)
# x86_64  → Ubuntu VPS
# aarch64 → Raspberry Pi 4/5 (64-bit OS)
# armv7l  → Raspberry Pi (32-bit OS — less common now)
```

### Tool-by-Tool Strategy

| Tool | x86_64 Install Method | ARM Install Method | Notes |
|------|-----------------------|--------------------|-------|
| ripgrep | GitHub Releases binary | GitHub Releases binary (aarch64 musl) | Both have pre-built binaries |
| fd | GitHub Releases binary | GitHub Releases binary (aarch64) | Same release page |
| fzf | `apt install fzf` OR GitHub binary | `apt install fzf` | apt version may be older; binary preferred |
| eza | GitHub Releases binary | GitHub Releases binary (aarch64) | Homebrew not used on Linux |
| bat | `apt install bat` OR GitHub binary | `apt install bat` | apt works on both |
| delta | GitHub Releases binary | GitHub Releases binary (aarch64) | |
| neovim | AppImage (x86_64 only) OR apt | `apt install neovim` OR build from source | AppImage is x86_64-only; apt neovim may be old version |
| starship | Official install script (auto-detects arch) | Same | Best option — script handles arch |
| Docker | Official apt repo (amd64) | Official apt repo (arm64) | Docker publishes both; repo URL uses `$(dpkg --print-architecture)` |

### Architecture Abstraction Pattern

Centralize arch mapping in `lib/platform.sh`. All install modules import this file and use the exported variables rather than calling `uname` themselves:

```bash
# lib/platform.sh
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_MUSL="x86_64-unknown-linux-musl"
           ARCH_GNU="x86_64-unknown-linux-gnu"
           ARCH_DEB="amd64"
           ;;
  aarch64) ARCH_MUSL="aarch64-unknown-linux-musl"
           ARCH_GNU="aarch64-unknown-linux-gnu"
           ARCH_DEB="arm64"
           ;;
  armv7l)  ARCH_MUSL="armv7-unknown-linux-musleabihf"
           ARCH_GNU="armv7-unknown-linux-gnueabihf"
           ARCH_DEB="armhf"
           ;;
  *)       fail "Unsupported architecture: $ARCH"; exit 1 ;;
esac

export ARCH ARCH_MUSL ARCH_GNU ARCH_DEB
```

## Anti-Patterns

### Anti-Pattern 1: Monolithic Bootstrap Script

**What people do:** Write one 1000-line `bootstrap.sh` that does everything inline.

**Why it's wrong:** Impossible to test sections independently. Debugging requires running the entire script. Adding a new tool means editing one massive file with high blast radius.

**Do this instead:** Split into `install/*.sh` modules. Each module does one thing. The entrypoint sources them in order. Any module can be run standalone for debugging.

### Anti-Pattern 2: Storing Secrets in the Repo

**What people do:** Commit SSH private keys, API tokens, or passwords into the dotfiles repo, especially in a "private" GitHub repo.

**Why it's wrong:** Repos get made public by accident. GitHub searches historical commits. Even "deleted" commits persist in forks and clones. One credential exposure is unrecoverable for anything sensitive.

**Do this instead:** Pass secrets as environment variables at bootstrap invocation time. For repeated use, pull from a local password manager CLI (pass, 1Password CLI, Bitwarden CLI). Never write secrets to the repo, not even in a .gitignore'd file.

### Anti-Pattern 3: Non-Idempotent Install Steps

**What people do:** Write install steps that fail or produce duplicates if run twice (e.g., `apt install -y` without checking if it's needed, `echo "alias..." >> .bashrc` without checking if the alias already exists).

**Why it's wrong:** Bootstrap scripts get re-run to apply config updates. Non-idempotent steps cause errors, duplicate config entries, or wasted time on already-installed tools.

**Do this instead:** Guard every action with a check. `command_exists`, `apt_installed`, `file_contains`, and `grep -q` are your friends. If the desired state already exists, skip silently.

### Anti-Pattern 4: SSH Hardening Before Key Deployment

**What people do:** Disable password authentication in sshd_config before verifying the SSH public key is in `authorized_keys` and actually works.

**Why it's wrong:** You lock yourself out of the server permanently. There is no recovery path except console access (which many VPS providers charge for or don't offer).

**Do this instead:** In `install/ssh.sh`: (1) deploy the public key, (2) verify the key file exists and is non-empty, (3) run `sshd -t` to validate config syntax, (4) then and only then disable password auth and reload sshd.

### Anti-Pattern 5: Copying Config Files Instead of Symlinking

**What people do:** Copy config files from the repo to `$HOME` during bootstrap (`cp ~/.dotfiles/zsh/.zshrc ~/.zshrc`).

**Why it's wrong:** The `$HOME` copy is now out of sync with the repo. `git pull` updates the repo but not the live copy. You must manually re-run the copy step or write a separate sync mechanism.

**Do this instead:** Symlink with GNU Stow or `ln -sf`. The symlink means the repo IS the live config. `git pull` updates configs immediately without any extra step.

### Anti-Pattern 6: Hardcoding Architecture in Install Scripts

**What people do:** Write `x86_64` or `amd64` directly into binary download URLs in install scripts.

**Why it's wrong:** The script silently fails or installs the wrong binary when run on ARM (Raspberry Pi).

**Do this instead:** Use `lib/platform.sh` to export `$ARCH_MUSL`, `$ARCH_DEB`, etc. All download URLs reference these variables. One script works on all supported architectures.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub (raw) | `curl -fsSL` to fetch bootstrap.sh | Pin to a specific commit or tag for stability; `main` branch is mutable |
| apt package repos | `apt-get install` with official signing keys | Docker requires adding their apt repo explicitly; keep key fingerprints in script |
| GitHub Releases | `curl` binary downloads by tag + arch | Pin versions explicitly; avoid `latest` redirects which can change |
| starship.rs install | Official install script auto-detects arch | Most reliable for starship; delegates arch complexity to upstream |
| Password manager CLI | Invoked at bootstrap time to fetch secrets | pass, 1Password CLI (`op`), Bitwarden CLI (`bw`) — all produce plaintext output to env vars |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| bootstrap.sh → install/*.sh | `source` (not exec) | Modules share the same shell session; they inherit lib functions and ARCH vars |
| install/*.sh → lib/*.sh | `source` at top of each module | Each module sources what it needs; lib functions are pure (no side effects) |
| install/ssh.sh → $SSH_PUBLIC_KEY | Environment variable | Never written to disk; consumed and applied during run |
| install/* → stow packages | Sequential: install tools first, then stow configs | Stow runs after all tools are installed so configs reference available binaries |
| zsh/.zshrc → .zshrc.linux / .zshrc.darwin | `source` with `$OSTYPE` guard | Both files live in the repo; only the matching one is sourced at runtime |

## Sources

- [Holman dotfiles — topics-based bootstrap structure](https://github.com/holman/dotfiles) — HIGH confidence (widely replicated pattern, inspected bootstrap script)
- [GNU Stow manual](https://www.gnu.org/software/stow/manual/stow.html) — HIGH confidence (official documentation)
- [awesome-dotfiles — curated ecosystem overview](https://github.com/webpro/awesome-dotfiles) — HIGH confidence (community-maintained reference)
- [ArchWiki: Dotfiles — bare repo vs symlink patterns](https://wiki.archlinux.org/title/Dotfiles) — HIGH confidence (authoritative, regularly updated)
- [How to write idempotent Bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — MEDIUM confidence (well-regarded but single author)
- [VPS-Harden: idempotent SSH hardening discussion](https://news.ycombinator.com/item?id=47033635) — MEDIUM confidence (practitioner post, 2025)
- [Effective Shell — dotfiles management patterns](https://effective-shell.com/part-5-building-your-toolkit/managing-your-dotfiles/) — MEDIUM confidence (educational resource, practical examples)
- [Modular .bashrc with .bashrc.d/ pattern](https://simoninglis.com/posts/modular-bashrc/) — MEDIUM confidence (pattern widely verified across multiple sources)
- [zsh $OSTYPE conditional sourcing for macOS/Linux](https://copyprogramming.com/howto/how-to-configure-zshrc-for-specfic-os) — HIGH confidence (pattern verified in official zsh docs and multiple independent sources)
- [chezmoi architecture documentation](https://www.chezmoi.io/) — HIGH confidence (official docs; considered but not chosen due to extra dependency overhead for a server bootstrap)

---
*Architecture research for: Server dotfiles and one-command bootstrap system*
*Researched: 2026-02-22*
