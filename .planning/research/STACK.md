# Stack Research

**Domain:** Server dotfiles / one-command bootstrap system
**Researched:** 2026-02-22
**Confidence:** HIGH (core approach verified via official docs + multiple sources)

## Summary Recommendation

**Use pure bash scripts + GNU stow.** No external tool dependencies (no chezmoi binary, no Ansible, no Python). A self-contained `install.sh` fetches the repo, installs packages via apt + GitHub release binaries, then uses stow to symlink dotfiles into `$HOME`. This approach works identically on Ubuntu x86_64 and Raspberry Pi ARM64 with zero bootstrap dependencies beyond bash, curl, and git.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 5.x (system) | Bootstrap orchestrator | Zero dependencies - every Ubuntu/RPi server has bash. No install step needed. Write once, runs everywhere. |
| GNU Stow | 2.3+ (apt) | Dotfile symlink management | Creates `$HOME` symlinks from repo directory structure. Idempotent by design. Available via apt on all Debian targets. Simpler than chezmoi for static configs. |
| Git | 2.x (apt) | Repo fetching and version control | Standard; bootstrap clones repo then stow deploys it. |
| curl | System | Downloading binaries and install scripts | Present on all Ubuntu/RPi images. Used to fetch GitHub release binaries and install scripts. |

### Shell Environment Stack

| Tool | Install Method | Architecture Support | Why |
|------|---------------|---------------------|-----|
| zsh | `apt install zsh` | All (in apt repo) | Target shell. Available in apt, no arch issues. |
| oh-my-zsh | Official install.sh with `--unattended` flag | All (shell script, no binary) | Standard plugin/theme framework for zsh. `--unattended` prevents interactive prompts on server install. Plugins installed via `git clone` into `$ZSH_CUSTOM/plugins/`. |
| starship | `curl -sS https://starship.rs/install.sh \| sh` | x86_64 + aarch64 (official binaries) | Cross-platform prompt. Official install script auto-detects arch and installs the correct binary. Re-running updates cleanly. |
| tmux | `apt install tmux` | All (in apt repo) | Terminal multiplexer. apt version (3.3a on Ubuntu 24.04) is sufficient. No need to compile from source. |

### Modern CLI Tools Install Strategy

All tools below have official ARM64/aarch64 Linux binaries on GitHub Releases. Use a shared `install_github_binary()` function that detects arch via `uname -m` and constructs the correct download URL.

| Tool | Repo | Install Method | ARM64 Asset Pattern | Notes |
|------|------|---------------|---------------------|-------|
| ripgrep | `BurntSushi/ripgrep` | GitHub Release tarball | `ripgrep-{ver}-aarch64-unknown-linux-gnu.tar.gz` | v14.1.0+ has aarch64 binaries. GNU libc (not musl) on arm64. |
| fd | `sharkdp/fd` | GitHub Release tarball | `fd-v{ver}-aarch64-unknown-linux-gnu.tar.gz` | aarch64 builds available. Ubuntu apt installs as `fdfind` binary — use GitHub release for correct name `fd`. |
| fzf | `junegunn/fzf` | Official install script: `git clone + ./install` OR GitHub release | `fzf-{ver}-linux_arm64.tar.gz` | Has its own install script that handles arch. |
| eza | `eza-community/eza` | GitHub Release tarball | `eza_aarch64-unknown-linux-gnu.tar.gz` | v0.23.4+ confirmed aarch64 assets. Replaces deprecated `exa`. |
| bat | `sharkdp/bat` | GitHub Release .deb | `bat_{ver}_arm64.deb` | Provides .deb packages, use `dpkg -i`. Ubuntu apt installs as `batcat` — use GitHub .deb for correct `bat` binary name. |
| delta | `dandavison/delta` | GitHub Release .deb | `git-delta_{ver}_arm64.deb` | Provides .deb packages for ARM64. Ubuntu 24.04 includes v0.18.2 in apt — prefer GitHub release for latest. |
| neovim | `neovim/neovim` | GitHub Release AppImage/tarball | `nvim-linux-arm64.appimage` | Official ARM64 AppImage since v0.10.4. For ARM64 prefer tarball (`nvim-linux-arm64.tar.gz`) over AppImage for server use (no FUSE needed). |

### Infrastructure Tools

