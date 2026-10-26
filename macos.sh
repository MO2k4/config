#!/bin/bash
set -euo pipefail

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock wvous-br-corner -int 14 # Quick Note
defaults write com.apple.dock wvous-br-modifier -int 0

# Appearance, input
defaults write -g AppleInterfaceStyle Dark
defaults write -g AppleShowAllExtensions -bool true
defaults write -g com.apple.swipescrolldirection -bool false # needs a re-login

# Finder
defaults write com.apple.finder FXPreferredViewStyle Nlsv # list view
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope SCcf # current folder

# Screenshots
defaults write com.apple.screencapture style window

killall Dock Finder SystemUIServer 2>/dev/null || true
echo "Done. Log out and back in for the scroll direction."
