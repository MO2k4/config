# Utility
alias ls='lsd'
alias ll='ls --classify --group-directories-first --long --human-readable --almost-all --blocks permission,user,size,date,name --date "+%d %b %H:%M" --size short'
alias cat=bat
alias dockclean='docker system prune -f -a && { vols=$(docker volume ls -qf dangling=true); [ -n "$vols" ] && docker volume rm $vols || true; }'

# Git navigation
alias gitroot='cd "$(git worktree list --porcelain | awk "/worktree/ {print \$2; exit}")"'

# Git commands
alias gst='git status'
alias ga='git add -A'
alias gc='git commit'
alias gcm='git commit -a -m'
alias gd='git diff'
alias gdc='git diff --cached'
alias gp='git push'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gcp='git cherry-pick'
alias gfoo='gcm "foobar"; gp'
alias grc='GIT_EDITOR=true git rebase --continue'

# Azure
alias jwt_decode='jq -R "split(".") | .[0],.[1] | @base64d | fromjson" <<< $(pbpaste)'

# Tools
alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# Convenience
alias reload='source ~/.zshrc'
alias up='mise up && mise up --bump && mise prune && brew update && brew upgrade && brew cleanup'
