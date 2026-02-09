#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$DOTFILES/Brewfile"

if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew not found." >&2
    exit 1
fi

echo "Updating Brewfile..."
brew bundle dump --file="$BREWFILE" --force

if git -C "$DOTFILES" diff --quiet "$BREWFILE" 2>/dev/null; then
    echo "Brewfile is already up to date."
else
    echo ""
    echo "Changes:"
    git -C "$DOTFILES" diff "$BREWFILE" || diff /dev/null /dev/null
    echo ""
    echo "Brewfile updated. Review and commit when ready."
fi
