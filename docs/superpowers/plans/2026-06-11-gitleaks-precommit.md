# Gitleaks Secret Scanning via pre-commit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Block commits that introduce secrets in this dotfiles repo using the pre-commit framework with the upstream gitleaks hook, while preserving the existing DCO `Signed-off-by` behavior and leaving the global `~/.githooks` setup untouched.

**Architecture:** This machine sets `core.hooksPath = ~/.githooks` globally, which makes git ignore `.git/hooks` and makes `pre-commit install` refuse. We make this repo self-contained for hooks: a repo-local `core.hooksPath` override points at the repo's own `.git/hooks` (shadowing the global one for this repo only), pre-commit's dispatchers are installed with an explicit `--git-dir` to bypass the refusal, and the DCO sign-off is re-added as a `local` pre-commit hook at the `prepare-commit-msg` stage (because the local override shadows the global hook for this repo).

**Tech Stack:** pre-commit (Python framework, installed via Homebrew), gitleaks v8.30.1 (Go binary, compiled from source by pre-commit at the pinned rev), POSIX `sh` for the sign-off hook, `bash` for the bootstrap script.

---

## Background facts (verified against the live repo on 2026-06-11)

- Currently installed gitleaks: **8.30.1** → pin the hook to `rev: v8.30.1`.
- `pre-commit` is **NOT** currently installed (`pre-commit --version` → not found). It must be installed via Homebrew before the wiring/verification tasks (Task 6+).
- Global hook source: `~/.githooks/prepare-commit-msg` (the sign-off script — copied verbatim into the repo in Task 1).
- `git/gitconfig:59` sets `hooksPath = /Users/martino/.githooks` (tracked, symlinked to `~/.gitconfig`). **This file is NOT modified by this plan.**
- **Spec correction (important):** the design spec computes the local hooks dir with `git rev-parse --git-path hooks`. Verified that this command **honors `core.hooksPath`** and therefore returns `/Users/martino/.githooks` (the global dir), NOT `.git/hooks`. Using it would re-point the local config at the global dir and defeat the shadowing. This plan uses **`$(git rev-parse --absolute-git-dir)/hooks`** instead, which returns the correct absolute path `/Users/martino/Work/config/.git/hooks`.

## File structure

| File | Status | Responsibility |
|---|---|---|
| `git/hooks/prepare-commit-msg` | Create | Version-controlled copy of the DCO sign-off `sh` script, runnable after a fresh clone. |
| `.pre-commit-config.yaml` | Create | Declares the gitleaks hook (pinned) + the `local` sign-off hook and the install hook types. |
| `setup-hooks.sh` | Create | Idempotent per-clone bootstrap: set local `core.hooksPath`, install pre-commit dispatchers via explicit git-dir. |
| `Brewfile` | Modify | Add `brew "pre-commit"` (gitleaks already present at line 49). |
| `README.md` | Modify | Add a "Secret scanning" section: what it does, the one-time `./setup-hooks.sh` step, the bypass escape hatch. |

These changes are independent of each other except for the wiring/verification at the end. Tasks 1–5 each produce a self-contained, committable artifact. Tasks 6–7 install the toolchain, wire it up, and prove it end-to-end.

---

### Task 1: Version-controlled DCO sign-off hook

**Files:**
- Create: `git/hooks/prepare-commit-msg`

- [ ] **Step 1: Confirm the script does not yet exist (the "failing test")**

Run: `ls git/hooks/prepare-commit-msg`
Expected: FAIL — `ls: git/hooks/prepare-commit-msg: No such file or directory`

- [ ] **Step 2: Create the sign-off script**

This is a verbatim copy of the current `~/.githooks/prepare-commit-msg`. Create `git/hooks/prepare-commit-msg`:

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

- [ ] **Step 3: Make it executable**

`language: script` hooks must be executable. Run:

```bash
chmod +x git/hooks/prepare-commit-msg
```

- [ ] **Step 4: Verify it appends a sign-off (the "passing test")**

