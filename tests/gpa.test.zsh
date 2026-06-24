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
print g1 > "$TMP/seed/g"   # extra files used by the --autostash tests below
print h1 > "$TMP/seed/h"
git -C "$TMP/seed" add f g h
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

# Behind-the-remote clones for the --autostash tests, kept in their own roots
# so the multi-repo sweep above never touches them. Cloned now, while upstream
# is still at c1, so they lag the commits pushed just below.
ASTASH="$TMP/astash"; mkdir -p "$ASTASH"
git clone -q "$TMP/upstream.git" "$ASTASH/mobile"
git -C "$ASTASH/mobile" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

CONFLICT="$TMP/conflict"; mkdir -p "$CONFLICT"
git clone -q "$TMP/upstream.git" "$CONFLICT/desktop"
git -C "$CONFLICT/desktop" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

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

# === Test E: --autostash pulls over a dirty tree and restores local work ===
# mobile lags by c2/c3 (both touch only `f`); the dirty edit is to `g`, so the
# stash reapplies cleanly after the rebase.
print local-change >> "$ASTASH/mobile/g"
outE=$(gpa --autostash "$ASTASH")
check "autostash repo updates"        "✓ mobile"                "$outE"
check "autostash notes preserved"     "(local changes preserved)" "$outE"
check "autostash restored local edit" "local-change"            "$(cat "$ASTASH/mobile/g")"

# Without the flag, the same dirty tree is still skipped (safe default).
print more >> "$ASTASH/mobile/g"
outE2=$(gpa "$ASTASH")
check "dirty still skipped by default" "⊘ mobile  skipped (uncommitted changes)" "$outE2"

# === Test F: --autostash surfaces a stash-pop conflict instead of hiding it ===
# Advance the remote on `h`, then make a diverging local edit to the same file
# so the autostash pop cannot apply cleanly.
print h-upstream > "$TMP/seed/h"; git -C "$TMP/seed" commit -qam c4
git -C "$TMP/seed" push -q
print h-local > "$CONFLICT/desktop/h"
outF=$(gpa --autostash "$CONFLICT")
check "autostash conflict reported" "✗ desktop  autostash conflict" "$outF"
check "autostash conflict counted"  "1 failed"                      "$outF"

# === Test G: unknown option is rejected ===
outG=$(gpa --bogus "$WORK" 2>&1); rcG=$?
check "unknown option message" "unknown option: --bogus" "$outG"
if (( rcG == 2 )); then
  print -r -- "ok   - unknown option exits 2"
else
  print -r -- "FAIL - unknown option exit code was $rcG, expected 2"; (( FAILS++ ))
fi

# --- result ----------------------------------------------------------------
print -r --
if (( FAILS )); then
  print -r -- "FAILED: $FAILS assertion(s)"
  exit 1
fi
print -r -- "All assertions passed."
