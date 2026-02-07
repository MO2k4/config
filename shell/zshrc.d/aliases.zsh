# Utility
alias ls='lsd'
alias ll='ls --classify --group-directories-first --long --human-readable --almost-all --blocks permission,user,size,date,name --date "+%d %b %H:%M" --size short'
alias cat=bat
alias dockclean='docker system prune -f -a && docker volume rm $(docker volume ls -qf dangling=true)'

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
alias cosmos=$'f() { docker run -it --rm mongo mongosh "$(az cosmosdb keys list --type connection-strings --resource-group rg-mc-$1 --name cosmos-mc-$1 --query \"connectionStrings[?description==\'Primary MongoDB Connection String\'].connectionString\" -o tsv)&socketTimeoutMS=360000&connectTimeoutMS=360000" };f'
alias jwt_decode='jq -R "split(".") | .[0],.[1] | @base64d | fromjson" <<< $(pbpaste)'
alias az_client1=$'f() { export AZURE_CONFIG_DIR=~/.az_client1 && (az account list-locations &>/dev/null || az login --use-device-code) };f'
alias az_client2='f() { export AZURE_CONFIG_DIR=~/.az_client2 && (az account list-locations &>/dev/null || az login --use-device-code) };f'
