#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES"

# pre-commit is required and must actually run: a broken shim that resolves on
# PATH but fails to exec (e.g. a stale pip/mise script with a dead interpreter)
# is treated as "not installed". It is installed via Homebrew (see Brewfile).
if ! pre-commit --version >/dev/null 2>&1; then
    echo "Error: pre-commit not found (or not runnable) on PATH." >&2
    echo "Install it with:  ./setup.sh --brew   (or:  brew install pre-commit)" >&2
    exit 1
fi

# This repo's gitconfig sets core.hooksPath = ~/.githooks globally, which makes
# git ignore .git/hooks. Shadow it with a repo-LOCAL override pointing at this
# repo's own hooks dir, so pre-commit's dispatchers actually fire here. Other
# repos are unaffected — the global ~/.githooks still serves them.
HOOKS_DIR="$(git rev-parse --absolute-git-dir)/hooks"
git config --local core.hooksPath "$HOOKS_DIR"
echo "Set local core.hooksPath → $HOOKS_DIR"

# pre-commit refuses to install while core.hooksPath is set, UNLESS an explicit
# --git-dir is passed (which skips that guard). Install both hook types.
pre-commit install \
    --git-dir "$(git rev-parse --git-dir)" \
    -t pre-commit \
    -t prepare-commit-msg

echo "Done. Hooks installed for this repo."
