export ZSH="$HOME/.oh-my-zsh"

# Starship draws the prompt when installed; otherwise use the bundled Gruvbox theme.
if (( $+commands[starship] )); then
  ZSH_THEME=""
else
  ZSH_THEME="gruvbox"
fi
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

(( $+commands[starship] )) && eval "$(starship init zsh)"

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

# Update the developer tools that dnf and Flatpak don't manage. Claude Code,
# opencode, codex and Antigravity are also kept current by T3 Code.
function devup() {
  local -a failed
  local current latest

  if (( $+commands[mise] )); then
    print -P '\n%B==> mise%b'
    mise self-update --yes || failed+=(mise)
    # Only the global tools (go, node, pnpm, gh, neovim, codex), not this folder's.
    print -P '\n%B==> mise tools%b'
    (cd ~ && mise upgrade) || failed+=('mise tools')
  fi
  if (( $+commands[bun] )); then
    print -P '\n%B==> bun%b'
    bun upgrade || failed+=(bun)
  fi
  if (( $+commands[nub] )); then
    print -P '\n%B==> nub%b'
    nub upgrade || failed+=(nub)
  fi
  if (( $+commands[rustup] )); then
    print -P '\n%B==> rust%b'
    rustup update || failed+=(rust)
  fi
  if (( $+commands[starship] )); then
    # Starship lives in /usr/local/bin, so its installer asks for sudo; only run
    # it when GitHub has a newer release.
    print -P '\n%B==> starship%b'
    current=${${(z)"$(starship --version)"}[2]}
    latest=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
      | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
    if [[ -z $latest ]]; then
      print -u2 -- 'Could not check the latest Starship release.'
      failed+=(starship)
    elif [[ $current == $latest ]]; then
      print -- "starship $current is the latest release."
    else
      curl -fsSL https://starship.rs/install.sh | sh -s -- --yes || failed+=(starship)
    fi
  fi

  if (( ${#failed} )); then
    print -u2 -- "devup: failed: ${(j:, :)failed}"
    return 1
  fi
  print -P '\n%F{green}All developer tools are up to date.%f'
}

# PATH entries for tools installed outside dnf (zsh/.zshrc.local in the repository).
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
