# Pitfalls Research

**Domain:** Server dotfiles / one-command bootstrap system (Ubuntu x86_64 + Raspberry Pi ARM)
**Researched:** 2026-02-22
**Confidence:** HIGH (multiple sources verified; domain is well-documented with real-world post-mortems)

---

## Critical Pitfalls

### Pitfall 1: Secrets Committed to Git History

**What goes wrong:**
A secret (SSH key, API token, password, private IP, hostname) is committed to the public repo — even once. Git history is immutable: removing the file in a later commit does not remove it from history. Automated bots scan GitHub's public event stream and harvest credentials within five minutes of a push.

**Why it happens:**
- `.zshrc` or aliases contain hardcoded tokens for convenience (`export GITHUB_TOKEN=ghp_xxx`)
- `.ssh/config` with internal hostnames gets added whole
- A `secrets.env` or `.env` file is committed "just once" to test
- Template files with placeholder values that contain real values "temporarily"
- Developer forgets `.gitignore` entries when adding a new tool's config

**How to avoid:**
- `.gitignore` all credential-adjacent filenames by default: `.env`, `*.local`, `secrets`, `*.key`, `*.pem`, `id_rsa`, `id_ed25519`
- Never source secrets from files in the repo; always pull from environment variables or a password manager CLI (e.g., `pass`, `op`, `bw`) at bootstrap time
- Add `git-secrets` or `gitleaks` as a pre-commit hook before any first commit
- Treat `.gitconfig` as safe only for non-sensitive fields; never put `[credential]` helper tokens in the tracked config
- Audit with `git log --all --full-history -- '**/*.env'` before making repo public

**Warning signs:**
- Any `export VARIABLE="literal_value"` in a tracked config file
- `.ssh/config` containing `IdentityFile` paths or `ProxyCommand` with internal hostnames
- `git status` shows files you didn't intend to add (from a broad `git add .`)
- First commit touches both configs and a credentials file

**Phase to address:** Phase 1 — Repository skeleton / `.gitignore` / secret strategy must be established before any configs are written

---

### Pitfall 2: Idempotency Failures Leaving Partial State

**What goes wrong:**
The bootstrap script fails halfway through (network blip, package not found, wrong password). On re-run, the script hits "directory already exists," "package already installed," or "symlink target already there" and exits with an error — or worse, silently does the wrong thing. The server is left in a partially-configured state that is neither fresh nor fully provisioned.

**Why it happens:**
- `mkdir path` fails if directory exists (needs `-p`)
- `ln -s source target` fails if target exists (needs `-sf` or `-sfn` for directories)
- `apt-get install` without `--no-upgrade` re-downloads and reconfigures unnecessarily
- Configuration blocks appended to `.zshrc` without checking for existence create duplicates on re-run
- Oh-my-zsh installer exits and spawns zsh, ending the parent script before subsequent steps run

**How to avoid:**
- Open every script with `set -euo pipefail` so partial failures surface loudly and stop execution cleanly
- Use guard patterns for every non-idempotent operation:
  ```bash
  # Directories
  mkdir -p "$HOME/.config/tool"

  # Symlinks (always safe to re-run)
  ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

  # Append-once pattern
  grep -qxF 'source ~/.aliases' ~/.zshrc || echo 'source ~/.aliases' >> ~/.zshrc

  # apt install (idempotent by design, but verify)
  dpkg -l package-name &>/dev/null || apt-get install -y package-name
  ```
- Install oh-my-zsh with `RUNZSH=no CHSH=no sh -c "$(curl -fsSL ...)"` to prevent it from launching a new shell mid-script
- Structure the script in atomic phases with clear progress logging so re-runs can skip completed phases
- Add a `BOOTSTRAP_STEP` tracking file or use `[ -f "$HOME/.zsh_installed" ]` guards for expensive one-time operations

**Warning signs:**
- Script works on first run, fails on second with "file exists" errors
- `.zshrc` grows duplicate `source` lines on each run
- Server has some tools but not others after an interrupted run
- oh-my-zsh installed but no subsequent tools (script exited after oh-my-zsh launched zsh)

**Phase to address:** Phase 1 — Bootstrap script structure; idempotency must be designed in from the start, not retrofitted

---

### Pitfall 3: SSH Hardening Locks You Out

