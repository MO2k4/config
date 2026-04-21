# aictx Prompt Segment

## Summary

Add an `aictx current` context indicator as the first segment in the Oh My Posh prompt. The segment displays the active AI context name (e.g., `ifm`) with a project icon on a red background. It is hidden when no context is set.

## Changes

### 1. Shell: define `set_poshcontext()` in `shell/zshrc.d/prompt.zsh`

After the OMP init (which defines a no-op `set_poshcontext`), redefine it to export the current aictx value:

```zsh
function set_poshcontext() {
  export AICTX_CURRENT=$(aictx current 2>/dev/null)
}
```

OMP calls `set_poshcontext` before every prompt render, so `AICTX_CURRENT` stays fresh. The `2>/dev/null` handles the case where `aictx` is not installed.

### 2. Prompt: add text segment to `prompt/claude.omp.json`

Insert a new segment at position 0 in the segments array:

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

- `\udb80\udc65` = 󰙅 (project icon)
- Wrapped in `{{ if .Env.AICTX_CURRENT }}` so the segment is invisible when no context is set
- Takes over `leading_diamond: "\ue0b6"` (prompt opener) from the current path segment

### 3. Prompt: update existing path segment

Change the path segment's `leading_diamond` from `"\ue0b6"` to `"<parentBackground,background>\ue0b0</>"` so it chains from the new aictx segment.

## Segment order after change

```
[󰙅 ifm] [path] [git] [claude model] [claude usage]
   red    orange  green    accent        blue
```

## Edge cases

- **aictx not installed**: `2>/dev/null` suppresses errors; `AICTX_CURRENT` is empty; segment hidden.
- **No active context**: If `aictx current` returns empty string, segment hidden via template conditional.
- **Performance**: `aictx current` is a fast local lookup; no network calls.
