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
link "shell/zshrc"      "$HOME/.zshrc"
link "shell/zshenv"     "$HOME/.zshenv"
link "shell/zprofile"   "$HOME/.zprofile"
link "shell/bashrc"     "$HOME/.bashrc"
link "shell/zshrc.d"    "$HOME/.zshrc.d"
link "shell/functions"  "$HOME/.zsh-functions"

# Git
link "git/gitconfig"         "$HOME/.gitconfig"
link "git/gitconfig-github"  "$HOME/.gitconfig-github"

# Vim
link "vim/vimrc" "$HOME/.vimrc"

# Mise (runtime version manager)
link "mise/config.toml" "$HOME/.config/mise/config.toml"

# iTerm2
# link "iterm2/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"

# Prompt / Oh-my-posh
link "prompt/claude.omp.json"                        "$HOME/claude.omp.json"
link "prompt/poshthemes/craver_custom.omp.json"      "$HOME/.poshthemes/craver_custom.omp.json"
link "prompt/az.completion"                          "$HOME/az.completion"

# Homebrew
if [ "${1:-}" = "--brew" ]; then
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing..."
        tmpfile=$(mktemp)
        curl -fSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$tmpfile"
        /bin/bash "$tmpfile"
        rm -f "$tmpfile"
    fi
    echo "Installing Homebrew packages..."
    brew bundle --file="$DOTFILES/Brewfile" --no-lock
fi

echo "Done."