| Tool | Install Method | Notes |
|------|---------------|-------|
| Docker Engine | `curl -fsSL https://get.docker.com \| sh` | Official convenience script. Installs Docker Engine + Compose plugin + containerd. Handles both x86_64 and ARM64 automatically. Sufficient for personal/homelab use. |
| Docker Compose | Included with Docker via get.docker.com | As of Docker Engine 23+, compose is a plugin (`docker compose`), not a separate binary. get.docker.com installs it. |
| OpenSSH Server | Pre-installed on Ubuntu/RPi | Hardened via `sshd_config` modifications: `PasswordAuthentication no`, `PubkeyAuthentication yes`, `PermitRootLogin no`. Script deploys user's `authorized_keys`. |

### Supporting Libraries / oh-my-zsh Plugins

| Plugin/Tool | Install Method | Purpose |
|-------------|---------------|---------|
| zsh-autosuggestions | `git clone` to `$ZSH_CUSTOM/plugins/` | Fish-like command suggestions. Standard OMZ plugin install pattern. |
| zsh-syntax-highlighting | `git clone` to `$ZSH_CUSTOM/plugins/` | Syntax coloring as you type. |
| zsh-completions | `git clone` to `$ZSH_CUSTOM/plugins/` | Extended tab completion. |

---

## Architecture Detection Pattern

This is the core pattern for multi-arch binary installation. Use `uname -m` and map to GitHub naming conventions:

```bash
detect_arch() {
    local machine
    machine="$(uname -m)"
    case "${machine}" in
        x86_64)  echo "x86_64" ;;   # for tools using x86_64 naming
        aarch64) echo "aarch64" ;;   # for tools using aarch64 naming
        armv7l)  echo "armv7"   ;;   # 32-bit ARM (older RPi models)
        *)
            echo "Unsupported architecture: ${machine}" >&2
            exit 1
            ;;
    esac
}

# GitHub naming varies by project. Some use amd64/arm64 (Debian convention),
# others use x86_64/aarch64 (GNU triple convention). Map per-tool:
detect_arch_deb() {
    case "$(uname -m)" in
        x86_64)  echo "amd64"   ;;
        aarch64) echo "arm64"   ;;
    esac
}
```

---

## Idempotency Patterns

Every install step must be safe to re-run. These patterns prevent errors on second+ runs:

```bash
# Check before installing binary
command -v rg &>/dev/null || install_ripgrep

# Check before apt install
dpkg -l zsh &>/dev/null || apt-get install -y zsh

# Check before git clone (plugins, oh-my-zsh)
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# Check before stow (stow itself is idempotent with -R flag)
stow --dir="$DOTFILES_DIR" --target="$HOME" --restow zsh tmux

# Check before modifying sshd_config
grep -q "PasswordAuthentication no" /etc/ssh/sshd_config || \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
```

---

## Secrets Handling

**Rule: Zero secrets in the repo. All sensitive values fetched at runtime.**

| Approach | When to Use | How |
|----------|-------------|-----|
| Environment variables | SSH public key URL, GitHub token for private config | Caller exports before running: `SSH_KEY_URL=... curl \| bash` |
| 1Password CLI (`op`) | If user has 1Password — inject secrets at bootstrap | `op read "op://vault/item/field"` in bootstrap script |
| Bitwarden CLI (`bw`) | If user has Bitwarden — same pattern | `bw get password item-name` after `bw unlock` |
| `pass` (GPG-based) | Existing pass store on machine | `pass show server/ssh-key` |
| Manual prompt | Fallback: ask user to paste key | `read -r -p "Paste SSH public key: " SSH_PUB_KEY` |

**Recommended default:** Accept `SSH_PUB_KEY` as an environment variable. Document usage:
```bash
SSH_PUB_KEY="ssh-ed25519 AAAA..." bash <(curl -fsSL https://raw.githubusercontent.com/.../install.sh)
```

