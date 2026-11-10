typeset -U path
path=($HOMEBREW_PREFIX/opt/python/libexec/bin $HOMEBREW_PREFIX/opt/rustup/bin $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin $path ~/.local/bin ~/.cargo/bin)

export CLICOLOR=1

autoload -Uz compinit && compinit -u

alias ga="git add"
alias gc="git commit -m"
alias gs="git status"
alias gp="git push origin -u HEAD"
alias gpom="git pull origin main"
alias gdab="git branch --format='%(refname:short)' | grep -vx main | xargs git branch -D"

mac() { ssh "${MAC:?add MAC=<dev-name>@<other-mac> to ~/.zshrc.local}" "$@"; }

git_branch() {
  local branch
  branch=$(git branch --show-current 2>/dev/null)
  [[ -n $branch ]] && print -n " %F{#cba6f7}$branch%f"
}

ssh_host() {
  [[ -n $SSH_CONNECTION ]] && print -n "%F{#f38ba8}%m%f "
}

setopt PROMPT_SUBST
precmd() {
  echo
  [[ -n $SSH_CONNECTION ]] && print -Pn "\e]0;%m: %3~\a"
}
PROMPT='%B$(ssh_host)%F{#b4befe}🚀 %3~%f$(git_branch)
%F{#fab387}❯%f %b'

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

command -v fzf >/dev/null && source <(fzf --zsh)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
