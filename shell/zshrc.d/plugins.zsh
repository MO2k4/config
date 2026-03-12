source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

_cache_source fzf fzf --zsh
_cache_source mise mise activate zsh
_cache_source direnv direnv hook zsh
[[ "$CLAUDECODE" != "1" ]] && _cache_source zoxide zoxide init zsh --cmd cd

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