**What goes wrong:**
The script disables password authentication, changes the SSH port, or restricts `AllowUsers` — then the sshd restart fails (config syntax error) or the new configuration is applied before the SSH public key is confirmed to be working. Result: no way back in without provider console access.

**Why it happens:**
- `sshd_config` changes applied and sshd restarted without validating config first (`sshd -t`)
- `PubkeyAuthentication yes` + `PasswordAuthentication no` applied before verifying the deployed key actually works
- `AllowUsers ubuntu` hardcoded but the user on the target server is `pi` or `admin`
- Firewall (`ufw`) enabled with a new port rule before the new port rule is confirmed to be correct
- Port changed in `sshd_config` but firewall still only allows 22

**How to avoid:**
- Always validate config before restarting: `sshd -t && systemctl reload sshd`
- Sequence matters: (1) deploy SSH key, (2) verify key-based login works in a test connection, (3) THEN disable password auth
- Use `PasswordAuthentication no` only as the final step; never as a mid-script action
- Keep `ufw` configuration separate from sshd configuration; confirm the firewall allows the new port before changing sshd
- For bootstrap scripts, script the sequence: add key → test key works (ssh-keyscan or explicit step) → harden sshd
- Raspberry Pi default user is `pi`; Ubuntu VPS default user varies (`ubuntu`, `admin`, `root`). Never hardcode `AllowUsers` in a shared config without parameterizing it

**Warning signs:**
- Script changes sshd and ufw in the same command block with no verification step between them
- No `sshd -t` call before `systemctl restart sshd`
- `PasswordAuthentication no` set before the script has confirmed the authorized_keys file was written correctly
- Hardcoded usernames in `sshd_config`

**Phase to address:** Phase for SSH hardening (likely Phase 2 or 3) — must be a discrete, carefully-ordered phase with explicit verification between steps

---

### Pitfall 4: Architecture-Specific Binary Download Failures (ARM vs x86_64)

**What goes wrong:**
The script downloads the wrong architecture binary. Common failure modes: (a) x86_64 binary downloaded on ARM — fails with `Exec format error`; (b) aarch64 musl binary requested but doesn't exist for that tool (e.g., ripgrep has no aarch64-musl release); (c) 64-bit binary installed on a 32-bit Raspberry Pi OS; (d) glibc version too old for a binary compiled against newer glibc.

**Why it happens:**
- `uname -m` returns `armv7l` on 32-bit RPi OS even on 64-bit hardware — scripts misread this as "armv7" and download the wrong binary
- 64-bit RPi hardware with 32-bit RPi OS: `uname -m` says `aarch64` but OS is 32-bit userland — aarch64 binaries won't work
- Tools differ in how they name release assets: ripgrep uses `aarch64-unknown-linux-gnu`, fzf uses `linux_arm64`, eza uses `aarch64-unknown-linux-gnu` — no consistent naming convention
- Raspberry Pi OS 32-bit (armhf) is being deprecated by Docker Engine v29+ — scripts assuming armhf Docker packages will fail on future RPi OS versions
- GitHub API rate limits on unauthenticated release asset queries cause download failures

**How to avoid:**
- Build a robust arch-detection function:
  ```bash
  detect_arch() {
    local machine arch
    machine=$(uname -m)
    case "$machine" in
      x86_64)  arch="x86_64" ;;
      aarch64|arm64) arch="aarch64" ;;
      armv7l|armv6l) arch="armv7" ;;
      *) echo "Unsupported architecture: $machine" >&2; exit 1 ;;
    esac
    echo "$arch"
  }
  ```
- Per-tool download URL functions that map arch to the tool's actual release naming convention
- Verify download with `file binary` before `chmod +x` — catch format errors early
- For Raspberry Pi, also check bitness of running OS: `getconf LONG_BIT` returns 32 or 64 regardless of hardware
- Prefer apt packages for tools with good apt availability (ripgrep, fzf, fd-find) on both platforms; fall back to binary only when apt version is too old
- Pin architecture-specific download URLs per tool; do not assume naming consistency across tools

**Warning signs:**
- `Exec format error` when running a newly installed binary
- `getconf LONG_BIT` returns 32 but script downloads aarch64 binaries
- Script uses a single `ARCH=$(uname -m)` variable substituted directly into download URLs without per-tool mapping

**Phase to address:** Phase for tool installation — architecture detection must be a shared utility function established before any binary downloads

---

### Pitfall 5: Oh-My-Zsh Installer Hijacks the Bootstrap Script

