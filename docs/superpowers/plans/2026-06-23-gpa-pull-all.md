# `gpa` Pull-All with Skip-and-Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline `gpa()` alias with an autoloaded `shell/functions/gpa` that rebase-pulls each immediate subfolder's git repo, skipping (and reporting) dirty or off-default-branch repos, with quiet one-line-per-repo output.

**Architecture:** A single zsh function, autoloaded from `shell/functions/` (already on `fpath` via the `~/.zsh-functions` symlink). It iterates immediate subdirectories with a `(N)` glob, classifies each repo (dirty → skip, off-default-branch → skip, else `git pull --rebase --quiet`), and prints one glyph-prefixed status line per repo plus a summary tally. A pure-zsh functional test harness (`tests/gpa.test.zsh`) builds throwaway local git repos and asserts on the output — no external test framework or network.

**Tech Stack:** zsh (autoload functions, glob qualifiers, `print -r`), git (`status --porcelain`, `symbolic-ref`, `pull --rebase`, `rev-list`), and the repo's existing `pre-commit` (`zsh -n` syntax check, markdownlint).

## Global Constraints

These apply to every task; copied verbatim from the spec.

- **zsh only.** The function uses zsh-specific syntax (`(N)` glob qualifier, `${...:t}` modifier, `print -r`). It is not bash-compatible. Do not add a `#!` line — autoloaded function files have none (see `shell/functions/grb`, `gwt`).
- **Autoload self-invoke pattern.** The file is a function definition followed by `gpa "$@"` at the very bottom, exactly matching `shell/functions/grb` and `shell/functions/gwt`.
- **Quiet output.** `--quiet` on the pull suppresses git's "Updating / Fast-forward" file lists. Exactly one line per repo, followed by one summary line.
- **Status glyphs (verbatim):** `✓` updated, `=` up to date, `⊘` skipped, `✗` pull failed. Two spaces separate the name from the status text.
- **Summary line (verbatim format):** `— $updated updated, $uptodate up-to-date, $skipped skipped, $failed failed` (leading em-dash `—`).
- **Offline-first default-branch detection.** Primary: `git symbolic-ref --short refs/remotes/origin/HEAD`, strip `origin/`. Fallback only if unset: `git remote show origin | awk '/HEAD branch/{print $NF}'`.
- **Immediate children only, sequential, no parallelism.** Use the zsh `(N)` glob qualifier so an empty directory is a no-op, not a glob error.
- **No `git checkout` and no unconditional `git remote show origin`** — step 2 already confirms the repo is on its default branch, so the network call is avoided unless detection falls back.
- **Optional root argument:** `gpa` (current dir, `${1:-.}`) or `gpa ~/Work`.
- **No `setup.sh` change.** `shell/functions/` is already symlinked to `~/.zsh-functions`, which is on `fpath`.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `shell/functions/gpa` (new) | The autoloaded `gpa` function — the entire feature. |
| `tests/gpa.test.zsh` (new) | Pure-zsh functional test harness: builds local fixture repos in a `mktemp` dir, runs `gpa`, asserts on output. Run manually with `zsh tests/gpa.test.zsh`. |
| `shell/zshrc` (modify, line 3) | Add `gpa` to the `autoload -Uz …` list. |
| `shell/zshrc.d/aliases.zsh` (modify, lines 34–41) | Remove the existing inline `gpa()` definition. |

The `tests/` directory is new — this repo has no prior test framework, so the harness is a single standalone, dependency-free zsh script (zsh and git are already hard requirements). It is not wired into `pre-commit`/CI; it is run by hand during development.

---

## Task 1: Functional test harness (failing)

Write the complete test harness first. With no `shell/functions/gpa` yet, autoloading and calling `gpa` fails, so every assertion fails — this is the red state.

**Files:**

- Create: `tests/gpa.test.zsh`

**Interfaces:**

- Consumes: nothing (the function under test does not exist yet).
- Produces: the contract the function must satisfy — `gpa [root]` prints, for each immediate git subdirectory of `root` (default `.`), exactly one line:
  - `✓ <name>  <n> new commit(s)` when the rebase-pull advanced HEAD,
  - `= <name>  up to date` when HEAD was unchanged,
  - `⊘ <name>  skipped (uncommitted changes)` when the working tree is dirty,
  - `⊘ <name>  skipped (on <cur>, not <def>)` when not on the default branch,
  - `✗ <name>  pull failed` when the pull command exits non-zero,
  - and nothing for non-git subdirectories — followed by a final
    `— <u> updated, <t> up-to-date, <s> skipped, <f> failed` summary line.

