# Expanded pre-commit checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing `.pre-commit-config.yaml` (gitleaks + DCO sign-off) into a full hygiene, linting, and formatting safety net for this dotfiles repo, including autofix hooks that rewrite files on commit.

**Architecture:** Add four hook groups on top of the current config — (1) generic hygiene + structured-data validation from `pre-commit/pre-commit-hooks`, (2) bash formatting/linting (`shfmt` + `shellcheck`) scoped to the 5 bash files, (3) a `local` `zsh -n` parse check, (4) `markdownlint-cli2 --fix`. Each group is added, its `rev` refreshed with `pre-commit autoupdate`, run against the whole tree to absorb one-time reformatting and surface findings, then committed on its own. The existing gitleaks and `signoff` hooks are preserved exactly.

**Tech Stack:** pre-commit 4.6.0 (already installed), the upstream hooks above (each runs in a pre-commit-managed environment — no Homebrew installs needed beyond what exists), zsh 5.9 (system), go 1.26 (for the gitleaks build, already primed).

---

## Background facts (verified against the live repo on 2026-06-11)

These were checked read-only during planning so the verification steps below are concrete:

- **pre-commit** is installed (`4.6.0`) and the dispatchers are already wired (`./setup-hooks.sh` was run in the prior gitleaks plan). Editing `.pre-commit-config.yaml` needs **no reinstall** — only `pre-commit`-stage and `local` hooks are added; the installed hook types (`pre-commit`, `prepare-commit-msg`) are unchanged.
- **gitleaks** is already built/cached from the prior plan, so its hook runs fast.
- **The 5 bash files** are `setup.sh`, `setup-hooks.sh`, `update-brewfile.sh`, `update-iterm2.sh` (all `#!/bin/bash`) and `git/hooks/prepare-commit-msg` (`#!/bin/sh`).
- **shellcheck** (v0.10) over those 5 files reports **zero findings** (exit 0). Task 2 should pass clean.
- **zsh -n** over all 19 target zsh files (`shell/zshrc`, `shell/zshenv`, `shell/zprofile`, `shell/functions/*`, `shell/zshrc.d/*.zsh`) reports **zero failures**. Task 3 should pass clean.
- **Shebang/executable consistency:** every file with a shebang is mode `100755`; no `shell/functions/*` file has a shebang or the executable bit. The two shebang-consistency hooks pass.
- **markdownlint** over the 7 **tracked** `.md` files, with `MD013`/`MD033`/`MD024` disabled, still reports `MD060` (table pipe spacing). **`MD060` is NOT auto-fixable** — `--fix` leaves it, so the hook would fail and block every commit. The repo uses compact (`|---|---|`) tables by design, so **`MD060` is also disabled** in `.markdownlint-cli2.yaml` (a deliberate refinement of the spec, which predates that rule).
- With `MD013`/`MD033`/`MD024`/`MD060` disabled, `--fix` auto-resolves all `MD031`/`MD032` findings. **Exactly two findings remain and need a manual one-word fix** (add a fence language): `CLAUDE.md:17` and `docs/superpowers/specs/2026-04-21-aictx-prompt-segment-design.md:46` (both `MD040`).
- pre-commit only runs against **tracked/staged** files. The untracked plan files under `docs/plans/` and `docs/superpowers/plans/` are ignored unless staged, so their many markdown violations are out of scope here.

## File structure

| File | Status | Responsibility |
|---|---|---|
| `.pre-commit-config.yaml` | Modify | Add the four new hook groups; keep gitleaks + `signoff` intact. |
| `.markdownlint-cli2.yaml` | Create | Disable `MD013`/`MD033`/`MD024`/`MD060`; all other rules on. |
| `CLAUDE.md` | Modify | One `MD040` fix (line 17 fence) + whatever autofix hooks normalize. |
| `docs/superpowers/specs/2026-04-21-aictx-prompt-segment-design.md` | Modify | One `MD040` fix (line 46 fence). |
| Various tracked files | Modify | One-time normalization by autofix hooks (whitespace, EOF, shfmt, markdown). |
| `README.md` | Modify | Document the expanded checks. |