**What goes wrong:**
The oh-my-zsh install script, run without flags, (1) interactively prompts "Do you want to change your default shell?" pausing an automated script forever, and (2) launches a new zsh session at the end — which exits the parent bash script, causing all subsequent bootstrap steps to never run.

**Why it happens:**
- `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"` is copied from the oh-my-zsh README, which is designed for interactive use
- The installer's default `RUNZSH=yes` spawns zsh, returning control to the shell's parent (terminal), not the bootstrap script

**How to avoid:**
- Always install oh-my-zsh with:
  ```bash
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ```
  or use the `--unattended` flag:
  ```bash
  sh install.sh --unattended
  ```
- `KEEP_ZSHRC=yes` prevents the installer from overwriting a `.zshrc` that the bootstrap script already placed
- Install oh-my-zsh before writing `.zshrc`; or use `KEEP_ZSHRC=yes` if writing `.zshrc` first
- Change default shell separately via `sudo chsh -s $(which zsh) "$USER"` or by editing `/etc/passwd` directly — do not rely on the oh-my-zsh installer for this

**Warning signs:**
- oh-my-zsh installs successfully but no tools installed after it
- Script hangs waiting for input during automated run
- `.zshrc` symlink replaced with oh-my-zsh template on each run

**Phase to address:** Phase for shell environment setup — oh-my-zsh install call must use these flags from day one

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode download URLs with pinned versions | Script is reproducible, no API calls | URLs go stale; silent failures when version no longer exists at that URL | Only if there is version-checking logic to detect stale URLs |
| Use `apt install` for all tools | Simple, reliable | apt versions lag 1-3 major versions; some tools (eza, delta) may not be in apt at all | Acceptable for tools where version currency is not critical (tmux, fzf) |
| Run bootstrap as root directly | Avoids sudo prompts | Creates root-owned files in home dir; breaks tool config for the actual user | Never — always run as user, use sudo only for system operations |
| Symlink entire dotfiles directory | Simple single operation | One bad file in the repo can clobber critical system files | Only if scope is tightly controlled and `.gitignore` is comprehensive |
| Skip `set -euo pipefail` for "simple" scripts | Script continues past soft errors | Partial installs silently succeed; debugging is much harder | Never for bootstrap scripts |
| Copy `.zshrc` from macOS verbatim | Instant familiar feel | macOS-specific paths (`/opt/homebrew/bin`, `pbcopy`, `open`) break on Linux | Never — use platform detection from day one |

---

## Integration Gotchas

Common mistakes when connecting to external services or tools.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub releases API | Unauthenticated requests rate-limited to 60/hour — fails in rapid re-runs or CI | Cache download URLs; use `GITHUB_TOKEN` env var if available; fall back to direct download URL with pinned version |
| Docker Engine install | Using `curl https://get.docker.com \| bash` on RPi 32-bit (armhf) — installs fine until Docker drops armhf support in v29+ | Install via official apt repo with explicit architecture; check RPi OS bitness before installing |
| SSH key deployment | Writing to `~/.ssh/authorized_keys` without checking if key already present — duplicates accumulate | `grep -qF "$PUBLIC_KEY" ~/.ssh/authorized_keys 2>/dev/null \|\| echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys` |
| oh-my-zsh custom plugins | Cloning plugin repos without checking if they already exist — fails on re-run | `[ -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] \|\| git clone ...` |
| starship install script | Official `curl \| bash` install script downloads latest release — version not pinned, different runs get different versions | Pin version or use apt/package-manager where available; verify binary with `starship --version` after install |
| tmux clipboard | macOS uses `pbcopy/pbpaste`; Linux headless servers have no clipboard — shared `.tmux.conf` breaks | Use OS detection in `.tmux.conf` with `if-shell "uname | grep -q Darwin"` blocks; on headless Linux, disable clipboard integration |

---

## Performance Traps

Patterns that slow down or cause timeouts during bootstrap.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `apt-get update` before every install | Script takes 3-5 minutes on slow connections | Run `apt-get update` once at the start; mark with a flag file | Slow network or RPi SD card I/O |
| Downloading binaries one at a time sequentially | 10+ minutes for full install on slow connection | Group downloads; consider parallel downloads with `&` and `wait` | Raspberry Pi on slow home internet |
| Building neovim from source as fallback | 30-60 minutes on RPi | Check for ARM AppImage release first; only build from source as last resort | Raspberry Pi 3 with limited CPU |
| Cloning large oh-my-zsh + all plugins via git | Slow on cold start; SSH not yet set up | Use `--depth 1` for all git clones; avoid large plugin repos | Network with high latency |

