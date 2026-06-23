# Design: `gpa` — Pull-All with Skip-and-Report

Date: 2026-06-23

## Overview

Replace the current inline `gpa()` function with an enhanced version that iterates over
immediate subfolders, and for each git repository brings it up to date using `get-latest`
semantics (rebase onto the latest default branch) — but only for repos that are safe to touch.
Repos with uncommitted changes, or repos checked out on a non-default branch, are skipped and
reported rather than modified. Output is quiet: one concise line per repo plus a summary, with
no per-file diff noise.

The function is promoted from `shell/zshrc.d/aliases.zsh` into `shell/functions/gpa` as an
autoloaded function, matching the existing `grb` / `gwt` helpers.

## Motivation

The current `gpa()` runs a plain `git pull` on whatever branch each repo happens to be on, with
full verbose git output:

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

Two problems:

1. **It is not aligned with the `get-latest` workflow.** The repos should land on their latest
   default branch (rebased), the same way `git get-latest` works for a single repo.
2. **Output is convoluted.** Every repo prints its full fast-forward file list, making it hard to
   see what actually changed across a batch.

## Behavior

For each immediate subdirectory of the target root that is a git repository:

1. **Dirty working tree?** If `git status --porcelain` is non-empty → **skip**, report
   `skipped (uncommitted changes)`. Never touches work in progress.
2. **Not on its default branch?** If the current branch differs from the repo's default branch →
   **skip**, report `skipped (on <current>, not <default>)`. Never switches the user off a
   feature branch.
3. **Clean and on default** → run `git pull --rebase --quiet`. Because step 2 already confirmed
   the repo is *on* its default branch, there is no `git checkout` (unlike `get-latest`), and the
   slow `git remote show origin` network call is avoided. This keeps the operation non-invasive.

### Default-branch detection (local-first)

Detection is offline by default:

- Primary: `git symbolic-ref --short refs/remotes/origin/HEAD` → e.g. `origin/main`; strip the
  `origin/` prefix.
- Fallback (only if the ref is not set locally): one `git remote show origin` call, parsing the
  `HEAD branch` line — the same source `get-latest` uses. This is the only path that hits the
  network for detection, and only when necessary.

### Updated-vs-up-to-date detection

Capture `git rev-parse HEAD` before and after the pull. If unchanged → up to date. If changed →
report the number of new commits via `git rev-list --count <before>..<after>`.

## Output Format

Quiet: `--quiet` on the pull suppresses git's "Updating / Fast-forward" file lists. One line per
repo, followed by a summary line. Status glyphs:

- `✓` updated (with new-commit count)
- `=` up to date
- `⊘` skipped (with reason)
- `✗` pull failed

Example:

```text
✓ api        3 new commits
= web        up to date
⊘ billing    skipped (uncommitted changes)
⊘ infra      skipped (on feat/vpc, not main)
✗ legacy     pull failed
— 1 updated, 1 up-to-date, 2 skipped, 1 failed
```

## Scope

- **Immediate children only** (no recursion), preserving current behavior.
- Accepts an optional root argument: `gpa` (current dir) or `gpa ~/Work`.
- **Sequential** execution — no parallelism. Keeps output legible and ordering deterministic.
- Uses a zsh `(N)` glob qualifier so an empty directory is a no-op rather than a glob error.

## Reference Implementation

`shell/functions/gpa` (autoload style: function definition followed by an invocation at the
bottom, matching `grb` / `gwt`):

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

    # 2. Determine current and default branch
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

    # 3. Clean and on default → rebase-pull quietly
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

## Files Changed

1. **`shell/functions/gpa`** (new) — the autoloaded function above.
2. **`shell/zshrc.d/aliases.zsh`** — remove the existing inline `gpa()` definition.
3. **`shell/zshrc`** — add `gpa` to the `autoload -Uz …` list.

No change to `setup.sh` is needed: `shell/functions` is already symlinked to `~/.zsh-functions`,
which is on `fpath`.

## Out of Scope (YAGNI)

- Recursive discovery of nested repos.
- Parallel execution.
- Auto-switching dirty/feature-branch repos onto default (explicitly rejected — skip-and-report
  is the chosen safety policy).