The current config (do not regress it) is:

```yaml
default_install_hook_types: [pre-commit, prepare-commit-msg]

repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
        stages: [pre-commit]

  - repo: local
    hooks:
      - id: signoff
        name: Append Signed-off-by (DCO)
        entry: git/hooks/prepare-commit-msg
        language: script
        stages: [prepare-commit-msg]
        always_run: true
        # pre-commit passes the commit-message file as the single "filename"
        # for prepare-commit-msg hooks, so pass_filenames MUST be true for the
        # script to receive it as $1 (false suppresses it).
        pass_filenames: true
```

The target end state (final hook order) is: `gitleaks` → `pre-commit-hooks` → `shfmt` → `shellcheck` → `markdownlint-cli2` → `local{zsh-syntax-check, signoff}`.

---

### Task 1: Generic hygiene & structured-data validation hooks

**Files:**

- Modify: `.pre-commit-config.yaml`

- [ ] **Step 1: Add the `pre-commit-hooks` block before the `local` repo**

Use Edit on `.pre-commit-config.yaml`. Find:

```yaml
      - id: gitleaks
        stages: [pre-commit]

  - repo: local
```

Replace with:

```yaml
      - id: gitleaks
        stages: [pre-commit]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
        exclude: ^iterm2/
      - id: end-of-file-fixer
        exclude: ^iterm2/
      - id: mixed-line-ending
        args: [--fix=lf]
        exclude: ^iterm2/
      - id: check-merge-conflict
      - id: check-case-conflict
      - id: check-executable-has-shebangs
      - id: check-shebang-scripts-are-executable
      - id: check-yaml
      - id: check-json
      - id: check-toml

  - repo: local
```

The `^iterm2/` excludes keep the machine-managed plist untouched (it is rewritten by `update-iterm2.sh`).

- [ ] **Step 2: Refresh this repo's rev to the latest tag**

Run:

```bash
pre-commit autoupdate --repo https://github.com/pre-commit/pre-commit-hooks
```

Expected: prints `updating ... -> ...` (or `already up to date`). It may bump `rev: v5.0.0` to a newer tag in the file — that is intended.

- [ ] **Step 3: Run the hooks against the whole tree (first pass — autofix expected)**

Only gitleaks + these hygiene hooks are configured so far, so this run is naturally scoped to them. Run:

```bash
pre-commit run --all-files
```

Expected: gitleaks → `Passed`. The check-* hooks (`check-yaml`/`check-json`/`check-toml`/`check-merge-conflict`/`check-case-conflict`/the two shebang hooks) → `Passed`. The autofix hooks (`trailing-whitespace`, `end-of-file-fixer`, `mixed-line-ending`) print `Passed` if the tree is already clean, or **`Failed`** and **modify files** if not. A `Failed`-with-modifications result here is normal, not an error.

- [ ] **Step 4: Inspect and absorb any autofixes, then re-run until clean**

If Step 3 modified files, review and re-run:

```bash
git diff --stat
git add -A
pre-commit run --all-files
```

Expected after re-adding: a second `pre-commit run --all-files` reports **all hooks `Passed`** (autofix hooks have nothing left to change). Repeat the add + run loop if needed (normally one pass suffices).

