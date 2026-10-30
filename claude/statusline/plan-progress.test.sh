#!/usr/bin/env bash
set -u
script="$(cd "$(dirname "$0")" && pwd)/plan-progress.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# repo <name> <task count> <ledger dir> <ledger lines...>
repo() {
    local r="$tmp/$1" n=$2 led=$3
    shift 3
    mkdir -p "$r/docs" "$r/.superpowers/sdd/$led"
    git -C "$r" init -q
    for i in $(seq 1 "$n"); do printf '### Task %d: x\n\nbody\n' "$i"; done >"$r/docs/$led.md"
    { echo "# SDD ledger — plan: docs/$led.md"; printf '%s\n' "$@"; } >"$r/.superpowers/sdd/$led/progress.md"
    echo "$r"
}

check() {
    local name=$1 want=$2 got=$3
    if [ "$got" = "$want" ]; then echo "PASS $name"; else echo "FAIL $name: want '$want' got '$got'"; exit 1; fi
}

r=$(repo c1 3 p "Task 1: complete abc" "Task 2: Ruling: x" "Task 2: Ruling: y")
check "1 running with decisions" "plan p · 1/3 done · Task 2 running (2 decisions logged)" "$("$script" "$r")"

mkdir -p "$r/sub/dir"
check "9 subdirectory" "plan p · 1/3 done · Task 2 running (2 decisions logged)" "$("$script" "$r/sub/dir")"

r=$(repo c2 3 p)
check "2 header only" "plan p · 0/3 done · Task 1 running" "$("$script" "$r")"

r=$(repo c3 3 p "Task 2: complete" "Task 3: complete" "Task 1 (partial: step 2)")
check "3 out of order" "plan p · 2/3 done · Task 1 running" "$("$script" "$r")"

r=$(repo c4 12 p "Task 10: complete" "Task 1: Ruling: a" "Task 10: Ruling: b")
check "4 prefix collision" "plan p · 1/12 done · Task 1 running (1 decisions logged)" "$("$script" "$r")"

r=$(repo c5 3 p "Task 1: complete" "Task 2: complete" "Task 3: complete")
check "5 all complete" "" "$("$script" "$r")"

r=$(repo c6 3 p "Task 1: complete")
touch -t "$(date -v-25H +%Y%m%d%H%M)" "$r/.superpowers/sdd/p/progress.md"
check "6 stale ledger" "" "$("$script" "$r")"

r=$(repo c7 3 p "Task 1: complete")
mkdir -p "$r/.superpowers/sdd/q"
cp "$r/.superpowers/sdd/p/progress.md" "$r/.superpowers/sdd/q/progress.md"
touch -t "$(date -v-1H +%Y%m%d%H%M)" "$r/.superpowers/sdd/p/progress.md"
got=$("$script" "$r")
check "7 newest ledger wins" "plan q " "${got:0:7}"

r=$(repo c8 3 p "Task 1: complete")
rm "$r/docs/p.md"
check "8 plan file missing" "plan p · 1 done · plan file missing" "$("$script" "$r")"

mkdir -p "$tmp/norepo"
got=$("$script" "$tmp/norepo"; echo "rc=$?")
check "10 not a repo" "rc=0" "$got"
