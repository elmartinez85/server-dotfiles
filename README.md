# server-dotfiles

One command turns a bare Ubuntu or Raspberry Pi server into a fully-configured, familiar environment.

```bash
curl -fsSL https://raw.githubusercontent.com/elmartinez85/server-dotfiles/main/bootstrap.sh | bash
```

## What gets installed

**Shell environment**
- zsh (set as default shell) + oh-my-zsh
- [Starship](https://starship.rs) prompt
- tmux
- zsh-autosuggestions + zsh-syntax-highlighting

**CLI tools** (from GitHub Releases, pinned versions)
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) — fast grep replacement
- [fd](https://github.com/sharkdp/fd) — fast find replacement
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder
- [eza](https://github.com/eza-community/eza) — modern `ls`
- [bat](https://github.com/sharkdp/bat) — `cat` with syntax highlighting
- [delta](https://github.com/dandavison/delta) — better git diffs
- [neovim](https://neovim.io) (`nvim`)

**Docker**
- Docker Engine + Docker Compose plugin (via official apt repo)
- [lazydocker](https://github.com/jesseduffield/lazydocker) — terminal UI for containers

**Shell configs** deployed as symlinks from this repo:
- `~/.zshrc`, `~/.zsh_aliases`, `~/.tmux.conf`, `~/.config/starship.toml`

## Requirements

- Ubuntu LTS (x86_64) or Raspberry Pi OS / Ubuntu (ARM64)
- Root or sudo access
- Internet connectivity during bootstrap

## Dry run

Preview what the script would do without making any changes:

```bash
curl -fsSL https://raw.githubusercontent.com/elmartinez85/server-dotfiles/main/bootstrap.sh | bash -s -- --dry-run
```

## Idempotent

Safe to re-run. Already-installed tools are skipped, existing config files are backed up to `~/.dotfiles.bak/` before symlinks are created.

## After bootstrap

Log back in to start a new zsh session, then run the verification script to confirm everything installed correctly:

```bash
~/.dotfiles/scripts/verify.sh
```

## Post-bootstrap manual steps

Docker group membership requires a re-login to take effect. After logging back in, `docker run hello-world` should work without sudo.

## Pinned versions

All tool versions are defined in [`lib/versions.sh`](lib/versions.sh). Update a version there and re-run bootstrap to upgrade.

| Tool | Version |
|------|---------|
| gitleaks | 8.30.0 |
| ripgrep | 15.1.0 |
| fd | 10.3.0 |
| fzf | 0.68.0 |
| eza | 0.23.4 |
| bat | 0.26.1 |
| delta | 0.18.2 |
| neovim | 0.11.6 |
| lazydocker | 0.24.4 |

## Repo structure

```
bootstrap.sh          # Entry point — curl | bash target
lib/
  log.sh              # Logging helpers
  os.sh               # Architecture detection
  pkg.sh              # Idempotent apt wrapper
  versions.sh         # Pinned tool versions
scripts/
  install-shell.sh    # zsh, oh-my-zsh, starship, tmux, plugins
  install-tools.sh    # Seven CLI tools
  install-docker.sh   # Docker Engine, Compose, lazydocker
  install-gitleaks.sh # Secret prevention (pre-commit hook)
  verify.sh           # Post-bootstrap checks
dotfiles/
  .zshrc
  .zsh_aliases
  .tmux.conf
  starship.toml
hooks/
  pre-commit          # Blocks commits containing secrets (gitleaks)
```

## Secret prevention

A gitleaks pre-commit hook is installed in the cloned repo. Attempting to commit a file containing a secret will block the commit.