---

## Security Mistakes

Domain-specific security issues for a public dotfiles repo.

| Mistake | Risk | Prevention |
|---------|------|------------|
| `curl URL \| bash` without TLS verification | MITM can inject arbitrary commands into bootstrap | Always use `https://`; never `http://`; verify checksums for binary downloads where available |
| SSH key deployed but authorized_keys permissions too open | sshd ignores `authorized_keys` if permissions are wrong (600 required for file, 700 for `.ssh` dir) | Script must explicitly `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys` |
| `PasswordAuthentication no` before key verified | Locked out with no recovery except console | Sequence: deploy key → verify login → disable password auth. Test in separate session. |
| Fetching secrets via `curl` to env vars in the same script that runs `set -x` | `set -x` prints the secret value to the terminal and potentially logs | Never combine `set -x` debug mode with secret-fetching steps; or use a secrets-only subscript without tracing |
| World-readable `~/.ssh/config` or `known_hosts` | Exposes internal hostnames; sshd may refuse to use private keys | Enforce `chmod 600 ~/.ssh/config` as part of bootstrap |
| Docker group membership grants root equivalent | Adding the deploy user to the `docker` group is a privilege escalation vector | Document this explicitly; only add to docker group if consciously accepted; prefer rootless Docker for non-root operations |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **oh-my-zsh installed:** Often missing — verify default shell was actually changed. `echo $SHELL` should return `/usr/bin/zsh`, not `/bin/bash`. Run `chsh -s $(which zsh) $USER` explicitly; don't rely on the oh-my-zsh installer.
- [ ] **Starship installed:** Often missing — verify `~/.config/starship.toml` exists AND `eval "$(starship init zsh)"` is in `.zshrc`. Without the eval line, starship binary exists but prompt doesn't change.
- [ ] **Docker installed:** Often missing — verify both `docker` and `docker compose` (v2 plugin) work. `docker compose version` is a separate check from `docker version`. On RPi, verify correct architecture package was installed.
- [ ] **SSH hardened:** Often missing — verify `sshd -t` shows no errors AND key-based auth actually works in a new session BEFORE closing the provisioning session.
- [ ] **Idempotent:** Run the bootstrap script a second time on the same server. Any errors on the second run indicate non-idempotent operations that need guard clauses.
- [ ] **Tools on PATH:** Binaries installed to `/usr/local/bin` or `~/.local/bin` are only available if those paths are in `$PATH` in the shell. Verify with `which rg`, `which nvim`, etc. in a new zsh session (not the bash install session).
- [ ] **Config symlinks correct:** `ls -la ~/.zshrc ~/.tmux.conf ~/.config/starship.toml` — verify they are symlinks pointing into the dotfiles directory, not copies.
- [ ] **Architecture verified:** On Raspberry Pi, confirm the correct architecture with `file $(which rg)` — output should show ARM or AArch64, not x86_64.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Secret committed to public repo | HIGH | 1. Rotate the credential immediately (assume compromised). 2. Use `git filter-repo` or BFG Repo-Cleaner to purge from history. 3. Force-push rewritten history. 4. Contact GitHub support to clear cached views. Rotation cannot be skipped — history scrubbing alone is insufficient. |
| SSH locked out | MEDIUM | Use hosting provider's OOB console (DigitalOcean Droplet Console, AWS EC2 Connect, RPi physical keyboard). Edit `/etc/ssh/sshd_config` to re-enable password auth temporarily. |
| Partial install leaving broken state | LOW | Re-run bootstrap script. If idempotency is properly implemented, the script resumes safely. If not, identify the failing step from the error and run that section manually. |
| Wrong architecture binary installed | LOW | `rm /usr/local/bin/toolname`, re-run the install section with corrected arch detection, verify with `file $(which toolname)`. |
| oh-my-zsh overwrote custom `.zshrc` | LOW | Restore from symlink: `ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"`. Oh-my-zsh backs up the original to `.zshrc.pre-oh-my-zsh`. |
| Duplicate lines in `.zshrc` from multiple runs | LOW | Script fix: add idempotency guards. Immediate: manually deduplicate `.zshrc`; `sort -u` is not safe (order matters) — edit manually. |
| Docker fails to start on RPi | MEDIUM | Check architecture: `dpkg --print-architecture`. Verify cgroup v2 support: `grep cgroup /proc/mounts`. On RPi 4+, enable cgroups in `/boot/cmdline.txt` by appending `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1`. |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Secrets committed to Git | Phase 1: Repo skeleton | `.gitignore` covers all credential patterns; `git-secrets` or `gitleaks` installed as pre-commit hook; no secrets in any tracked file |
| Idempotency failures | Phase 1: Bootstrap script structure | Run bootstrap script twice on a clean server; second run must complete without errors |
| SSH hardening lock-out | Phase for SSH hardening | Sequence verified: key deployed → login tested → password auth disabled. `sshd -t` called before every `systemctl restart sshd` |
| Wrong architecture binary | Phase for tool installation | `file $(which <tool>)` on both Ubuntu VPS and Raspberry Pi confirms correct architecture |
| Oh-my-zsh hijacking script | Phase for shell environment setup | `RUNZSH=no CHSH=no` flags present in install command; zsh change-default done via `chsh` separately |
| macOS/Linux config incompatibility | Phase for dotfiles deployment | Platform detection in `.zshrc` and `.tmux.conf`; test shell opens cleanly on Linux without macOS-specific errors |
| Partial state on failed run | Phase 1: Bootstrap script structure | `set -euo pipefail` header; trap for cleanup; guard clauses on every non-idempotent operation |
| Docker armhf deprecation | Phase for Docker installation | Install via official apt repo with explicit `arch=arm64`; verify with `docker compose version` |

