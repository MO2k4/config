# Privileges Toggle and Update Aliases Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `priv` toggle function for PrivilegesCLI and replace the `up` alias with a function that auto-manages admin privileges.

**Architecture:** Single file change to `shell/zshrc.d/aliases.zsh` — replace the `up` alias with a shell function, and add a `priv` function in the Convenience section. No new files needed.

**Tech Stack:** zsh, PrivilegesCLI (Homebrew), mise, brew

---

## Chunk 1: Implement changes

### Task 1: Update aliases.zsh

**Files:**
- Modify: `shell/zshrc.d/aliases.zsh:33` (replace `up` alias)
- Modify: `shell/zshrc.d/aliases.zsh` (add `priv` function)

- [ ] **Step 1: Read the current file**

Read `shell/zshrc.d/aliases.zsh` to confirm current state before editing.

- [ ] **Step 2: Replace the `up` alias with a function**

Remove line 33:
```zsh
alias up='mise up && mise up --bump && mise prune && brew update && brew upgrade && brew cleanup'
```

Replace with:
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

- [ ] **Step 3: Add `priv` function in the Convenience section**

After the `reload` alias, add:
```zsh
priv() {
  if id -Gn | grep -q '\badmin\b'; then
    PrivilegesCLI --remove
  else
    PrivilegesCLI --add
  fi
}
```

- [ ] **Step 4: Verify the file looks correct**

Read `shell/zshrc.d/aliases.zsh` and confirm:
- `up` is now a function (not an alias)
- `up` no longer contains `mise up --bump`
- `priv` function is present in the Convenience section
- No syntax errors (no stray `alias up=` line remaining)

- [ ] **Step 5: Manual smoke test**

Run in a new shell session:
```bash
source ~/.zshrc
type priv   # should show: priv is a shell function
type up     # should show: up is a shell function
```

- [ ] **Step 6: Commit**

```bash
git add shell/zshrc.d/aliases.zsh
git commit -m "feat(shell): add priv toggle and update up alias to use PrivilegesCLI"
```