**For config files with secrets (e.g., `.gitconfig` with signing key):** Use stow to deploy a template, then prompt for the value and write it only to the live file — never to the repo.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Bootstrap orchestrator | Pure bash | Ansible | Ansible requires Python 3 + pip install on target. Overkill for single-user, single-role, personal server. Idempotency can be achieved in bash with check patterns. |
| Bootstrap orchestrator | Pure bash | chezmoi | chezmoi is excellent but adds a binary bootstrap dependency. The "get chezmoi" one-liner fetches a binary, then chezmoi fetches config — that's two networked steps. For a server with no prior state, bash + git + stow is simpler. |
| Dotfile management | GNU Stow | chezmoi | chezmoi has better templating for multi-machine secrets, but adds complexity. For a single config profile (no per-machine differences beyond arch), stow is sufficient and already in apt. |
| Dotfile management | GNU Stow | rcm (Thoughtbot) | rcm requires Homebrew or manual install on Linux. Extra dependency. |
| Dotfile management | GNU Stow | Bare git repo | Bare git (`git init --bare $HOME`) approach is clever but confusing to maintain and debug. Stow is more explicit. |
| CLI tool install | GitHub Release binaries | Homebrew on Linux | Homebrew on Raspberry Pi (aarch64) has inconsistent support. apt + GitHub releases is more reliable and faster. |
| CLI tool install | GitHub Release binaries | Cargo (build from source) | Building from source requires Rust toolchain (~1.5GB), takes minutes per tool. GitHub provides prebuilt binaries for all target tools. |
| Shell framework | oh-my-zsh | zinit / zplug | zinit is more performant but more complex to configure. oh-my-zsh is the standard — the goal is macOS parity with existing setup, not optimization. |
| Shell prompt | starship | powerlevel10k | p10k requires a Zsh-specific theme setup and manual configuration wizard. starship is shell-agnostic, has official Linux ARM64 binaries, and is configured via TOML — easier to commit to repo. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `apt install bat` | Installs as `batcat` binary on Ubuntu, not `bat`. Breaks aliases and scripts. | GitHub Release .deb which installs as `bat` |
| `apt install fd-find` | Installs as `fdfind` binary, not `fd`. Same naming issue as bat. | GitHub Release tarball which provides `fd` binary |
| `apt install neovim` | Ubuntu 22.04 LTS ships neovim 0.6 (2021). Ubuntu 24.04 ships 0.9.5. Current stable is 0.10.x. The apt version is significantly behind. | GitHub Release AppImage/tarball for current stable |
| `apt install eza` | `eza` is not in Ubuntu apt repos (it's a newer community fork of `exa`). `exa` is in apt but deprecated. | GitHub Release tarball from `eza-community/eza` |
| Ansible | Requires Python 3 + pip on target server, adds ~200MB of dependencies for a personal dotfiles setup | Pure bash |
| Homebrew on Linux (for server) | Inconsistent ARM64/aarch64 support on Raspberry Pi, requires additional setup, slow on RPi hardware | apt + GitHub Release binaries |
| Committing any credential | Public repo — any committed key/token is permanently in git history even after deletion | Environment variables or password manager CLI at runtime |
| `curl URL \| bash` without pinning | Mutable URLs can serve different content on re-run. Idempotency assumption breaks. | Download, verify, then execute — OR accept this tradeoff consciously for personal tool |
| `exa` | Deprecated. Maintainer abandoned project in 2023. Community forked to `eza`. | `eza` from `eza-community/eza` |

---

## Stack Patterns by Variant

**For Raspberry Pi (ARM64 / aarch64):**
- Use `aarch64-unknown-linux-gnu` asset patterns (not musl — musl isn't consistently available for all tools on ARM)
- Neovim: use `nvim-linux-arm64.tar.gz` not AppImage (AppImage requires FUSE which may not be configured)
- Docker: `get.docker.com` handles ARM64 automatically
- starship: install script handles arch detection

**For Ubuntu VPS (x86_64 / amd64):**
- Prefer `.deb` packages for bat and delta (cleaner dpkg management)
- Neovim AppImage works well on x86_64 Ubuntu

**For fresh server with no existing state:**
- Run `apt-get update` once at start of script, install all apt packages in a single `apt-get install -y` call
- Then install GitHub release tools in parallel or sequentially

**For updating an existing install (idempotent re-run):**
- Check versions before re-downloading binaries
- `stow --restow` safely re-applies symlinks
- oh-my-zsh: `omz update` (not re-running install.sh)

---

## Version Compatibility Notes

| Component | Constraint | Notes |
|-----------|-----------|-------|
| oh-my-zsh | Always installs latest | No pinning supported; auto-update can be disabled with `DISABLE_AUTO_UPDATE=true` in `.zshrc` |
| starship | Install script fetches latest | Re-run to update. Config is TOML in `~/.config/starship.toml` — fully portable across versions. |
| Docker | get.docker.com installs latest stable | Not suitable for upgrading existing Docker (script warns about this). Fine for fresh installs. |
| bat + delta | Must use compatible versions | delta's Cargo.toml specifies the bat version it's built against. When installing from .deb, this is handled. When mixing sources, check delta release notes. |
| neovim | 0.10.x+ recommended | AppImage ARM64 support starts at 0.10.4. |
| Ubuntu target | 22.04 LTS or 24.04 LTS | 24.04 preferred (supported until 2029). Script should check `lsb_release -cs` and warn on other versions. |
| Raspberry Pi OS | Bookworm (Debian 12) | Based on Debian 12, same `apt` patterns as Ubuntu. aarch64 binaries work. |

---

## Installation Sketch

```bash
# 1. Bootstrap: one-liner to start
# SSH_PUB_KEY="ssh-ed25519 ..." bash <(curl -fsSL https://raw.githubusercontent.com/USER/server-dotfiles/main/install.sh)

# 2. System packages (single apt call)
sudo apt-get update -qq
sudo apt-get install -y \
    zsh tmux git curl wget stow \
    build-essential ca-certificates gnupg \
    unzip tar

# 3. oh-my-zsh (unattended)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 4. oh-my-zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# 5. starship (detects arch automatically)
curl -sS https://starship.rs/install.sh | sh -s -- -y

# 6. GitHub release binaries (arch-aware function)
ARCH=$(uname -m)  # x86_64 or aarch64
install_ripgrep   # fetches ripgrep-{ver}-${ARCH}-unknown-linux-gnu.tar.gz
install_fd        # fetches fd-v{ver}-${ARCH}-unknown-linux-gnu.tar.gz
install_fzf       # via fzf's own install script or release tarball
install_eza       # fetches eza_${ARCH}-unknown-linux-gnu.tar.gz
install_bat       # fetches bat_{ver}_${arch_deb}.deb (uses amd64/arm64 naming)
install_delta     # fetches git-delta_{ver}_${arch_deb}.deb
install_neovim    # fetches nvim-linux-${arch_nvim}.tar.gz

# 7. Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

# 8. Deploy dotfiles via stow
git clone https://github.com/USER/server-dotfiles "$HOME/.dotfiles"
stow --dir="$HOME/.dotfiles" --target="$HOME" --restow zsh tmux git starship

# 9. SSH hardening
# - Install authorized_keys from $SSH_PUB_KEY env var
# - Modify /etc/ssh/sshd_config
# - Reload sshd

# 10. Change default shell to zsh
chsh -s "$(which zsh)" "$USER"
```

---

## Sources

- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/) — chezmoi vs stow vs alternatives (HIGH confidence, official docs)
- [dotfiles.github.io bootstrap](https://dotfiles.github.io/bootstrap/) — community bootstrap patterns (MEDIUM confidence, curated community resource)
- [felipecrs/dotfiles](https://github.com/felipecrs/dotfiles) — real-world chezmoi + bash approach (MEDIUM confidence, production project)
- [starship.rs](https://starship.rs/) — official install script, arch support (HIGH confidence, official docs)
- [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) — `--unattended` flag, `$ZSH_CUSTOM` plugin pattern (HIGH confidence, official repo)
- [docker/docker-install](https://github.com/docker/docker-install) — get.docker.com convenience script (HIGH confidence, official Docker repo)
- [neovim ARM64 AppImage issue #15143](https://github.com/neovim/neovim/issues/15143) — ARM64 AppImage since v0.10.4 (HIGH confidence, official issue tracker)
- [eza-community/eza releases](https://github.com/eza-community/eza/releases) — v0.23.4 aarch64 assets confirmed (HIGH confidence, official releases)
- [BurntSushi/ripgrep releases](https://github.com/BurntSushi/ripgrep/releases) — v14.1.0+ aarch64-unknown-linux-gnu (HIGH confidence, official releases)
- [dandavison/delta installation](https://dandavison.github.io/delta/installation.html) — .deb packages for ARM64 (MEDIUM confidence, official docs, ARM64 CI breakage noted in some releases)
- [arslan.io idempotent bash](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — idempotency patterns (MEDIUM confidence, widely cited community reference)
- [1Password secrets in dotfiles](https://samedwardes.com/blog/2023-11-03-1password-for-secret-dotfiles/) — secrets via password manager CLI (MEDIUM confidence, documented approach)
- [SSH hardening 2025 sshd_config](https://www.msbiro.net/posts/back-to-basics-sshd-hardening/) — current sshd_config best practices (MEDIUM confidence, practitioner blog with 2025 date)

---

*Stack research for: server-dotfiles bootstrap system (Ubuntu x86_64 + Raspberry Pi ARM64)*
*Researched: 2026-02-22*
