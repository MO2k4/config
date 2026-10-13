# Mark GitHub notifications as "done" once their PR is merged or issue is closed.
#
#   ghdone            # all repos
#   ghdone owner/repo # single repo only
#   ghdone -n         # dry-run: count what would be cleared per repo, change nothing
#
# GHDONE_JOBS (default 8) caps parallel reads; DELETEs run 4 at a time.
# GHDONE_BATCH (default 100) sets items per GraphQL query — larger batches cost
# the same point but run slower.
#
# "Done" = DELETE /notifications/threads/{id} (removes from inbox);
# a plain "read" would be PATCH. Closed PRs (merged or not) and closed issues
# are touched — anything still open is left alone.
ghdone() {
  local dry=0 repo="" batch=${GHDONE_BATCH:-100} jobs=${GHDONE_JOBS:-8}
  for arg in "$@"; do
    case "$arg" in
      -n|--dry-run) dry=1 ;;
      *) repo="$arg" ;;
    esac
  done

  local filter='(.subject.type=="PullRequest" or .subject.type=="Issue")'
  [[ -n "$repo" ]] && filter+=" and .repository.full_name==\"$repo\""

  local tmp last
  local jq=".[] | select($filter) | [.id, .subject.url, .subject.type, .repository.full_name] | @tsv"
  tmp=$(mktemp -d) || return 1

  # Page 1's Link header names the last page, so the rest can be fetched in
  # parallel instead of walking rel="next" (~0.5s per page, 90+ pages).
  # per_page is ignored by this endpoint; pages stay at 50.
  gh api -i notifications --jq "$jq" > "$tmp/head" || { rm -rf "$tmp"; return 1; }
  last=$(sed -n 's/.*[?&]page=\([0-9]*\)>; rel="last".*/\1/p' "$tmp/head")
  sed '1,/^\r*$/d' "$tmp/head" > "$tmp/p.1"
  print -u2 "fetching ${last:-1} pages of notifications..."
  (( ${last:-1} > 1 )) && seq 2 "$last" | xargs -P "$jobs" -I{} sh -c \
    'gh api "notifications?page=$1" --jq "$2" > "$3/p.$1"' _ {} "$jq" "$tmp"
  # Pages can shift while fetching; drop duplicate threads.
  cat "$tmp"/p.<->(n) | awk -F'\t' '!seen[$1]++' > "$tmp/list"
  [[ -s "$tmp/list" ]] || { rm -rf "$tmp"; return; }

  # One REST lookup per item would eat most of the 5000/h core budget, so look
  # states up as aliased GraphQL batches (1 point each). Deleted or inaccessible
  # repos come back as null aliases next to errors and are skipped.
  local query='"{" + ([split("\n")[] | select(. != "") | split("\t")
    | (.[1] | capture("repos/(?<o>[^/]+)/(?<r>[^/]+)/[a-z]+/(?<n>[0-9]+)$")) as $m
    | "t\(.[0]): repository(owner:\"\($m.o)\",name:\"\($m.r)\"){issueOrPullRequest(number:\($m.n)){... on PullRequest{state} ... on Issue{state}}}"
    ] | join(" ")) + "}"'
  print -u2 "checking state of $(( $(wc -l < "$tmp/list") )) PRs/issues..."
  split -l "$batch" "$tmp/list" "$tmp/batch."
  print -l "$tmp"/batch.* | xargs -P "$jobs" -I{} sh -c \
    'jq -Rrs "$1" "$2" | gh api graphql -F query=@- > "$2.json" 2>/dev/null' _ "$query" {}

  # REST "closed" covers both GraphQL CLOSED and MERGED.
  jq -r '.data // {} | to_entries[] | select(.value.issueOrPullRequest.state == ("CLOSED", "MERGED")) | .key[1:]' \
    "$tmp"/batch.*.json \
  | awk -F'\t' 'NR == FNR { closed[$1]; next } $1 in closed {
      n = $2; sub(/.*\//, "", n)
      print $1, $4, ($3 == "Issue" ? "issue" : "PR") "#" n
    }' - "$tmp/list" > "$tmp/done"

  local total=$(( $(wc -l < "$tmp/done") )) n=0 failed=0 r
  print "$total closed, ready to clear"

  if (( dry )); then
    cut -d' ' -f2 "$tmp/done" | sort | uniq -c | sort -rn
  elif (( total )); then
    # DELETEs cost 5 points against the secondary per-minute limit; keep them few.
    xargs -P 4 -L1 sh -c \
      'gh api -X DELETE "notifications/threads/$2" 2>>"$1/err" && echo ok || echo fail' \
      _ "$tmp" < "$tmp/done" \
    | while read -r r; do
        (( n++ )); [[ $r == ok ]] || (( failed++ ))
        printf '\r[%-30s] %d/%d cleared, %d failed' \
          "${(l:n*30/total::#:):-}" $(( n - failed )) $total $failed
      done
    print
    # Usually the hourly rate limit; a rerun after the reset picks up the rest.
    (( failed )) && print -u2 "last error: $(tail -1 "$tmp/err")"
  fi
  rm -rf "$tmp"
}
