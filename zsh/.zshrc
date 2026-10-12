export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="gruvbox"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

alias ezl="eza -lahg --icons --group-directories-first"
alias ezo="eza -lahgo --icons --group-directories-first"
alias ezg="eza -lahg --icons --group-directories-first --git"
alias ezt="eza -T --icons --group-directories-first --level=2"
alias pstat='stat -c "%A %a %n"'
alias refresh='source ~/.zshrc'

# Attempt both update managers and report failures from either one.
unalias suup 2>/dev/null || :
function suup() {
  local dnf_status=0 flatpak_status=0

  sudo dnf upgrade --refresh --setopt='*.skip_if_unavailable=False' || dnf_status=$?
  flatpak update || flatpak_status=$?

  if (( dnf_status || flatpak_status )); then
    print -u2 -- "suup: DNF exit status=$dnf_status; Flatpak exit status=$flatpak_status"
    return 1
  fi
  return 0
}

# Machine-specific PATH entries and toolchain managers stay out of the repository.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