Run:

```bash
printf 'test message\n' > /tmp/msg.txt
git/hooks/prepare-commit-msg /tmp/msg.txt
cat /tmp/msg.txt
```

Expected: output ends with a `Signed-off-by: <your name> <your email>` line, e.g.:

```
test message

Signed-off-by: Martin Oehlert <...>
```

- [ ] **Step 5: Verify it is idempotent (does not double-append)**

Run:

```bash
git/hooks/prepare-commit-msg /tmp/msg.txt
grep -c "^Signed-off-by: " /tmp/msg.txt
```

Expected: `1` (the existing sign-off short-circuits the second run).

- [ ] **Step 6: Verify the executable bit is tracked by git**

Run:

```bash
git add git/hooks/prepare-commit-msg
git ls-files -s git/hooks/prepare-commit-msg
```

Expected: mode begins with `100755` (executable), e.g. `100755 <hash> 0	git/hooks/prepare-commit-msg`.

- [ ] **Step 7: Commit**

```bash
git add git/hooks/prepare-commit-msg
git commit -m "feat(hooks): add version-controlled DCO sign-off hook"
```

---

### Task 2: pre-commit configuration

**Files:**
- Create: `.pre-commit-config.yaml`

- [ ] **Step 1: Confirm the config does not yet exist (the "failing test")**

Run: `ls .pre-commit-config.yaml`
Expected: FAIL — `ls: .pre-commit-config.yaml: No such file or directory`

- [ ] **Step 2: Create `.pre-commit-config.yaml`**

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

Notes for the implementer:
- `rev: v8.30.1` matches the installed gitleaks; bump later with `pre-commit autoupdate`.
- The gitleaks hook is compiled from Go source at that rev; this needs `go` on PATH (provided by mise `go 1.26`). The first run is slow (build); later runs are cached.
- The `signoff` hook runs at the `prepare-commit-msg` stage. pre-commit passes the commit-message file path as the first argument to the hook, which the script reads as `$1`. `pass_filenames: false` stops the staged-file list from being appended; `always_run: true` makes it run even with no staged files.

- [ ] **Step 3: Verify it is valid YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.pre-commit-config.yaml')); print('valid')"
```

Expected: `valid`

- [ ] **Step 4: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "feat: add pre-commit config with gitleaks and DCO sign-off"
```

---

### Task 3: Per-clone bootstrap script

**Files:**
- Create: `setup-hooks.sh`

- [ ] **Step 1: Confirm the script does not yet exist (the "failing test")**

Run: `ls setup-hooks.sh`
Expected: FAIL — `ls: setup-hooks.sh: No such file or directory`

- [ ] **Step 2: Create `setup-hooks.sh`**

Follows the style of `update-iterm2.sh` / `update-brewfile.sh` (`#!/bin/bash`, `set -euo pipefail`, `DOTFILES` resolved from `$0`). Uses `git rev-parse --absolute-git-dir` (NOT `--git-path hooks`, see Background facts) to get the real `.git/hooks` path.

```bash
#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES"

# pre-commit is required; it is installed via Homebrew (see Brewfile).
if ! command -v pre-commit &>/dev/null; then
    echo "Error: pre-commit not found on PATH." >&2
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
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x setup-hooks.sh
```

- [ ] **Step 4: Verify the missing-pre-commit guard fires (the "failing test" for the error path)**

`pre-commit` is not installed yet, so the guard should trigger. Run:

```bash
./setup-hooks.sh; echo "exit=$?"
```

Expected: prints the `Error: pre-commit not found on PATH.` hint and `exit=1`. (It must NOT have set a local `core.hooksPath` — verify with `git config --local --get core.hooksPath`, expected: empty/no output. `set -e` aborts before that line because the guard `exit 1` runs first.)

- [ ] **Step 5: Verify the executable bit is tracked**

```bash
git add setup-hooks.sh
git ls-files -s setup-hooks.sh
```

Expected: mode `100755`.

