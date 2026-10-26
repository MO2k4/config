#!/bin/bash
# Global agent skills managed by `npx skills`, kept in skills.txt.
#   ./skills.sh dump      write skills.txt from ~/.agents/.skill-lock.json
#   ./skills.sh install   reinstall everything in skills.txt
# skills.txt: first line "agents <agent>...", then one "<source> <skill>..." line per repo.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
LIST="$DOTFILES/skills.txt"

case "${1:-}" in
    dump)
        python3 - "$HOME/.agents/.skill-lock.json" >"$LIST" <<'PY'
import collections, json, sys
lock = json.load(open(sys.argv[1]))
renamed = {"kimi-cli": "kimi-code-cli"}  # the lock keeps names the CLI no longer accepts
agents = lock.get("lastSelectedAgents") or ["claude-code"]
print("agents", *(renamed.get(a, a) for a in agents))
by_source = collections.defaultdict(list)
for name, skill in lock["skills"].items():
    by_source[skill["source"]].append(name)
for source in sorted(by_source):
    print(source, *sorted(by_source[source]))
PY
        echo "Wrote $LIST ($(($(wc -l <"$LIST") - 1)) sources)"
        ;;
    install)
        read -r _ agents <"$LIST"
        tail -n +2 "$LIST" | while read -r source skills; do
            echo "== $source"
            # shellcheck disable=SC2086 # agents and skills are space-separated lists
            npx -y skills add "$source" -g -y -a $agents -s $skills </dev/null
        done
        # own skills are linked live from their repo, so edits there apply at once
        own="$HOME/Work/github/claude-skills/skills"
        if [ -d "$own" ]; then
            mkdir -p "$HOME/.claude/skills"
            for d in "$own"/*/; do
                d="${d%/}"
                ln -sfn "$d" "$HOME/.claude/skills/${d##*/}"
                echo "linked ${d##*/}"
            done
        else
            echo "skipped own skills: clone MO2k4/claude-skills to ${own%/skills} and re-run"
        fi
        ;;
    *)
        echo "usage: $0 dump|install" >&2
        exit 1
        ;;
esac
