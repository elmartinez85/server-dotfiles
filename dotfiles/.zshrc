# .zshrc — managed by server-dotfiles
# Configures zsh with oh-my-zsh, plugins, aliases, and starship prompt.
# Linux-only (no macOS conditionals). Deployed as a symlink to $HOME/.zshrc.

# ---------------------------------------------------------------------------
# oh-my-zsh setup
# ---------------------------------------------------------------------------

export ZSH="${HOME}/.oh-my-zsh"

# MUST be empty string — starship replaces oh-my-zsh's theme system entirely.
# A named theme here causes two competing prompt systems and a broken prompt.
ZSH_THEME=""

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------

[[ -f "${HOME}/.zsh_aliases" ]] && source "${HOME}/.zsh_aliases"

# ---------------------------------------------------------------------------
# Starship prompt — MUST be the last line executed in this file.
# Placing this before oh-my-zsh source would cause oh-my-zsh to reset
# $PROMPT, making starship's prompt disappear. Double quotes are required
# since starship v1.17.0 (single quotes break the substitution).
# ---------------------------------------------------------------------------

eval "$(starship init zsh)"
