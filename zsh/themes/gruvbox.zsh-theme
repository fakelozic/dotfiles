# A small native Oh My Zsh prompt using the Gruvbox Dark palette.
# It mirrors the previous Starship prompt without another prompt binary.

setopt prompt_subst

typeset -g GRUVBOX_ORANGE='#fe8019'
typeset -g GRUVBOX_BLUE='#83a598'
typeset -g GRUVBOX_AQUA='#8ec07c'
typeset -g GRUVBOX_GREEN='#b8bb26'
typeset -g GRUVBOX_YELLOW='#fabd2f'
typeset -g GRUVBOX_PURPLE='#d3869b'
typeset -g GRUVBOX_RED='#fb4934'
typeset -g GRUVBOX_GRAY='#928374'

# Match Starship's default behavior: hostname appears only over SSH.
typeset -g GRUVBOX_USER_HOST="%F{${GRUVBOX_ORANGE}}%n"
if [[ -n ${SSH_CONNECTION:-} ]]; then
  GRUVBOX_USER_HOST+="@%m"
fi
GRUVBOX_USER_HOST+='%f'

# Oh My Zsh's Git helpers supply the branch and working-tree state.
ZSH_THEME_GIT_PROMPT_PREFIX="%F{${GRUVBOX_GRAY}}| %F{${GRUVBOX_AQUA}} "
ZSH_THEME_GIT_PROMPT_SUFFIX='%f '
ZSH_THEME_GIT_PROMPT_DIRTY=''
ZSH_THEME_GIT_PROMPT_CLEAN=''
ZSH_THEME_GIT_PROMPT_ADDED="%F{${GRUVBOX_GREEN}}+%f"
ZSH_THEME_GIT_PROMPT_MODIFIED="%F{${GRUVBOX_YELLOW}}!%f"
ZSH_THEME_GIT_PROMPT_DELETED="%F{${GRUVBOX_RED}}-%f"
ZSH_THEME_GIT_PROMPT_RENAMED="%F{${GRUVBOX_PURPLE}}»%f"
ZSH_THEME_GIT_PROMPT_UNMERGED="%F{${GRUVBOX_RED}}=%f"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{${GRUVBOX_ORANGE}}?%f"
ZSH_THEME_GIT_PROMPT_STASHED="%F{${GRUVBOX_AQUA}}\$%f"
ZSH_THEME_GIT_PROMPT_AHEAD="%F{${GRUVBOX_BLUE}}⇡%f"
ZSH_THEME_GIT_PROMPT_BEHIND="%F{${GRUVBOX_BLUE}}⇣%f"
ZSH_THEME_GIT_PROMPT_DIVERGED="%F{${GRUVBOX_PURPLE}}⇕%f"

# user | path | branch/status | jobs | HH:MM prompt
PROMPT='${GRUVBOX_USER_HOST} %F{$GRUVBOX_GRAY}| %F{$GRUVBOX_BLUE}%3~%f $(git_prompt_info)$(git_prompt_status)%1(j.%F{$GRUVBOX_GRAY}| %F{$GRUVBOX_RED} %j %f.)%F{$GRUVBOX_GRAY}| %D{%H:%M}%f %(?.%F{$GRUVBOX_GREEN}󰄾.%F{$GRUVBOX_RED}󰄾)%f '
RPROMPT=''
