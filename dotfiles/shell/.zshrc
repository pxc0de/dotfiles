for prefix in /opt/homebrew /usr/local; do
  [[ -x $prefix/bin/brew ]] && eval "$($prefix/bin/brew shellenv)" && break
done

typeset -U path
path=(~/.local/bin $path ~/.cargo/bin)

export CLICOLOR=1

autoload -Uz compinit && compinit

alias ga="git add"
alias gc="git commit -m"
alias gs="git status"
alias gp="git push origin -u HEAD"
alias gpom="git pull origin main"
alias gdab="git branch --format='%(refname:short)' | grep -vx main | xargs git branch -D"

git_branch() {
  local branch
  branch=$(git branch --show-current 2>/dev/null)
  [[ -n $branch ]] && print -n " %F{#cba6f7}$branch%f"
}

setopt PROMPT_SUBST
precmd() { echo }
PROMPT='%B%F{#b4befe}🚀 %3~%f$(git_branch)
%F{#fab387}❯%f %b'

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

command -v fzf >/dev/null && source <(fzf --zsh)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
