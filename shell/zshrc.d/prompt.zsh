_cache_source oh-my-posh oh-my-posh init zsh --config ~/.poshthemes/craver_custom.omp.json --print

function set_poshcontext() {
  export AICTX_CURRENT=$(aictx current 2>/dev/null)
}