- [ ] **Step 1: Write the failing test harness**

Create `tests/gpa.test.zsh` with this exact content:

```zsh
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh tests/gpa.test.zsh; echo "exit=$?"`

Expected: zsh reports it cannot find the function definition file for `gpa` (e.g. `gpa: function definition file not found`), every `check` prints `FAIL - …`, and the script exits non-zero — `exit=1`.

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/gpa.test.zsh
git commit -m "test(gpa): add functional harness for pull-all skip-and-report"
```

---

## Task 2: Implement the `gpa` autoloaded function

Write the function so the Task 1 harness passes.

**Files:**

- Create: `shell/functions/gpa`
- Test: `tests/gpa.test.zsh` (from Task 1)

**Interfaces:**

- Consumes: the output contract defined by `tests/gpa.test.zsh` (Task 1 → Produces).
- Produces: an autoloadable function `gpa [root]` for `shell/zshrc` to register (Task 3 consumes the bare name `gpa`).

- [ ] **Step 1: Write the function**

Create `shell/functions/gpa` with this exact content:

```zsh
gpa() {
  local root="${1:-.}"
  local updated=0 uptodate=0 skipped=0 failed=0

  for dir in "$root"/*/(N); do
    git -C "$dir" rev-parse --git-dir &>/dev/null || continue
    local name=${${dir%/}:t}

    # 1. Skip dirty working trees
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      print -r -- "⊘ $name  skipped (uncommitted changes)"
      ((skipped++)); continue
    fi

    # 2. Determine current and default branch (offline-first)
    local cur def
    cur=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
    def=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    def=${def#origin/}
    if [[ -z "$def" ]]; then
      def=$(git -C "$dir" remote show origin 2>/dev/null | awk '/HEAD branch/{print $NF}')
    fi

    # Skip repos not on their default branch
    if [[ -n "$def" && "$cur" != "$def" ]]; then
      print -r -- "⊘ $name  skipped (on $cur, not $def)"
      ((skipped++)); continue
    fi

    # 3. Clean and on default -> rebase-pull quietly
    local before after
    before=$(git -C "$dir" rev-parse HEAD)
    if git -C "$dir" pull --rebase --quiet 2>/dev/null; then
      after=$(git -C "$dir" rev-parse HEAD)
      if [[ "$before" == "$after" ]]; then
        print -r -- "= $name  up to date"
        ((uptodate++))
      else
        local n=$(git -C "$dir" rev-list --count "$before..$after")
        print -r -- "✓ $name  $n new commit(s)"
        ((updated++))
      fi
    else
      print -r -- "✗ $name  pull failed"
      ((failed++))
    fi
  done

  print -r -- "— $updated updated, $uptodate up-to-date, $skipped skipped, $failed failed"
}

gpa "$@"
```

- [ ] **Step 2: Syntax-check the function**

Run: `zsh -n shell/functions/gpa && echo "syntax OK"`

Expected: `syntax OK` (this is the same check the repo's `zsh -n` pre-commit hook runs on `shell/functions/`).

- [ ] **Step 3: Run the test to verify it passes**

Run: `zsh tests/gpa.test.zsh; echo "exit=$?"`

Expected: every `check` prints `ok   - …`, including the four scenario tests, the no-line check for `plain`, the fallback/empty/default-root cases, and finally:

```text
All assertions passed.
exit=0
```

- [ ] **Step 4: Commit**

```bash
git add shell/functions/gpa
git commit -m "feat(gpa): autoloaded pull-all with skip-and-report"
```

---

## Task 3: Wire up autoload and remove the inline alias

Register the new function and delete the old definition so the autoloaded version is the one in effect.

**Files:**

- Modify: `shell/zshrc:3`
- Modify: `shell/zshrc.d/aliases.zsh:34-41`

**Interfaces:**

- Consumes: the `gpa` function file from Task 2.
- Produces: nothing downstream (final integration task).

- [ ] **Step 1: Add `gpa` to the autoload list**

In `shell/zshrc`, line 3 currently reads:

```zsh
autoload -Uz grb _git_branch_worktree gfeature gfix gchore gwt _gwt md2pdf _dotnet_zsh_complete
```

Change it to append `gpa`:

```zsh
autoload -Uz grb _git_branch_worktree gfeature gfix gchore gwt _gwt md2pdf _dotnet_zsh_complete gpa
```

- [ ] **Step 2: Remove the inline `gpa()` alias**

In `shell/zshrc.d/aliases.zsh`, delete the entire inline definition (lines 34–41) **and the trailing blank line that followed it**, so the `reload` alias is followed directly by a single blank line and then `priv()`. Remove this block:

```zsh
gpa() {
  for dir in */; do
    if git -C "$dir" rev-parse --git-dir &>/dev/null; then
      echo "→ ${dir%/}"
      git -C "$dir" pull
    fi
  done
}

