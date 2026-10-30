#!/usr/bin/env bash
# Prints the progress line of the newest superpowers SDD ledger in the repo containing $1.
# Must never break the statusline: prints nothing and exits 0 on any problem.

main() {
    local root ledger name plan total done n current rulings
    root=$(git -C "$1" rev-parse --show-toplevel) || return
    ledger=$(find "$root/.superpowers/sdd" -mindepth 2 -maxdepth 2 -name progress.md -mtime -1 -exec stat -f '%m %N' {} + |
        sort -rn | head -1 | cut -d' ' -f2-)
    [ -n "$ledger" ] || return
    name=$(basename "$(dirname "$ledger")")
    done=$(grep -cE '^Task [0-9]+: complete' "$ledger")

    plan="$root/$(head -1 "$ledger" | sed -n 's/^# SDD ledger — plan: //p')"
    if [ ! -f "$plan" ]; then
        echo "plan $name · $done done · plan file missing"
        return
    fi
    total=$(grep -cE '^### Task [0-9]+:' "$plan")

    for ((n = 1; n <= total; n++)); do
        grep -qE "^Task $n: complete" "$ledger" || { current=$n; break; }
    done
    [ -n "${current:-}" ] || return

    rulings=$(grep -cE "^Task $current: Ruling:" "$ledger")
    printf 'plan %s · %s/%s done · Task %s running' "$name" "$done" "$total" "$current"
    [ "$rulings" -gt 0 ] && printf ' (%s decisions logged)' "$rulings"
    echo
}

main "${1:-.}" 2>/dev/null
exit 0
