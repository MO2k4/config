# aictx Prompt Segment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display the active `aictx current` context as the first segment in the Oh My Posh prompt.

**Architecture:** Pre-compute the context value in `set_poshcontext()` (called by OMP before each render), store in env var, display via a `text` segment with a conditional template.

**Tech Stack:** Oh My Posh (JSON config), zsh

---

### Task 1: Add aictx text segment to prompt config

**Files:**
- Modify: `prompt/claude.omp.json:18-31` (insert new segment, update path segment)

- [ ] **Step 1: Insert new text segment at position 0 in the segments array**

In `prompt/claude.omp.json`, add this segment as the first entry in `blocks[0].segments` (before the existing path segment):

```json
{
  "template": "{{ if .Env.AICTX_CURRENT }} \udb80\udc65 {{ .Env.AICTX_CURRENT }} {{ end }}",
  "foreground": "p:white",
  "leading_diamond": "\ue0b6",
  "background": "p:red",
  "type": "text",
  "style": "diamond"
}
```

- [ ] **Step 2: Update the path segment's leading_diamond**

Change the path segment's `leading_diamond` from `"\ue0b6"` to `"<parentBackground,background>\ue0b0</>"` so it chains from the new aictx segment instead of being the prompt opener.

Old:
```json
"leading_diamond": "\ue0b6",
```

New:
```json
"leading_diamond": "<parentBackground,background>\ue0b0</>",
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('prompt/claude.omp.json'))"`
Expected: No output (valid JSON)

- [ ] **Step 4: Commit**

```bash
git add prompt/claude.omp.json
git commit -m "feat(prompt): add aictx context segment to Oh My Posh prompt"
```

---

### Task 2: Define set_poshcontext in shell config

**Files:**
- Modify: `shell/zshrc.d/prompt.zsh`

- [ ] **Step 1: Add set_poshcontext function after OMP init**

Append to `shell/zshrc.d/prompt.zsh` after the existing `_cache_source` line:

```zsh

function set_poshcontext() {
  export AICTX_CURRENT=$(aictx current 2>/dev/null)
}
```

This overrides the no-op `set_poshcontext` that OMP's init script defines. OMP calls it before every prompt render, keeping `AICTX_CURRENT` fresh.

The full file should now be:

```zsh
_cache_source oh-my-posh oh-my-posh init zsh --config ~/.poshthemes/craver_custom.omp.json --print

function set_poshcontext() {
  export AICTX_CURRENT=$(aictx current 2>/dev/null)
}
```

- [ ] **Step 2: Verify syntax**

Run: `zsh -n shell/zshrc.d/prompt.zsh`
Expected: No output (valid syntax)

- [ ] **Step 3: Commit**

```bash
git add shell/zshrc.d/prompt.zsh
git commit -m "feat(shell): add set_poshcontext to export aictx current context"
```

---

### Task 3: Manual verification

- [ ] **Step 1: Reload shell and verify**

Open a new terminal (or run `exec zsh`) and confirm:
1. The prompt shows `󰙅 <context>` in red as the first segment when `aictx current` returns a value
2. The segment is hidden when no context is set (test with `unset AICTX_CURRENT`)
3. The diamond chain flows correctly: red -> orange -> green -> accent -> blue
