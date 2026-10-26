# Loads MCP tokens (e.g. GRAFANA_SA_TOKEN for .mcp.json ${...} expansion) from a
# file outside this repo. The subshell keeps them out of the interactive shell.
claude() {
  (
    set -a
    [ -f ~/.secrets/mcp/claude-tokens.env ] && . ~/.secrets/mcp/claude-tokens.env
    exec command claude "$@"
  )
}
