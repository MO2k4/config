#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
    local src="$DOTFILES/$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    # Already linked to the correct target — nothing to do
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "OK $dst (already linked)"
        return
    fi
    # Back up real files only (not symlinks)
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "Backing up $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    echo "Linked $dst → $src"
}

# Shell
link "shell/zshrc" "$HOME/.zshrc"
link "shell/zshenv" "$HOME/.zshenv"
link "shell/zprofile" "$HOME/.zprofile"
link "shell/bashrc" "$HOME/.bashrc"
link "shell/zshrc.d" "$HOME/.zshrc.d"
link "shell/functions" "$HOME/.zsh-functions"

# Git
link "git/gitconfig" "$HOME/.gitconfig"
link "git/gitconfig-github" "$HOME/.gitconfig-github"
link "git/gitignore_global" "$HOME/.gitignore_global"
# global hooks: gitconfig sets core.hooksPath = ~/.githooks; husky repos bridge back via init.sh
link "githooks" "$HOME/.githooks"
link "husky/init.sh" "$HOME/.config/husky/init.sh"

# Vim
link "vim/vimrc" "$HOME/.vimrc"

# Mise (runtime version manager)
link "mise/config.toml" "$HOME/.config/mise/config.toml"

# XQuartz (sourced on X server start by /opt/X11/etc/X11/xinit/xinitrc.d/98-user.sh)
link "x11/xinitrc.d" "$HOME/.xinitrc.d"

# Ghostty
link "ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Herdr
link "herdr/config.toml" "$HOME/.config/herdr/config.toml"

# GitHub CLI (hosts.yml holds the token and stays untracked)
link "gh/config.yml" "$HOME/.config/gh/config.yml"

# Claude Code
link "claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
for hook in claude/hooks/*; do
    link "$hook" "$HOME/.claude/hooks/$(basename "$hook")"
done

# iTerm2 — copy, not symlink (cfprefsd atomic writes break symlinks)
if [ ! -f "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]; then
    cp "$DOTFILES/iterm2/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    echo "Copied iTerm2 preferences"
fi

# Prompt / Oh-my-posh
link "prompt/claude.omp.json" "$HOME/claude.omp.json"
link "prompt/poshthemes/craver_custom.omp.json" "$HOME/.poshthemes/craver_custom.omp.json"
link "prompt/az.completion" "$HOME/az.completion"

# Homebrew
if [ "${1:-}" = "--brew" ]; then
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing..."
        tmpfile=$(mktemp)
        curl -fSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$tmpfile"
        /bin/bash "$tmpfile"
        rm -f "$tmpfile"
    fi
    # Same elevation as up() in shell/zshrc.d/aliases.zsh
    if ! id -Gn | grep -q '\badmin\b'; then
        PrivilegesCLI --add
        trap 'PrivilegesCLI --remove' EXIT
    fi
    # Some casks run pkg installers that prompt for sudo mid-run; ask up front instead
    echo "Some casks need admin rights, asking for your password now..."
    sudo -v
    echo "Installing Homebrew packages ($(grep -cE '^[a-z]+ "' "$DOTFILES/Brewfile") entries)..."
    # msodbcsql18/mssql-tools18 otherwise stop for an interactive EULA prompt buried in the output
    echo "Accepting the Microsoft ODBC/mssql-tools EULA: https://aka.ms/odbc18eula"
    HOMEBREW_ACCEPT_EULA=Y brew bundle --verbose --file="$DOTFILES/Brewfile"
fi

echo "Done."