If a `check-yaml`/`check-json`/`check-toml` hook reports `Failed`, the corresponding data file is genuinely malformed — open it, fix the syntax, `git add`, and re-run. (Per Background facts the tracked data files are valid, so this is not expected.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(pre-commit): add hygiene and structured-data checks"
```

---

### Task 2: Bash linting & formatting (shfmt + shellcheck)

**Files:**

- Modify: `.pre-commit-config.yaml`

- [ ] **Step 1: Add the `shfmt` and `shellcheck` blocks before the `local` repo**

Use Edit on `.pre-commit-config.yaml`. Find:

```yaml
      - id: check-toml

  - repo: local
```

Replace with:

```yaml
      - id: check-toml

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.10.0-2
    hooks:
      - id: shfmt
        args: [-w, -i, '4', -ci]
        files: (\.sh$|^git/hooks/prepare-commit-msg$)

  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        files: (\.sh$|^git/hooks/prepare-commit-msg$)

  - repo: local
```

`-i 4` matches the existing 4-space indentation; `-ci` indents switch-case bodies. The `files:` regex scopes both hooks to the 5 bash files only (avoids false positives on zsh and `shell/bashrc`).

- [ ] **Step 2: Refresh both revs to their latest tags**

Run:

```bash
pre-commit autoupdate --repo https://github.com/scop/pre-commit-shfmt
pre-commit autoupdate --repo https://github.com/shellcheck-py/shellcheck-py
```

Expected: each prints `updating`/`already up to date`. The first run also builds the hook environments (slower); later runs are cached.

- [ ] **Step 3: Run shfmt (first pass — may reformat the bash files)**

```bash
pre-commit run shfmt --all-files
```

Expected: `Passed` if the bash files already match the style, or **`Failed`** with files rewritten (4-space, indented cases). A rewrite here is normal.

- [ ] **Step 4: Absorb shfmt changes and confirm it re-passes**

```bash
git diff --stat
git add -A
pre-commit run shfmt --all-files
```

Expected: now `Passed` (nothing left to reformat).

- [ ] **Step 5: Run shellcheck (report-only)**

```bash
pre-commit run shellcheck --all-files
```

Expected: **`Passed`** — per Background facts the 5 bash files have zero shellcheck findings.

If shellcheck unexpectedly reports a finding (e.g. after an autoupdate to a newer version), fix the real issue in the script, or — only when the warning is intentional — add a scoped pragma on the line above it, for example:

```bash
# shellcheck disable=SC2155  # intentional: combined declare+assign is fine here
```

Then `git add` and re-run until `Passed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(pre-commit): add shfmt formatting and shellcheck linting for bash"
```

---

### Task 3: zsh syntax check

**Files:**

- Modify: `.pre-commit-config.yaml`

- [ ] **Step 1: Add the `zsh-syntax-check` hook inside the existing `local` repo**

Use Edit on `.pre-commit-config.yaml`. Find:

```yaml
  - repo: local
    hooks:
      - id: signoff
```

Replace with:

```yaml
  - repo: local
    hooks:
      - id: zsh-syntax-check
        name: zsh -n syntax check
        entry: zsh -n
        language: system
        files: ^shell/(zshrc|zshenv|zprofile|functions/|zshrc\.d/.*\.zsh)
        pass_filenames: true

      - id: signoff
```

`language: system` runs the host `zsh` (5.9, on PATH). The `files:` regex excludes `shell/bashrc` (bash) and the vendored `prompt/` completions. `zsh -n` is parse-only — it never executes the configs.

- [ ] **Step 2: Run the hook**

```bash
pre-commit run zsh-syntax-check --all-files
```

Expected: **`Passed`** — per Background facts all 19 target zsh files parse cleanly.

If a file fails, `zsh -n` prints the parse error with a line number; fix the syntax in that file, `git add`, and re-run until `Passed`.

- [ ] **Step 3: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "feat(pre-commit): add zsh -n syntax check"
```

---

### Task 4: Markdown linting

**Files:**

- Create: `.markdownlint-cli2.yaml`
- Modify: `.pre-commit-config.yaml`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-21-aictx-prompt-segment-design.md`

- [ ] **Step 1: Create `.markdownlint-cli2.yaml`**

Create the file with exactly this content:

```yaml
# markdownlint-cli2 configuration for this dotfiles repo.
# All rules stay on except these, disabled for machine-generated docs:
config:
  MD013: false  # line length — generated prose has long lines
  MD033: false  # inline HTML — specs use <details>, <br>, etc.
  MD024: false  # duplicate headings — plans repeat headings across tasks
  MD060: false  # table pipe spacing — repo uses compact |---| tables by design
```

`MD060` is disabled because it is not auto-fixable and the repo's compact tables would otherwise block every commit (see Background facts).

- [ ] **Step 2: Add the `markdownlint-cli2` block before the `local` repo**

Use Edit on `.pre-commit-config.yaml`. Find:

```yaml
      - id: shellcheck
        files: (\.sh$|^git/hooks/prepare-commit-msg$)

  - repo: local
```

Replace with:

```yaml
      - id: shellcheck
        files: (\.sh$|^git/hooks/prepare-commit-msg$)

  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.18.1
    hooks:
      - id: markdownlint-cli2
        args: [--fix]

  - repo: local
```

- [ ] **Step 3: Refresh the rev to the latest tag**

```bash
pre-commit autoupdate --repo https://github.com/DavidAnson/markdownlint-cli2
```

Expected: prints `updating`/`already up to date`.

- [ ] **Step 4: Run markdownlint (first pass — autofix + surfaces the 2 manual cases)**

```bash
pre-commit run markdownlint-cli2 --all-files
```

Expected: **`Failed`** — `--fix` auto-resolves the `MD031`/`MD032` findings (rewriting `CLAUDE.md`, `docs/superpowers/plans/2026-03-12-privileges-and-update-aliases.md`, and `docs/superpowers/specs/2026-03-12-privileges-and-update-aliases-design.md`) but two `MD040` errors remain and are reported:

```text
CLAUDE.md:17 MD040/fenced-code-language ...
docs/superpowers/specs/2026-04-21-aictx-prompt-segment-design.md:46 MD040/fenced-code-language ...
```

- [ ] **Step 5: Manually fix `CLAUDE.md:17` (add a fence language)**

`CLAUDE.md` line 17 opens the architecture diagram fence. Use Edit on `CLAUDE.md`. Find this exact opening fence (the one immediately above the `setup.sh ...` diagram):

```text
## Architecture

```
setup.sh          → Idempotent symlink installer (bash, ln -sf)
```

Change just that opening fence line from ` ``` ` to ` ```text ` so the block reads:

```text
## Architecture

```text
setup.sh          → Idempotent symlink installer (bash, ln -sf)
```

(Do not alter the closing ` ``` `.)

