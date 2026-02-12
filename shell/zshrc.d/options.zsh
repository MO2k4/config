HISTFILE=~/.zsh_history
HISTSIZE=100000                      # Max entries kept in memory
SAVEHIST=100000                      # Max entries written to HISTFILE

setopt APPEND_HISTORY                # Append to history file instead of overwriting
setopt INC_APPEND_HISTORY            # Write each command immediately, not at shell exit
setopt EXTENDED_HISTORY              # Save timestamp and duration with each entry
setopt SHARE_HISTORY                 # Share history across all running sessions
setopt HIST_BEEP                     # Beep when accessing a non-existent history entry
setopt HIST_EXPIRE_DUPS_FIRST        # Evict duplicates first when HISTSIZE is reached
setopt HIST_FCNTL_LOCK               # Use kernel-level file locking for the history file
setopt HIST_FIND_NO_DUPS             # Skip duplicates when searching with Ctrl-R
setopt HIST_IGNORE_ALL_DUPS          # Remove older duplicate when a new duplicate is added
setopt HIST_IGNORE_DUPS              # Don't record an entry identical to the previous one
setopt HIST_IGNORE_SPACE             # Exclude commands starting with a space
setopt HIST_NO_STORE                 # Don't store the `history` command itself
setopt HIST_REDUCE_BLANKS            # Trim superfluous whitespace before saving
setopt HIST_SAVE_NO_DUPS             # Deduplicate when writing the history file
setopt HIST_VERIFY                   # Show expanded history substitution before executing