- [ ] **Step 6: Commit**

```bash
git add setup-hooks.sh
git commit -m "feat: add setup-hooks.sh to bootstrap pre-commit per clone"
```

---

### Task 4: Add pre-commit to the Brewfile

**Files:**
- Modify: `Brewfile` (gitleaks is already present at line 49)

- [ ] **Step 1: Confirm pre-commit is not yet in the Brewfile (the "failing test")**

Run: `grep -n 'pre-commit' Brewfile`
Expected: FAIL — no output (exit code 1).

- [ ] **Step 2: Add the brew entry next to the existing gitleaks line**

The repo's `Brewfile` is normally regenerated with `brew bundle dump`, but pre-commit is not installed yet, so add the line manually now. Find the line:

```ruby
brew "gitleaks"
```

and add directly below it:

```ruby
brew "pre-commit"
```

- [ ] **Step 3: Verify both entries are present**

Run: `grep -nE 'brew "(gitleaks|pre-commit)"' Brewfile`
Expected: two lines — `brew "gitleaks"` and `brew "pre-commit"`.

- [ ] **Step 4: Commit**

```bash
git add Brewfile
git commit -m "chore(brew): add pre-commit"
```

---

### Task 5: Document secret scanning in the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Confirm there is no secret-scanning section yet (the "failing test")**

Run: `grep -ni 'secret scanning' README.md`
Expected: FAIL — no output (exit code 1).

- [ ] **Step 2: Add the section**

Insert a new `## Secret scanning` section after the existing `## Files NOT tracked (secrets)` section and before `## Daily workflow`. Use this exact content:

```markdown
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
```

- [ ] **Step 3: Verify the section landed**

