if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

autoload -Uz compinit && compinit
autoload -U +X bashcompinit && bashcompinit

# Kubernetes & containers
command -v kubectl &>/dev/null && source <(kubectl completion zsh)
command -v helm &>/dev/null && source <(helm completion zsh)
command -v minikube &>/dev/null && source <(minikube completion zsh)
command -v kind &>/dev/null && source <(kind completion zsh)
command -v k9s &>/dev/null && source <(k9s completion zsh)
command -v colima &>/dev/null && source <(colima completion zsh)

# Git platforms
command -v gh &>/dev/null && source <(gh completion -s zsh)
command -v glab &>/dev/null && source <(glab completion -s zsh)

# Infrastructure
command -v terraform &>/dev/null && complete -o nospace -C terraform terraform
command -v packer &>/dev/null && complete -o nospace -C packer packer
command -v infracost &>/dev/null && source <(infracost completion --shell zsh)
command -v trivy &>/dev/null && source <(trivy completion zsh)

# Other tools
source ~/az.completion
command -v ng &>/dev/null && source <(ng completion script)
command -v yq &>/dev/null && source <(yq shell-completion zsh)

# Custom
compdef _dotnet_zsh_complete dotnet
compdef _gwt gwt
