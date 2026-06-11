# Expanded pre-commit checks — design

**Date:** 2026-06-11
**Status:** Approved, pending implementation

## Goal

Extend `.pre-commit-config.yaml` beyond the current gitleaks + DCO-signoff setup
into a full hygiene, linting, and formatting safety net for this dotfiles repo.
Direction chosen by the user: **both maximally** — catch breakage *and* enforce
consistency, including hooks that rewrite files on commit.

## Repo composition (what we're protecting)

- **Bash** — 5 files: `setup.sh`, `setup-hooks.sh`, `update-brewfile.sh`,
  `update-iterm2.sh`, `git/hooks/prepare-commit-msg` (all have `sh` shebangs).
- **zsh** — `shell/zshrc`, `shell/zshenv`, `shell/zprofile`, everything under
  `shell/functions/`, and `shell/zshrc.d/*.zsh`. (`shell/bashrc` is bash.)
- **Structured data** — 2 JSON (oh-my-posh themes), 1 YAML (this config),
  1 TOML (`mise/config.toml`), 1 plist (iTerm2, ~17 KB, machine-managed).
- **Markdown** — 6 files, mostly machine-generated specs/plans.
- **Other** — `Brewfile`, `git/gitconfig*`, `vim/vimrc`, vendored completions.

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | Full hygiene + linting + formatting | User selected "both, maximally" |
| File rewriting | Allowed | User accepted autofix hooks |
| zsh linting | `zsh -n` syntax check (not shellcheck/shfmt) | shellcheck/shfmt only understand bash/POSIX and produce noise on zsh |
| Bash linting | shellcheck + shfmt, scoped to the 5 bash files only | Avoid false positives on zsh |
| Markdown | Full `markdownlint-cli2` with a few noisy rules disabled | User chose full linting, accepting tuning |
| iTerm2 plist | Excluded from rewriting hooks | Machine-managed by `update-iterm2.sh`; rewrites would corrupt it |

## Hooks to add

### 1. Generic hygiene & structured-data validation

Repo: `pre-commit/pre-commit-hooks` (v5.0.0)

- `trailing-whitespace` — strip trailing spaces *(rewrites; excludes `^iterm2/`)*
- `end-of-file-fixer` — single final newline *(rewrites; excludes `^iterm2/`)*
- `mixed-line-ending` `--fix=lf` — normalize to LF *(rewrites; excludes `^iterm2/`)*
- `check-merge-conflict` — block unresolved conflict markers
- `check-case-conflict` — block case-collision names (macOS case-insensitive FS)
- `check-executable-has-shebangs` — exec bit ⇒ must have shebang
- `check-shebang-scripts-are-executable` — shebang ⇒ must be executable
- `check-yaml` — validate this config
- `check-json` — validate the 2 omp themes
- `check-toml` — validate `mise/config.toml`

### 2. Bash linting & formatting

Scoped to bash files via `files: (\.sh$|^git/hooks/prepare-commit-msg$)`.

- `shfmt` (`scop/pre-commit-shfmt`) — `args: [-w, -i, '4', -ci]`
  (4-space indent matching existing code, indent switch-cases). **Rewrites.**
- `shellcheck` (`shellcheck-py/shellcheck-py`) — static analysis, report-only.

Both run in pre-commit-managed environments; no Homebrew installs required.

### 3. zsh syntax check

`local` hook running `zsh -n` (parse-only):

- `entry: zsh -n`, `language: system`, `pass_filenames: true`
- `files: ^shell/(zshrc|zshenv|zprofile|functions/|zshrc\.d/.*\.zsh)`
- Excludes `shell/bashrc` and vendored `prompt/` completions.
- Report-only; needs zsh on PATH (guaranteed on this macOS/zsh setup).

### 4. Markdown linting

`markdownlint-cli2` (`DavidAnson/markdownlint-cli2`), scoped to `\.md$`,
`args: [--fix]`. Runs in pre-commit's Node environment; no global npm install.

Paired with `.markdownlint-cli2.yaml` disabling:

- `MD013` (line length) — generated prose has long lines
- `MD033` (inline HTML) — specs use `<details>`, `<br>`, etc.
- `MD024` (duplicate headings) — plans repeat headings across sections

All other rules stay on.

## Target configuration

```yaml
default_install_hook_types: [pre-commit, prepare-commit-msg]

repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
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

  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.18.1
    hooks:
      - id: markdownlint-cli2
        args: [--fix]

  - repo: local
    hooks:
      - id: zsh-syntax-check
        name: zsh -n syntax check
        entry: zsh -n
        language: system
        files: ^shell/(zshrc|zshenv|zprofile|functions/|zshrc\.d/.*\.zsh)
        pass_filenames: true

      - id: signoff
        name: Append Signed-off-by (DCO)
        entry: git/hooks/prepare-commit-msg
        language: script
        stages: [prepare-commit-msg]
        always_run: true
        pass_filenames: true
```

> The `rev` pins above are best-known values; they are confirmed/refreshed via
> `pre-commit autoupdate` during implementation rather than trusted as-is.

## Rollout plan

1. Write the config + `.markdownlint-cli2.yaml`.
2. `pre-commit autoupdate` to lock exact latest `rev` pins.
3. `pre-commit run --all-files` once — triggers one-time auto-formatting
   (shfmt, whitespace, EOF, markdown) and surfaces shellcheck/zsh findings.
4. Fix anything shellcheck or markdownlint reports that isn't auto-fixed
   (or add inline `# shellcheck disable=` pragmas where a finding is intentional).
5. Document the new checks in `README.md` (alongside existing gitleaks/setup-hooks docs).

## Out of scope

- Linting/formatting zsh beyond `zsh -n` (no zsh formatter exists that's worth it).
- Validating the iTerm2 plist (binary/managed; left untouched).
- Reformatting vendored completions under `prompt/`.
- Any CI integration — this is local pre-commit only.