Run: `grep -n 'Secret scanning' README.md`
Expected: one match for the `## Secret scanning` heading.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document gitleaks secret scanning and setup-hooks"
```

---

### Task 6: Install the toolchain and wire up the hooks

This task installs `pre-commit` and runs the bootstrap for real. It changes machine/repo state but creates no new tracked files (the local `core.hooksPath` lives in the untracked `.git/config`).

**Files:** none (state changes only)

- [ ] **Step 1: Install pre-commit via Homebrew**

```bash
brew install pre-commit
```

Expected: pre-commit is installed. Verify:

```bash
pre-commit --version
```

Expected: prints a version string (e.g. `pre-commit 4.x.x`).

- [ ] **Step 2: Run the bootstrap**

```bash
./setup-hooks.sh
```

Expected output includes:
```
Set local core.hooksPath → /Users/martino/Work/config/.git/hooks
pre-commit installed at .git/hooks/pre-commit
pre-commit installed at .git/hooks/prepare-commit-msg
Done. Hooks installed for this repo.
```

- [ ] **Step 3: Verify the local hooksPath shadows the global one**

```bash
git config --local --get core.hooksPath
git config --get core.hooksPath
```

Expected: the **local** value is `/Users/martino/Work/config/.git/hooks` (this repo's own hooks); the effective/global value still resolves to `~/.githooks` for everything else. The local value must point at `.git/hooks`, NOT `~/.githooks`.

- [ ] **Step 4: Verify both dispatchers were installed and are pre-commit's**

```bash
head -n 5 .git/hooks/pre-commit .git/hooks/prepare-commit-msg
```

Expected: both files exist and contain the pre-commit generated header (a comment referencing `pre-commit`).

- [ ] **Step 5: Prime the gitleaks hook (compiles from Go source — slow first run)**

```bash
pre-commit run gitleaks --all-files
```

Expected: gitleaks builds (first time only), then runs and reports `Passed` (the baseline working tree is clean per the spec). If the build fails for lack of `go`, ensure mise's `go` is active (`go version` → 1.26) and retry.

---

### Task 7: End-to-end verification (planted secret blocked; sign-off preserved)

This is the spec's acceptance test. It uses a throwaway commit that is removed at the end, so the repo history stays clean.

**Files:** none committed permanently (a temporary file is created and deleted)

- [ ] **Step 1: Confirm a clean commit still gets the sign-off (positive path)**

Make a trivial, secret-free change and commit it through the hooks:

```bash
echo "" >> README.md
git add README.md
git commit -m "test: verify sign-off trailer"
```

Expected: the commit **succeeds**, gitleaks reports `Passed`. Verify the trailer:

```bash
git log -1 --format=%B
```

Expected: the message ends with a `Signed-off-by: <name> <email>` line.

- [ ] **Step 2: Undo that test commit (keep history clean)**

```bash
git reset --hard HEAD~1
```

Expected: `README.md` is back to its committed state; `git status` is clean.

- [ ] **Step 3: Plant a fake secret and attempt to commit (negative path)**

> **Correction (verified 2026-06-11):** do NOT use `AKIAIOSFODNN7EXAMPLE`. That is the canonical
> AWS *documentation* example key, which gitleaks **allowlists by design** (the "EXAMPLE" stopword),
> so it is NOT detected and the commit would wrongly succeed. Use a high-entropy fake secret that
> gitleaks flags as `generic-api-key`, as below.

Use a flagging fake secret in a throwaway file:

```bash
printf 'aws_secret_access_key = "wJalrXUtnFEMIK7MDENGbPxRfiCYwQ8H4kGhT9zZ"\n' > /tmp/leak-test.txt
cp /tmp/leak-test.txt ./leak-test.txt
git add leak-test.txt
git commit -m "test: this should be blocked"; echo "exit=$?"
```

Expected: the commit is **blocked** — gitleaks reports `Failed` / detects a secret, and `exit=1` (non-zero). The commit must NOT be created.

- [ ] **Step 4: Confirm no commit was created and clean up the planted file**

```bash
git log -1 --format=%s
git reset leak-test.txt
rm -f leak-test.txt
git status
```

Expected: `git log -1` still shows the pre-test HEAD subject (the blocked commit never landed); after cleanup `git status` is clean with no `leak-test.txt`.

- [ ] **Step 5: Verify the bypass escape hatch works (optional sanity check)**

```bash
cp /tmp/leak-test.txt ./leak-test.txt
git add leak-test.txt
SKIP=gitleaks git commit -m "test: bypass" --dry-run 2>/dev/null || true
git reset leak-test.txt
rm -f leak-test.txt
```

Expected: with `SKIP=gitleaks`, gitleaks is skipped (no leak failure from it). Clean up the planted file afterward so the tree is clean.

- [ ] **Step 6: Final state check**

```bash
git status
git log --oneline -6
```

Expected: working tree clean; the last commits are the Task 1–5 feature commits with no leftover test commits or `leak-test.txt`.

---

## Self-review (completed during planning)

- **Spec coverage:** Change 1 (`.pre-commit-config.yaml`) → Task 2. Change 2 (`git/hooks/prepare-commit-msg`) → Task 1. Change 3 (`setup-hooks.sh`) → Task 3. Change 4 (Brewfile `pre-commit`) → Task 4. Change 5 (README) → Task 5. Verification section (planted secret blocked + sign-off preserved + test commit removed) → Task 7. Edge cases (pre-commit missing → Task 3 Step 4 + Task 6 Step 1; fresh clone inert → README Task 5; other repos unaffected → Task 6 Step 3; intentional bypass → README Task 5 + Task 7 Step 5). All covered.
- **Spec deviation (justified):** `setup-hooks.sh` uses `git rev-parse --absolute-git-dir`/hooks instead of the spec's `git rev-parse --git-path hooks`, because the latter was verified to return the global `~/.githooks` and would not shadow it. See Background facts.
- **Type/name consistency:** hook id `signoff`, file `git/hooks/prepare-commit-msg`, rev `v8.30.1`, script `setup-hooks.sh`, and the `core.hooksPath` target `.git/hooks` are used consistently across all tasks.
- **Placeholder scan:** none — every code/config step contains full content and every verification step has an exact command + expected output.
