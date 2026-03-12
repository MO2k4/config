# Design: Privileges Toggle and Update Aliases

Date: 2026-03-12

## Overview

Add a `priv` toggle function for PrivilegesCLI and update the existing `up` alias to a function
that automatically manages admin privileges around update commands.

## Components

### `priv` — privilege toggle function

A shell function in `shell/zshrc.d/aliases.zsh` that checks current admin group membership and
toggles privileges accordingly.

```zsh
priv() {
  if id -Gn | grep -q '\badmin\b'; then
    PrivilegesCLI --remove
  else
    PrivilegesCLI --add
  fi
}
```

- Uses `id -Gn` to check group membership — reliable, no dependency on PrivilegesCLI status command
- `PrivilegesCLI` is invoked without a path since it is installed via Homebrew at `/opt/homebrew/bin/`

### `up` — update function

Replaces the existing `up` alias with a function that auto-elevates only when needed, and only
revokes if it was the one that elevated.

```zsh
up() {
  local elevated=0
  if ! id -Gn | grep -q '\badmin\b'; then
    PrivilegesCLI --add || return 1
    elevated=1
  fi
  mise up && mise prune && brew update && brew upgrade && brew cleanup
  local exit_code=$?
  (( elevated )) && PrivilegesCLI --remove
  return $exit_code
}
```

Changes from the current alias:
- Removed `mise up --bump` (major version bumps, too aggressive for routine updates)
- Added auto-privilege management: request admin if not already elevated, revoke only if elevated by this function
- Preserves the caller's existing admin state — if they ran `priv` manually before `up`, they keep admin rights after

## File Changed

`shell/zshrc.d/aliases.zsh` — replace `up` alias with function, add `priv` function in the Convenience section.
