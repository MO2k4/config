# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A symlink-based dotfiles repository for macOS/zsh. Files are stored without dot prefixes (e.g., `shell/zshrc` not `shell/.zshrc`) for visibility. The install script `setup.sh` creates symlinks from `~` back into this repo, so editing `~/.zshrc` directly modifies `shell/zshrc` in the repo.

## Key commands

- `./setup.sh` — Create symlinks (idempotent, safe to re-run)
- `./setup.sh --brew` — Also install Homebrew packages from `Brewfile`
- `brew bundle dump --file=Brewfile --force` — Regenerate Brewfile from currently installed packages

## Architecture

```
setup.sh          → Idempotent symlink installer (bash, ln -sf)
Brewfile          → Homebrew packages (brews, casks, vscode extensions, go/cargo)
shell/            → zshrc, zshenv, zprofile, bashrc   →  ~/.<file>
git/              → gitconfig                         →  ~/.<file>
vim/              → vimrc                             →  ~/.<file>
mise/             → config.toml                       →  ~/.config/mise/config.toml
prompt/           → Oh-my-posh themes, az.completion  →  ~/<file> or ~/.<dir>/<file>
```

## How setup.sh works

The `link()` function handles three cases:
1. **Symlink already correct** → skip (prints "OK")
2. **Real file exists** → back up to `<file>.bak`, then symlink
3. **Nothing exists** → create symlink directly

To add a new dotfile: place it in the appropriate directory, then add a `link` call in `setup.sh`.

## Files intentionally not tracked

Credential files: `~/.npmrc`, `~/.netrc`, `~/.yarnrc`, `~/.docker/config.json`, `~/.config/gh/hosts.yml`. Never add these to the repo.
