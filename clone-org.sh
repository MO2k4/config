#!/bin/bash
# Clones every non-archived repo of a GitHub org that is not checked out yet.
#   ./clone-org.sh [org] [dir]    defaults: ais-schule ~/Work/ais
# Existing folders are left alone, so it is safe to re-run.
set -euo pipefail

ORG="${1:-ais-schule}"
DIR="${2:-$HOME/Work/ais}"
mkdir -p "$DIR"

# shellcheck disable=SC2016 # the inner sh expands $1..$3
gh repo list "$ORG" --limit 1000 --no-archived --json name -q '.[].name' |
    while read -r repo; do
        [ -e "$DIR/$repo" ] || echo "$repo"
    done |
    xargs -P 4 -I{} sh -c 'git clone --quiet "git@github.com:$1/$2.git" "$3/$2" && echo "cloned $2"' _ "$ORG" {} "$DIR"