```

After the edit, the region around the old definition reads:

```zsh
# Convenience
alias reload='source ~/.zshrc'

priv() {
```

- [ ] **Step 3: Verify the old definition is gone**

Run: `rg -n 'gpa' shell/zshrc.d/aliases.zsh; echo "exit=$?"`

Expected: no matching lines and `exit=1` (ripgrep exits 1 when there are no matches).

- [ ] **Step 4: Verify autoload registration resolves in a clean shell**

Run: `zsh -df -c 'fpath=(shell/functions $fpath); autoload -Uz gpa; whence -v gpa'`

Expected: output identifying `gpa` as an autoload/function, e.g. `gpa is an autoload shell function` (zsh prints it is a shell function once resolved). It must not print `gpa not found`.

- [ ] **Step 5: Re-run the functional test as a regression check**

Run: `zsh tests/gpa.test.zsh; echo "exit=$?"`

Expected: `All assertions passed.` and `exit=0` — the integration edits did not change behavior.

- [ ] **Step 6: Run pre-commit on all touched files**

Run: `pre-commit run --files shell/functions/gpa shell/zshrc shell/zshrc.d/aliases.zsh tests/gpa.test.zsh`

Expected: all hooks pass (`Passed` / `Skipped`). The `zsh -n syntax check` hook covers `shell/functions/gpa`, `shell/zshrc`, and `shell/zshrc.d/aliases.zsh`; `markdownlint-cli2` and the generic whitespace/EOF hooks must report no failures.

- [ ] **Step 7: Commit**

```bash
git add shell/zshrc shell/zshrc.d/aliases.zsh
git commit -m "refactor(gpa): autoload the function and drop the inline alias"
```

---

## Self-Review

**Spec coverage:**

- Rebase-pull each immediate git subfolder → Task 2 function, `git pull --rebase --quiet`; Test A `api`/`web`.
- Skip dirty trees with `skipped (uncommitted changes)` → Task 2 step 1; Test A `billing`.
- Skip off-default-branch with `skipped (on <cur>, not <def>)` → Task 2 step 2; Test A `infra`, Test B `fallback`.
- No `git checkout`, no unconditional `git remote show origin` → Task 2 omits both; the `remote show` call is reached only in the `[[ -z "$def" ]]` fallback (Test B).
- Offline-first default-branch detection (symbolic-ref primary, `remote show origin` fallback) → Task 2 step 2; Test A exercises the primary path, Test B the fallback.
- Updated-vs-up-to-date via before/after `rev-parse` + `rev-list --count` → Task 2 step 3; Test A `api` (count) and `web` (unchanged).
- Glyphs `✓ = ⊘ ✗` and summary line → Global Constraints + Task 2; asserted verbatim in Test A.
- Pull failure → `✗ … pull failed` → Task 2 else branch; Test A `legacy`.
- Immediate children only, sequential, optional root arg, `(N)` empty-dir no-op → Task 2 loop + `${1:-.}`; Tests C (empty) and D (default cwd).
- Non-git subdirs ignored → Task 2 `rev-parse --git-dir || continue`; Test A `plain` no-line check.
- Promote to `shell/functions/gpa` autoload, add to zshrc list, remove inline alias, no `setup.sh` change → Tasks 2 and 3.

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to" placeholders; every code and command step contains complete content.

**Type/name consistency:** The output strings asserted in Task 1 (`✓ api`, `= web  up to date`, `⊘ … skipped (…)`, `✗ … pull failed`, summary `— … updated, … up-to-date, … skipped, … failed`) match the `print -r --` lines emitted by the Task 2 function exactly, including the two-space separator and the `(s)` in `new commit(s)`. The bare name `gpa` registered in Task 3's autoload list matches the function file name `shell/functions/gpa` from Task 2.
