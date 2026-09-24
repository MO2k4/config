# Completion cache directory (doubles as fpath entry for lazy loading)
ZSH_COMP_CACHE="$HOME/.zsh-completion-cache"
[[ -d "$ZSH_COMP_CACHE" ]] || mkdir -p -m 700 "$ZSH_COMP_CACHE"

# Write generator output ($2...) to a cache file ($1). Regenerates when the
# generator's resolved binary path changes (brew upgrades land in a new
# versioned Cellar dir), or after 7 days for tools whose path never changes
# (mise shims, go/bin, npm globals). ctime is useless as an upgrade signal:
# something bumps it across the whole Cellar.
# Refreshes run in the background so the prompt never waits on cold generators
# (trivy/minikube/k9s take >1s each). Temp and signature files are dotfiles so
# compinit ignores them in fpath, and named after the cache file because
# _cache_fpath and _cache_source can share a name (mise).
# Delete ~/.zsh-completion-cache to force a synchronous rebuild.
_cache_refresh() {
  local cache_file="$1"; shift
  local sig_file="$ZSH_COMP_CACHE/.sig.${cache_file:t}" bin="${commands[$1]:A}" old_sig
  if [[ ! -f "$cache_file" ]]; then
    "$@" > "$cache_file" 2>/dev/null
    [[ "$cache_file" == *.zsh ]] && zcompile "$cache_file" 2>/dev/null
    print -r -- "$bin" > "$sig_file"
    return
  fi
  [[ -f "$sig_file" ]] && read -r old_sig < "$sig_file"
  local -a expired=($cache_file(N.mh+168))
  [[ "$old_sig" == "$bin" ]] && (( ! $#expired )) && return
  local tmp="$ZSH_COMP_CACHE/.tmp.${cache_file:t}.$$"
  {
    if "$@" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
      mv -f "$tmp" "$cache_file"
      [[ "$cache_file" == *.zsh ]] && zcompile "$cache_file" 2>/dev/null
    else
      # keep the old cache and don't retry on every shell until the next upgrade/expiry
      rm -f "$tmp"; touch "$cache_file"
    fi
    print -r -- "$bin" > "$sig_file"
  } &!
}

# Cache a completion script into fpath (NOT sourced — compinit loads lazily on first TAB).
_cache_fpath() {
  local name="$1"; shift
  _cache_refresh "$ZSH_COMP_CACHE/_$name" "$@"
}

# Cache and source a shell init script (for plugins that must run at startup).
# Uses zcompile for faster sourcing.
_cache_source() {
  local name="$1"; shift
  _cache_refresh "$ZSH_COMP_CACHE/$name.zsh" "$@"
  source "$ZSH_COMP_CACHE/$name.zsh"
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
  # compinit only rewrites the dump when the fpath file count changes, so bump
  # the mtime ourselves or the 24h check stays true forever.
  touch ~/.zcompdump
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
