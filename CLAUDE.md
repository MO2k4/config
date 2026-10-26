# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A symlink-based dotfiles repository for macOS/zsh. Files are stored without dot prefixes (e.g., `shell/zshrc` not `shell/.zshrc`) for visibility. The install script `setup.sh` creates symlinks from `~` back into this repo, so editing `~/.zshrc` directly modifies `shell/zshrc` in the repo.

## Key commands

- `./setup.sh` — Create symlinks (idempotent, safe to re-run)
- `./setup.sh --brew` — Also install Homebrew packages from `Brewfile`
- `./macos.sh` — Apply macOS settings (Dock, Finder, appearance, screenshots); re-run safe
- `./clone-org.sh [org] [dir]` — Clone every non-archived repo of a GitHub org that is missing locally (default `ais-schule` into `~/Work/ais`)
- `./skills.sh dump` / `./skills.sh install` — Snapshot global agent skills (`npx skills`) to `skills.txt` / reinstall them, plus link the own skills from `~/Work/github/claude-skills`
- `brew bundle dump --file=Brewfile --force` — Regenerate Brewfile from currently installed packages

## Architecture

```text
setup.sh          → Idempotent symlink installer (bash, ln -sf)
Brewfile          → Homebrew packages (brews, casks, vscode extensions, go/cargo)
shell/            → zshrc, zshenv, zprofile, bashrc   →  ~/.<file>
git/              → gitconfig, gitignore_global       →  ~/.<file>
gh/               → config.yml                        →  ~/.config/gh/config.yml
claude/           → CLAUDE.md, hooks/*                →  ~/.claude/ (settings.json not tracked: holds per-repo autoMode)
githooks/         → global hook dispatcher + drop-ins →  ~/.githooks (core.hooksPath; DCO sign-off)
husky/            → init.sh                           →  ~/.config/husky/init.sh (husky repos → ~/.githooks)
vim/              → vimrc                             →  ~/.<file>
iterm2/           → com.googlecode.iterm2.plist       →  ~/Library/Preferences/ (copied, not symlinked)
mise/             → config.toml                       →  ~/.config/mise/config.toml
x11/              → xinitrc.d/                        →  ~/.xinitrc.d (XQuartz runs *.sh on start)
ghostty/          → config                            →  ~/Library/Application Support/com.mitchellh.ghostty/config
herdr/            → config.toml                       →  ~/.config/herdr/config.toml
prompt/           → Oh-my-posh themes, az.completion  →  ~/<file> or ~/.<dir>/<file>
```

> **Note on iTerm2:** iTerm2 is copied (not symlinked) because macOS's cfprefsd preference daemon
> uses atomic writes that break symlinks. Run `./update-iterm2.sh` to snapshot current settings
> back into the repo before committing.

## How setup.sh works

The `link()` function handles three cases:

1. **Symlink already correct** → skip (prints "OK")
2. **Real file exists** → back up to `<file>.bak`, then symlink
3. **Nothing exists** → create symlink directly

To add a new dotfile: place it in the appropriate directory, then add a `link` call in `setup.sh`.

## Files intentionally not tracked

Credential files: `~/.npmrc`, `~/.netrc`, `~/.yarnrc`, `~/.docker/config.json`, `~/.config/gh/hosts.yml`. Never add these to the repo.
