# Dotfiles

My macOS configuration files, managed with symlinks.

## What's included

| Repo path | Symlinked to |
|---|---|
| `shell/zshrc` | `~/.zshrc` |
| `shell/zshenv` | `~/.zshenv` |
| `shell/zprofile` | `~/.zprofile` |
| `shell/bashrc` | `~/.bashrc` |
| `git/gitconfig` | `~/.gitconfig` |
| `git/gitconfig-alt` | `~/.gitconfig-alt` |
| `vim/vimrc` | `~/.vimrc` |
| `prompt/claude.omp.json` | `~/claude.omp.json` |
| `prompt/poshthemes/craver_custom.omp.json` | `~/.poshthemes/craver_custom.omp.json` |
| `prompt/az.completion` | `~/az.completion` |
| `mise/config.toml` | `~/.config/mise/config.toml` |

## Quick start

```bash
git clone git@github.com:MO2k4/config.git ~/Work/config
cd ~/Work/config
./setup.sh
```

## Homebrew packages

Install all Homebrew packages from the Brewfile:

```bash
./setup.sh --brew
```

## Files NOT tracked (secrets)

These files contain credentials and are intentionally excluded:

- `~/.npmrc`
- `~/.netrc`
- `~/.yarnrc`
- `~/.docker/config.json`
- `~/.config/gh/hosts.yml`

## Daily workflow

Files in `~` are symlinks pointing into this repo. Edit them as normal:

```bash
# Edit your shell config
vim ~/.zshrc

# Changes are already in the repo
cd ~/Work/config
git add -A && git commit -m "Update zshrc" && git push
```