- [ ] **Step 6: Manually fix the aictx spec fence (add a fence language)**

Use Edit on `docs/superpowers/specs/2026-04-21-aictx-prompt-segment-design.md`. Find the segment-order fence:

```text
## Segment order after change

```
[󰙅 ifm] [path] [git] [claude model] [claude usage]
```

Change its opening fence from ` ``` ` to ` ```text `:

```text
## Segment order after change

```text
[󰙅 ifm] [path] [git] [claude model] [claude usage]
```

- [ ] **Step 7: Re-run until clean**

```bash
git add -A
pre-commit run markdownlint-cli2 --all-files
```

Expected: **`Passed`** — the two `MD040` cases are now resolved and `--fix` has nothing left to change.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(pre-commit): add markdownlint-cli2 and normalize markdown"
```

---

### Task 5: Lock revisions and prove a clean full run

**Files:**

- Modify: `.pre-commit-config.yaml` (only if a rev bumps)

- [ ] **Step 1: Refresh all remaining revs (catches gitleaks too)**

```bash
pre-commit autoupdate
```

Expected: prints one line per repo (`updating`/`already up to date`). This also re-checks `gitleaks`. Any `rev:` it bumps is a config change to be committed in this task.

- [ ] **Step 2: Run the entire suite against the whole tree**

```bash
pre-commit run --all-files
```

Expected: **every hook `Passed`** with no file modifications. (The `signoff` hook is a `prepare-commit-msg`-stage hook and does not run during `pre-commit run` — that is correct; it is exercised in Task 7.)

If an autoupdate bump introduced new autofixes or findings, absorb them the same way as earlier tasks (`git add -A`, fix any non-autofixable finding, re-run) until the full run is clean.

- [ ] **Step 3: Confirm the final hook order matches the target**

```bash
grep -nE '^\s+- repo:|^\s+- id:' .pre-commit-config.yaml
```

Expected order: `gitleaks`, then `pre-commit-hooks` (its 10 ids), `pre-commit-shfmt` (`shfmt`), `shellcheck-py` (`shellcheck`), `markdownlint-cli2`, then the `local` repo with `zsh-syntax-check` and `signoff`.

- [ ] **Step 4: Commit any rev bumps (skip if the working tree is clean)**

```bash
git status --short
git add .pre-commit-config.yaml
git commit -m "chore(pre-commit): pin hook revisions via autoupdate"
```

If `git status --short` shows no changes, there is nothing to commit — move on.

---

### Task 6: Document the expanded checks in the README

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Confirm there is no "what the checks cover" list yet (the "failing test")**

Run: `grep -ni 'whitespace, end-of-file' README.md`
Expected: FAIL — no output (exit code 1).

- [ ] **Step 2: Rename the existing section and add the checks list**

The README already has a `## Secret scanning` section describing the gitleaks/`setup-hooks.sh` flow. Broaden it. Use Edit on `README.md`. Find:

