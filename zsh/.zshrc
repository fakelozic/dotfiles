export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="gruvbox"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"

export EDITOR=nvim
export VISUAL=nvim

alias ls='eza --icons --group-directories-first'
alias ll='eza -lahg --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --icons --group-directories-first --level=2'
alias cat='bat --paging=never'
alias rgf='rg --files'
alias refresh='source ~/.zshrc'

# Machine-specific PATH entries and toolchain managers stay out of the repository.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
