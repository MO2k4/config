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

## Secret scanning

Commits to this repo are scanned for secrets by [gitleaks](https://github.com/gitleaks/gitleaks),
wired in through the [pre-commit](https://pre-commit.com/) framework. A commit that introduces a
secret (API key, token, private key, …) is blocked before it lands.

Because this machine sets `core.hooksPath` globally (for the DCO sign-off), the hooks are not active
on a fresh clone until you run the one-time bootstrap:

```bash
./setup.sh --brew   # installs pre-commit + gitleaks (skip if already installed)
./setup-hooks.sh    # wires the hooks into this repo
```

`setup-hooks.sh` points this repo's `core.hooksPath` at its own `.git/hooks` (shadowing the global
`~/.githooks` for this repo only — other repos are untouched) and installs the pre-commit dispatchers.
The DCO `Signed-off-by` trailer is still appended automatically, now via a pre-commit hook.

To bypass scanning for a single commit (rare, intentional cases only):

```bash
git commit --no-verify        # skips ALL hooks (also skips the sign-off)
SKIP=gitleaks git commit      # skips only gitleaks, keeps the sign-off
```

## Daily workflow

Files in `~` are symlinks pointing into this repo. Edit them as normal:

```bash
# Edit your shell config
vim ~/.zshrc

# Changes are already in the repo
cd ~/Work/config
git add -A && git commit -m "Update zshrc" && git push
```
