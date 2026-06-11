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

## Pre-commit checks

Commits to this repo run through a [pre-commit](https://pre-commit.com/) hook suite that catches
breakage and enforces consistency before anything lands. On commit it:

- **Scans for secrets** with [gitleaks](https://github.com/gitleaks/gitleaks) — a commit that
  introduces an API key, token, or private key is blocked.
- **Fixes hygiene** — strips trailing whitespace, enforces a single final newline, and normalizes
  line endings to LF (the iTerm2 plist is excluded).
- **Validates data files** — YAML, JSON, and TOML are parsed; merge-conflict markers and
  case-collision filenames are rejected; shebang/executable bits must agree.
- **Formats and lints bash** — `shfmt` (4-space, indented cases) rewrites the shell scripts and
  `shellcheck` flags issues, scoped to the bash files only.
- **Syntax-checks zsh** — `zsh -n` parses the `shell/` zsh configs.
- **Lints and fixes Markdown** — `markdownlint-cli2 --fix` tidies the docs.

Autofix hooks (whitespace, shfmt, markdown) rewrite files in place; if a commit is blocked because a
hook reformatted something, re-`git add` the changes and commit again.

Because this machine sets `core.hooksPath` globally (for the DCO sign-off), the hooks are not active
on a fresh clone until you run the one-time bootstrap:

```bash
./setup.sh --brew   # installs pre-commit + gitleaks (skip if already installed)
./setup-hooks.sh    # wires the hooks into this repo
```

The remaining tools (shfmt, shellcheck, markdownlint-cli2, the hygiene hooks) need no manual install
— pre-commit fetches and caches each one in its own environment on first run.

`setup-hooks.sh` points this repo's `core.hooksPath` at its own `.git/hooks` (shadowing the global
`~/.githooks` for this repo only — other repos are untouched) and installs the pre-commit dispatchers.
The DCO `Signed-off-by` trailer is still appended automatically, now via a pre-commit hook.

To bypass checks for a single commit (rare, intentional cases only):

```bash
git commit --no-verify              # skips ALL hooks (also skips the sign-off)
SKIP=gitleaks git commit            # skips only gitleaks, keeps everything else
SKIP=shellcheck,shfmt git commit    # skip specific hooks by id (comma-separated)
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
