# A small native Oh My Zsh prompt using the Gruvbox Dark palette.
# It mirrors starship.toml for machines without Starship:
#   fak3 | …/c/lsbtw | git:main !1 ?1 (+22 -1) | 47s | exit 1 | jobs 1 | 01:40:14 ❯
# Plain text only (no Nerd Font icons), so the prompt reads the same when pasted.

setopt prompt_subst
zmodload zsh/datetime

typeset -g GRUVBOX_ORANGE='#fe8019'
typeset -g GRUVBOX_BLUE='#83a598'
typeset -g GRUVBOX_AQUA='#8ec07c'
typeset -g GRUVBOX_GREEN='#b8bb26'
typeset -g GRUVBOX_YELLOW='#fabd2f'
typeset -g GRUVBOX_PURPLE='#d3869b'
typeset -g GRUVBOX_RED='#fb4934'
typeset -g GRUVBOX_GRAY='#928374'

# user, plus @host over SSH.
typeset -g GRUVBOX_USER_HOST="%B%F{${GRUVBOX_ORANGE}}%n"
[[ -n ${SSH_CONNECTION:-} ]] && GRUVBOX_USER_HOST+="@%m"
GRUVBOX_USER_HOST+='%f%b'

# The last two folders, counted from ~.
typeset -g GRUVBOX_DIR="%B%F{${GRUVBOX_BLUE}}%(3~|…/%2~|%~)%f%b"

typeset -g _gruvbox_cmd_start=''
typeset -gi _gruvbox_drawn=0
typeset -g GRUVBOX_GIT='' GRUVBOX_LAST=''

_gruvbox_preexec() { _gruvbox_cmd_start=$EPOCHREALTIME }

# Branch, counts per kind, and lines changed since the last commit.
_gruvbox_git() {
  GRUVBOX_GIT=''
  local line branch='' detached=''
  local -i staged=0 modified=0 deleted=0 renamed=0 conflicted=0 untracked=0
  local -i ahead=0 behind=0 stashed=0 added_lines=0 removed_lines=0
  local -a lines
  lines=("${(@f)$(command git status --porcelain=v2 --branch --show-stash 2>/dev/null)}") || return
  (( ${#lines} )) && [[ -n ${lines[1]} ]] || return
  for line in $lines; do
    case $line in
      '# branch.head '*) branch=${line#\# branch.head } ;;
      '# branch.oid '*) detached=${${line#\# branch.oid }[1,7]} ;;
      '# branch.ab '*) ahead=${${(s: :)line}[3]#+}; behind=${${(s: :)line}[4]#-} ;;
      '# stash '*) stashed=${line#\# stash } ;;
      'u '*) (( conflicted++ )) ;;
      '? '*) (( untracked++ )) ;;
      [12]' '*)
        [[ ${line[3]} != . ]] && (( staged++ ))
        case ${line[4]} in
          M|T) (( modified++ )) ;;
          D) (( deleted++ )) ;;
        esac
        [[ ${line[1]} == 2 ]] && (( renamed++ ))
        ;;
    esac
  done
  local g="%F{$GRUVBOX_GRAY}| "
  if [[ $branch == '(detached)' ]]; then
    g+="%B%F{$GRUVBOX_AQUA}detached ${detached}%b "
  else
    g+="%B%F{$GRUVBOX_AQUA}git:${branch}%b "
  fi
  (( conflicted )) && g+="%F{$GRUVBOX_RED}=${conflicted} "
  (( stashed )) && g+="%F{$GRUVBOX_PURPLE}\$${stashed} "
  (( deleted )) && g+="%F{$GRUVBOX_RED}-${deleted} "
  (( renamed )) && g+="%F{$GRUVBOX_PURPLE}»${renamed} "
  (( modified )) && g+="%F{$GRUVBOX_YELLOW}!${modified} "
  (( staged )) && g+="%F{$GRUVBOX_GREEN}+${staged} "
  (( untracked )) && g+="%F{$GRUVBOX_GRAY}?${untracked} "
  if (( ahead && behind )); then
    g+="%F{$GRUVBOX_PURPLE}↑${ahead}↓${behind} "
  else
    (( ahead )) && g+="%F{$GRUVBOX_BLUE}↑${ahead} "
    (( behind )) && g+="%F{$GRUVBOX_BLUE}↓${behind} "
  fi
  local -a stat
  stat=(${(s: :)$(command git diff HEAD --shortstat 2>/dev/null)})
  local i
  for (( i = 1; i <= ${#stat}; i++ )); do
    [[ ${stat[i+1]} == insertion* ]] && added_lines=${stat[i]}
    [[ ${stat[i+1]} == deletion* ]] && removed_lines=${stat[i]}
  done
  if (( added_lines || removed_lines )); then
    g+="%F{$GRUVBOX_GRAY}("
    (( added_lines )) && g+="%F{$GRUVBOX_GREEN}+${added_lines}"
    (( removed_lines )) && g+=" %F{$GRUVBOX_RED}-${removed_lines}"
    g+="%F{$GRUVBOX_GRAY}) "
  fi
  GRUVBOX_GIT="${g}%f"
}

# Duration (2 s or longer), exit code and background jobs of the last command.
_gruvbox_precmd() {
  local -i code=$?
  # A blank line before every prompt but the first, like Starship's add_newline.
  if (( _gruvbox_drawn )); then print; else _gruvbox_drawn=1; fi
  GRUVBOX_LAST=''
  if [[ -n $_gruvbox_cmd_start ]]; then
    local -i secs=$(( EPOCHREALTIME - _gruvbox_cmd_start ))
    if (( secs >= 2 )); then
      local d=''
      (( secs >= 3600 )) && d+="$(( secs / 3600 ))h"
      (( secs >= 60 )) && d+="$(( secs % 3600 / 60 ))m"
      d+="$(( secs % 60 ))s"
      GRUVBOX_LAST+="%F{$GRUVBOX_GRAY}| %F{$GRUVBOX_YELLOW}${d} "
    fi
    if (( code )); then
      local sig=''
      (( code > 128 && code - 128 < ${#signals} )) && sig=" ${signals[code - 127]}"
      GRUVBOX_LAST+="%F{$GRUVBOX_GRAY}| %B%F{$GRUVBOX_RED}exit ${code}${sig}%b "
    fi
  fi
  _gruvbox_cmd_start=''
  GRUVBOX_LAST+='%f'
  _gruvbox_git
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _gruvbox_preexec
add-zsh-hook precmd _gruvbox_precmd

PROMPT='${GRUVBOX_USER_HOST} %F{$GRUVBOX_GRAY}|%f ${GRUVBOX_DIR} ${GRUVBOX_GIT}${GRUVBOX_LAST}%1(j.%F{$GRUVBOX_GRAY}| %B%F{$GRUVBOX_RED}jobs %j%b%f .)%F{$GRUVBOX_GRAY}| %D{%H:%M:%S}%f %B%(?.%F{$GRUVBOX_GREEN}.%F{$GRUVBOX_RED})❯%f%b '
RPROMPT=''
