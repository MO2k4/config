#!/bin/sh
# Husky per-user init — sourced by .husky/_/h before every hook in every
# husky-managed repo. Husky sets core.hooksPath=.husky/_, which shadows the
# global ~/.githooks layer; re-run the global drop-ins here so they apply
# in husky repos too.
#
# $0 is the husky shim path (e.g. .husky/_/prepare-commit-msg) — sourcing
# preserves it — and "$@" carries the hook arguments. SKIP_REPO_DELEGATE
# stops the dispatcher from also running $GIT_DIR/hooks/<name>: husky owns
# the repo layer here, and stale hooks in .git/hooks must stay dead.

husky_global_hook="$HOME/.githooks/$(basename "$0")"
if [ -x "$husky_global_hook" ]; then
    GITHOOKS_SKIP_REPO_DELEGATE=1 "$husky_global_hook" "$@" || exit $?
fi
unset husky_global_hook
