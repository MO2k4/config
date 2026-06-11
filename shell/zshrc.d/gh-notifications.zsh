# Mark GitHub PR notifications as "done" once their PR is merged.
#
#   ghdone            # all repos
#   ghdone owner/repo # single repo only
#   ghdone -n         # dry-run: list what would be cleared, change nothing
#
# "Done" = DELETE /notifications/threads/{id} (removes from inbox);
# a plain "read" would be PATCH. Only genuinely merged PRs are touched —
# open or closed-unmerged notifications are left alone.
ghdone() {
  local dry=0 repo=""
  for arg in "$@"; do
    case "$arg" in
      -n|--dry-run) dry=1 ;;
      *) repo="$arg" ;;
    esac
  done

  local filter='.subject.type=="PullRequest"'
  [[ -n "$repo" ]] && filter+=" and .repository.full_name==\"$repo\""

  gh api 'notifications?all=true' --paginate \
    --jq ".[] | select($filter) | [.id, .subject.url, .repository.full_name] | @tsv" \
  | while IFS=$'\t' read -r tid url full; do
      [[ "$(gh api "$url" --jq '.merged' 2>/dev/null)" == "true" ]] || continue
      if (( dry )); then
        echo "would clear: $full PR#${url##*/}"
      else
        gh api -X DELETE "notifications/threads/$tid" \
          && echo "done: $full PR#${url##*/}"
      fi
    done
}
