#!/usr/bin/env bash
# Claude Code statusLine command: oh-my-posh line, then the superpowers plan progress line.
input=$(cat)
printf '%s' "$input" | AICTX_CURRENT=$(aictx current 2>/dev/null) oh-my-posh claude --config ~/claude.omp.json
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
[ -n "$dir" ] && plan=$("$(dirname "$0")/plan-progress.sh" "$dir")
# oh-my-posh ends without a newline
[ -n "${plan:-}" ] && printf '\n%s\n' "$plan"
exit 0