```markdown
## Secret scanning

Commits to this repo are scanned for secrets by [gitleaks](https://github.com/gitleaks/gitleaks),
wired in through the [pre-commit](https://pre-commit.com/) framework. A commit that introduces a
secret (API key, token, private key, …) is blocked before it lands.
```

Replace with:

```markdown
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
```

- [ ] **Step 3: Update the bootstrap comment to reflect the broader tooling**

The setup block below it still reads as gitleaks-only. Use Edit on `README.md`. Find:

```markdown
Because this machine sets `core.hooksPath` globally (for the DCO sign-off), the hooks are not active
on a fresh clone until you run the one-time bootstrap:

```bash
./setup.sh --brew   # installs pre-commit + gitleaks (skip if already installed)
./setup-hooks.sh    # wires the hooks into this repo
```
```

Replace with:

```markdown
Because this machine sets `core.hooksPath` globally (for the DCO sign-off), the hooks are not active
on a fresh clone until you run the one-time bootstrap:

```bash
./setup.sh --brew   # installs pre-commit + gitleaks (skip if already installed)
./setup-hooks.sh    # wires the hooks into this repo
```

The remaining tools (shfmt, shellcheck, markdownlint-cli2, the hygiene hooks) need no manual install
— pre-commit fetches and caches each one in its own environment on first run.
```

- [ ] **Step 4: Update the bypass note to mention skipping individual hooks**

Use Edit on `README.md`. Find:

```markdown
To bypass scanning for a single commit (rare, intentional cases only):

```bash
git commit --no-verify        # skips ALL hooks (also skips the sign-off)
SKIP=gitleaks git commit      # skips only gitleaks, keeps the sign-off
```
```

Replace with:

```markdown
To bypass checks for a single commit (rare, intentional cases only):

```bash
git commit --no-verify              # skips ALL hooks (also skips the sign-off)
SKIP=gitleaks git commit            # skips only gitleaks, keeps everything else
SKIP=shellcheck,shfmt git commit    # skip specific hooks by id (comma-separated)
```
```

- [ ] **Step 5: Verify the new section landed and the file passes its own linter**

```bash
grep -n 'Pre-commit checks' README.md
pre-commit run markdownlint-cli2 --files README.md
```