---

## Sources

- [How to write idempotent Bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — concrete failure modes for non-idempotent operations (MEDIUM confidence, verified against common bash patterns)
- [Allow non-interactive install — ohmyzsh/ohmyzsh Issue #5675](https://github.com/ohmyzsh/ohmyzsh/issues/5675) — RUNZSH/CHSH environment variables for automation (HIGH confidence, official repo)
- [ohmyzsh/ohmyzsh install.sh](https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh) — source of truth for installer flags (HIGH confidence, official source)
- [Dotfiles Security: Why Your Public Dotfiles Are a Security Minefield](https://instatunnel.my/blog/why-your-public-dotfiles-are-a-security-minefield) — credential leak patterns in dotfiles (MEDIUM confidence)
- [GitHub Secret Leaks: 39 Million Credentials in 2024](https://medium.com/@instatunnel/github-secret-leaks-the-13-million-api-credentials-sitting-in-public-repos-1a3babfb68b1) — scope and speed of exploitation (MEDIUM confidence)
- [Back to Basics: sshd Hardening 2025](https://www.msbiro.net/posts/back-to-basics-sshd-hardening/) — SSH hardening sequence pitfalls (MEDIUM confidence)
- [How To Harden OpenSSH on Ubuntu — DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-harden-openssh-on-ubuntu-20-04) — keep second session open pattern (HIGH confidence, authoritative source)
- [Raspberry Pi OS (32-bit / armhf) Docker Docs](https://docs.docker.com/engine/install/raspberry-pi-os/) — Docker v29 dropping armhf support (HIGH confidence, official Docker docs)
- [ripgrep aarch64 musl not available — Issue #589](https://github.com/anomalyco/opencode/issues/589) — no aarch64-musl ripgrep build (HIGH confidence, GitHub issue)
- [Neovim ARM AppImage — Issue #8512](https://github.com/neovim/neovim/issues/8512) — AppImage is x86_64 only historically; ARM support is recent (HIGH confidence, official repo)
- [Properly setting $PATH for zsh on macOS (path_helper conflict)](https://gist.github.com/Linerre/f11ad4a6a934dcf01ee8415c9457e7b2) — macOS/Linux path_helper incompatibility (MEDIUM confidence)
- [Frictions and Complexities of Simple Scripts](https://www.lloydatkinson.net/posts/2024/frictions-and-complexities-of-simple-bash-scripts/) — bash script failure modes (MEDIUM confidence)
- [set -euo pipefail explanation](https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425) — strict mode for bash scripts (MEDIUM confidence, verified against bash docs)

---
*Pitfalls research for: server dotfiles / one-command bootstrap (Ubuntu x86_64 + Raspberry Pi ARM)*
*Researched: 2026-02-22*
