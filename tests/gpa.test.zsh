#!/usr/bin/env zsh
# Functional tests for the `gpa` autoloaded function (shell/functions/gpa).
#
# Pure zsh + git, no external test framework and no network. Builds throwaway
# local git repos under a mktemp dir, runs gpa against them, and asserts on the
# one-line-per-repo output and the summary line.
#
# Run:  zsh tests/gpa.test.zsh
# Exit: 0 = all assertions passed, 1 = at least one failed.

emulate -L zsh
set -u

# Hermetic git identity so the suite needs no ~/.gitconfig.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# Load the function under test via real autoload, mirroring shell/zshrc.
SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
fpath=("$REPO_ROOT/shell/functions" $fpath)
autoload -Uz gpa

# --- tiny assertion helper -------------------------------------------------
typeset -i FAILS=0
check() {  # check <description> <expected-substring> <actual-output>
  if [[ "$3" == *"$2"* ]]; then
    print -r -- "ok   - $1"
  else
    print -r -- "FAIL - $1"
    print -r -- "       expected substring: $2"
    print -r -- "       actual output:"
    print -r -- "$3" | sed 's/^/         | /'
    (( FAILS++ ))
  fi
}

# --- fixtures --------------------------------------------------------------
TMP=$(mktemp -d)
cleanup() { [[ -n "${TMP:-}" && -d "$TMP" ]] && rm -rf -- "$TMP"; }
trap cleanup EXIT

# Bare upstream on `main` with one commit, plus a seed clone to push from.
git init -q -b main --bare "$TMP/upstream.git"
git clone -q "$TMP/upstream.git" "$TMP/seed"
print v1 > "$TMP/seed/f"
git -C "$TMP/seed" add f
git -C "$TMP/seed" commit -qm c1
git -C "$TMP/seed" push -q -u origin main

WORK="$TMP/work"; mkdir -p "$WORK"
mkclone() {  # mkclone <name> : clone upstream and pin origin/HEAD locally
  git clone -q "$TMP/upstream.git" "$WORK/$1"
  git -C "$WORK/$1" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
}

mkclone api          # left behind the remote -> updated
mkclone web          # brought current -> up to date
mkclone billing      # dirty working tree -> skipped
mkclone infra        # on a feature branch -> skipped
mkclone legacy       # broken remote -> pull fails
mkdir "$WORK/plain"  # not a git repo -> silently ignored

# Advance the remote by two commits, then bring `web` (only) current.
print v2 >> "$TMP/seed/f"; git -C "$TMP/seed" commit -qam c2
print v3 >> "$TMP/seed/f"; git -C "$TMP/seed" commit -qam c3
git -C "$TMP/seed" push -q
git -C "$WORK/web" pull -q --rebase

print scratch >> "$WORK/billing/f"                 # dirty
git -C "$WORK/infra" checkout -q -b feat/vpc       # feature branch
git -C "$WORK/legacy" remote set-url origin /nonexistent/path.git  # broken remote

# === Test A: full sweep over a multi-repo root ===
out=$(gpa "$WORK")
check "api reports new commits"      "✓ api"                                       "$out"
check "api counts 2 new commits"     "2 new commit(s)"                             "$out"
check "web up to date"               "= web  up to date"                           "$out"
check "billing skipped dirty"        "⊘ billing  skipped (uncommitted changes)"    "$out"
check "infra skipped feature branch" "⊘ infra  skipped (on feat/vpc, not main)"    "$out"
check "legacy pull failed"           "✗ legacy  pull failed"                       "$out"
check "summary tallies"              "— 1 updated, 1 up-to-date, 2 skipped, 1 failed" "$out"
if [[ "$out" != *plain* ]]; then
  print -r -- "ok   - plain (non-git) produced no line"
else
  print -r -- "FAIL - plain (non-git) produced a line"; (( FAILS++ ))
fi

# === Test B: default-branch fallback via `remote show origin` ===
# Delete the local origin/HEAD so symbolic-ref fails; gpa must fall back to
# `git remote show origin` to learn the default is `main`, then skip feat/x.
mkclone fallback
git -C "$WORK/fallback" symbolic-ref --delete refs/remotes/origin/HEAD
git -C "$WORK/fallback" checkout -q -b feat/x
outB=$(gpa "$WORK")
check "fallback detects default via remote show" "⊘ fallback  skipped (on feat/x, not main)" "$outB"

# === Test C: empty root is a no-op, not a glob error ===
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
outC=$(gpa "$EMPTY")
check "empty root summary" "— 0 updated, 0 up-to-date, 0 skipped, 0 failed" "$outC"

# === Test D: no argument defaults to the current directory ===
outD=$( cd "$WORK" && gpa )
check "default root is cwd" "= web  up to date" "$outD"

# --- result ----------------------------------------------------------------
print -r --
if (( FAILS )); then
  print -r -- "FAILED: $FAILS assertion(s)"
  exit 1
fi
print -r -- "All assertions passed."
