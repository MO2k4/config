#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

cp ~/Library/Preferences/com.googlecode.iterm2.plist "$DOTFILES/iterm2/com.googlecode.iterm2.plist"
echo "Updated iterm2/com.googlecode.iterm2.plist from live preferences"
git -C "$DOTFILES" diff iterm2/