Expected: the `grep` shows the `## Pre-commit checks` heading; markdownlint reports `Passed` (with `MD060` disabled, the README tables are fine).

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document the expanded pre-commit checks"
```

---

### Task 7: End-to-end verification through a real commit

This proves the hooks fire via `git commit` (not just `pre-commit run`) and that the DCO sign-off still works. It uses a throwaway commit that is rolled back, so history stays clean.

**Files:** none committed permanently

- [ ] **Step 1: Make a trivial, clean change and commit it through the hooks**

```bash
printf '\n' >> README.md
git add README.md
git commit -m "test: verify full hook suite on commit"
echo "exit=$?"
```

Expected: the commit **succeeds** (`exit=0`). The `pre-commit`-stage hooks run (gitleaks + hygiene + linters → all `Passed`; note `end-of-file-fixer` collapses the extra blank line, which may require one re-add + re-commit — that is the autofix flow working as designed).

- [ ] **Step 2: Confirm the DCO sign-off trailer was appended**

```bash
git log -1 --format=%B
```

Expected: the message ends with a `Signed-off-by: Martin Oehlert <...>` line (the `signoff` `prepare-commit-msg` hook ran).

- [ ] **Step 3: Roll back the throwaway commit**

```bash
git reset --hard HEAD~1
git status
```

Expected: working tree clean; `README.md` back to its committed state.

- [ ] **Step 4: Confirm a planted secret is still blocked (regression check on gitleaks)**

```bash
printf 'aws_secret_access_key = "wJalrXUtnFEMIK7MDENGbPxRfiCYwQ8H4kGhT9zZ"\n' > leak-test.txt
git add leak-test.txt
git commit -m "test: should be blocked"; echo "exit=$?"
```

Expected: the commit is **blocked** — gitleaks reports a finding and `exit` is non-zero. No commit is created.

- [ ] **Step 5: Clean up the planted file**

```bash
git reset leak-test.txt
rm -f leak-test.txt
git log -1 --format=%s
git status
```

Expected: `git log -1` shows the last real feature/docs commit (the blocked commit never landed); `git status` is clean with no `leak-test.txt`.

- [ ] **Step 6: Final state check**

```bash
git status
git log --oneline -8
```

Expected: working tree clean; the recent commits are the Task 1–6 feature/docs commits with no leftover `test:` commits or `leak-test.txt`.

---

## Self-review (completed during planning)

- **Spec coverage:** Hook group 1 (hygiene + data validation) → Task 1. Group 2 (shfmt + shellcheck, scoped to bash) → Task 2. Group 3 (`zsh -n`) → Task 3. Group 4 (markdownlint + `.markdownlint-cli2.yaml`) → Task 4. Rollout step 2 (`autoupdate` to lock revs) → folded into each task plus a final sweep in Task 5. Rollout step 3–4 (one-time autoformat + fix findings) → absorbed within Tasks 1/2/4 and re-proven in Task 5. Rollout step 5 (README docs) → Task 6. Verification → Task 7. The existing gitleaks + `signoff` config is preserved (shown verbatim in File structure; never edited destructively). All covered.
- **Spec refinement (justified):** `.markdownlint-cli2.yaml` disables `MD060` in addition to the spec's three rules, because `MD060` is not auto-fixable and would block every commit against the repo's compact tables. Verified read-only on 2026-06-11. The two non-autofixable `MD040` cases are fixed inline in Task 4 with exact locations.
- **Type/name consistency:** hook ids (`trailing-whitespace`, `end-of-file-fixer`, `mixed-line-ending`, `check-merge-conflict`, `check-case-conflict`, `check-executable-has-shebangs`, `check-shebang-scripts-are-executable`, `check-yaml`, `check-json`, `check-toml`, `shfmt`, `shellcheck`, `markdownlint-cli2`, `zsh-syntax-check`, `signoff`), the `files:` regex `(\.sh$|^git/hooks/prepare-commit-msg$)`, the `^iterm2/` excludes, and the config filename `.markdownlint-cli2.yaml` are used identically across every task and match the spec's target configuration.
- **Placeholder scan:** none — every config edit shows full before/after YAML, every verification step has an exact command and concrete expected output grounded in the read-only checks from Background facts.
