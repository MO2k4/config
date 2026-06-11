# Gitleaks Secret Scanning via pre-commit

## Summary

Block commits to this repo that introduce secrets, using the [pre-commit](https://pre-commit.com/)
framework with the upstream [gitleaks](https://github.com/gitleaks/gitleaks) hook. The existing DCO
`Signed-off-by` behavior is preserved, and the global `~/.githooks` setup used by other repos is left
untouched.

## Context & constraint

This machine sets `core.hooksPath = ~/.githooks` **globally** (in `git/gitconfig`), with a
`prepare-commit-msg` hook there that appends a `Signed-off-by` trailer. That global setting creates two
problems for a per-repo pre-commit hook:

1. **Git ignores `.git/hooks`.** Any hook pre-commit installs into `.git/hooks` never fires, because git
   uses the global `~/.githooks` instead.
2. **`pre-commit install` refuses.** Verified in pre-commit source (`install_uninstall.py`): `install()`
   aborts with *"Cowardly refusing to install hooks with `core.hooksPath` set"* whenever
   `has_core_hookpaths_set()` is true — i.e. for **any** non-empty value — *unless* an explicit `git_dir`
   is passed, which skips the guard.

Resolution: make this repo **self-contained for hooks**. Override `core.hooksPath` locally to the repo's
own `.git/hooks`, install pre-commit's dispatchers with an explicit `--git-dir` to bypass the refusal,
and re-add the sign-off as a pre-commit hook (since the local override shadows the global one for this
repo only).

Baseline check: `gitleaks git` over full history and `gitleaks dir` over the working tree both report
**zero leaks**, so the default ruleset is clean — no allowlist is needed at the outset.

## Changes

### 1. `.pre-commit-config.yaml` (new, tracked)

```yaml
default_install_hook_types: [pre-commit, prepare-commit-msg]

repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks

  - repo: local
    hooks:
      - id: signoff
        name: Append Signed-off-by (DCO)
        entry: git/hooks/prepare-commit-msg
        language: script
        stages: [prepare-commit-msg]
        always_run: true
        pass_filenames: false
```

- The gitleaks hook is compiled from source at the pinned `rev` via Go (satisfied by mise `go 1.26`).
  Pin matches the currently installed gitleaks (`8.30.1`); bump with `pre-commit autoupdate`.
- The `local` signoff hook runs at the `prepare-commit-msg` stage. pre-commit passes the commit-message
  file path as the hook argument, matching what the sign-off script expects as `$1`.

### 2. `git/hooks/prepare-commit-msg` (new, tracked)

A copy of the current `~/.githooks/prepare-commit-msg` sign-off logic, version-controlled in this repo so
it is reproducible after a fresh clone. The global `~/.githooks/prepare-commit-msg` is left unchanged.

```sh
#!/bin/sh
# Auto-append Signed-off-by trailer for DCO compliance.
# Skips merges, squashes, and messages that already contain a sign-off.

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

case "$COMMIT_SOURCE" in
    merge|squash) exit 0 ;;
esac

if grep -qE "^Signed-off-by: " "$COMMIT_MSG_FILE"; then
    exit 0
fi

NAME=$(git config user.name)
EMAIL=$(git config user.email)

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
    exit 0
fi

printf '\nSigned-off-by: %s <%s>\n' "$NAME" "$EMAIL" >> "$COMMIT_MSG_FILE"
```

### 3. `setup-hooks.sh` (new, tracked)

Idempotent bootstrap, in the style of `update-iterm2.sh` / `update-brewfile.sh`. Repo-local git config
lives in the untracked `.git/config`, so this must run once per clone to enable the hooks.

Responsibilities:

1. Set the repo-local hooks dir, shadowing the global `core.hooksPath`:
   `git config --local core.hooksPath "$(git rev-parse --git-path hooks)"`
2. Install pre-commit dispatchers, bypassing the cowardly-refusal via explicit git-dir:
   `pre-commit install --git-dir "$(git rev-parse --git-dir)" -t pre-commit -t prepare-commit-msg`

The script verifies `pre-commit` is on `PATH` and prints a hint to `brew bundle` if not.

### 4. `Brewfile`

Add `brew "pre-commit"` (gitleaks is already listed) so the toolchain is reproducible via `./setup.sh --brew`.

### 5. `README.md`

Add a **Secret scanning** section: what the hook does, the one-time `./setup-hooks.sh` step after cloning,
and the escape hatch for intentional bypass (`git commit --no-verify` or `SKIP=gitleaks git commit`).

## Out of scope (YAGNI)

- **No `.gitleaks.toml` / allowlist** — the baseline scan is clean. If a false positive appears later, add a
  one-line `.gitleaksignore` entry then.
- **No CI / GitHub Action** — scoped to a local pre-commit hook; can be added later as a second layer.
- **No change to global `~/.githooks`** or to any other repo.

## Verification

Implementation is complete only after a real test commit demonstrates both, after which the test commit is
removed:

1. A planted fake secret (e.g. an `AKIA…`-style string) is **blocked** by the gitleaks hook.
2. A normal commit still receives the `Signed-off-by` trailer.

## Edge cases

- **pre-commit not installed**: `setup-hooks.sh` detects a missing `pre-commit` binary and points the user
  to `./setup.sh --brew`.
- **Fresh clone**: hooks are inert until `./setup-hooks.sh` runs, because the local `core.hooksPath`
  override is not tracked. Documented in the README.
- **Other repos**: unaffected — only this repo gets a local `core.hooksPath` override; the global
  `~/.githooks` continues to serve every other repo.
- **Intentional bypass**: `--no-verify` / `SKIP=gitleaks` documented for the rare legitimate case.
