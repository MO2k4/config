# Mark GitHub notifications as "done" once their PR is merged or issue is closed.
#
#   ghdone            # all repos
#   ghdone owner/repo # single repo only
#   ghdone -n         # dry-run: list what would be cleared, change nothing
#
# "Done" = DELETE /notifications/threads/{id} (removes from inbox);
# a plain "read" would be PATCH. Closed PRs (merged or not) and closed issues
# are touched — anything still open is left alone.
ghdone() {
  local dry=0 repo="" label=""
  for arg in "$@"; do
    case "$arg" in
      -n|--dry-run) dry=1 ;;
      *) repo="$arg" ;;
    esac
  done

  local filter='(.subject.type=="PullRequest" or .subject.type=="Issue")'
  [[ -n "$repo" ]] && filter+=" and .repository.full_name==\"$repo\""

  gh api notifications --paginate \
    --jq ".[] | select($filter) | [.id, .subject.url, .subject.type, .repository.full_name] | @tsv" \
  | while IFS=$'\t' read -r tid url type full; do
      case "$type" in
        PullRequest)
          [[ "$(gh api "$url" --jq '.state' 2>/dev/null)" == "closed" ]] || continue
          label="PR#${url##*/}" ;;
        Issue)
          [[ "$(gh api "$url" --jq '.state' 2>/dev/null)" == "closed" ]] || continue
          label="issue#${url##*/}" ;;
        *) continue ;;
      esac
      if (( dry )); then
        echo "would clear: $full $label"
      else
        gh api -X DELETE "notifications/threads/$tid" \
          && echo "done: $full $label"
      fi
    done
}
