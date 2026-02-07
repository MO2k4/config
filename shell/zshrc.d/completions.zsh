if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

autoload -Uz compinit && compinit
autoload -U +X bashcompinit && bashcompinit

command -v kubectl &>/dev/null && source <(kubectl completion zsh)

source ~/az.completion

command -v ng &>/dev/null && source <(ng completion script)

compdef _dotnet_zsh_complete dotnet
compdef _gwt gwt
