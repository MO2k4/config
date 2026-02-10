# Completion cache directory (doubles as fpath entry for lazy loading)
ZSH_COMP_CACHE="$HOME/.zsh-completion-cache"
[[ -d "$ZSH_COMP_CACHE" ]] || mkdir -p -m 700 "$ZSH_COMP_CACHE"

# Cache a completion script into fpath (NOT sourced — compinit loads lazily on first TAB).
# Regenerates after 24h. Delete ~/.zsh-completion-cache to force refresh.
_cache_fpath() {
  local name="$1"; shift
  local cache_file="$ZSH_COMP_CACHE/_$name"
  local -a stale=($cache_file(N.mh+24))
  if [[ ! -f "$cache_file" ]] || (( $#stale )); then
    "$@" > "$cache_file" 2>/dev/null
  fi
}

# Cache and source a shell init script (for plugins that must run at startup).
# Uses zcompile for faster sourcing.
_cache_source() {
  local name="$1"; shift
  local cache_file="$ZSH_COMP_CACHE/$name.zsh"
  local -a stale=($cache_file(N.mh+24))
  if [[ ! -f "$cache_file" ]] || (( $#stale )); then
    "$@" > "$cache_file" 2>/dev/null
    zcompile "$cache_file" 2>/dev/null
  fi
  source "$cache_file"
}

# Generate completion caches (placed in fpath, loaded lazily by compinit)
command -v kubectl   &>/dev/null && _cache_fpath kubectl   kubectl completion zsh
command -v helm      &>/dev/null && _cache_fpath helm      helm completion zsh
command -v minikube  &>/dev/null && _cache_fpath minikube  minikube completion zsh
command -v kind      &>/dev/null && _cache_fpath kind      kind completion zsh
command -v k9s       &>/dev/null && _cache_fpath k9s       k9s completion zsh
command -v colima    &>/dev/null && _cache_fpath colima    colima completion zsh
command -v gh        &>/dev/null && _cache_fpath gh        gh completion -s zsh
command -v glab      &>/dev/null && _cache_fpath glab      glab completion -s zsh
command -v infracost &>/dev/null && _cache_fpath infracost infracost completion --shell zsh
command -v trivy     &>/dev/null && _cache_fpath trivy     trivy completion zsh
command -v ng        &>/dev/null && _cache_fpath ng        ng completion script
command -v yq        &>/dev/null && _cache_fpath yq        yq shell-completion zsh
command -v mise      &>/dev/null && _cache_fpath mise      mise completion zsh

# fpath: cache dir + homebrew completions
fpath=($ZSH_COMP_CACHE /opt/homebrew/share/zsh-completions /opt/homebrew/share/zsh/site-functions $fpath)

# compinit: full rebuild once/day, cached otherwise; compile in background
autoload -Uz compinit
local -a zcompdump_stale=(~/.zcompdump(N.mh+24))
if (( $#zcompdump_stale )); then
  compinit
else
  compinit -C
fi
{ zcompile ~/.zcompdump 2>/dev/null } &!

autoload -U +X bashcompinit && bashcompinit

# Infrastructure (uses bashcompinit's `complete`)
command -v terraform &>/dev/null && complete -o nospace -C terraform terraform
command -v packer    &>/dev/null && complete -o nospace -C packer packer

# Other tools
[ -f ~/az.completion ] && source ~/az.completion

# Custom completions
compdef _dotnet_zsh_complete dotnet
compdef _gwt gwt
