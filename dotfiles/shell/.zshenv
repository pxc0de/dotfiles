for prefix in /opt/homebrew /usr/local; do
  [[ -x $prefix/bin/brew ]] && eval "$($prefix/bin/brew shellenv)" && break
done
typeset -U path
path+=(~/.local/bin ~/.cargo/bin ~/go/bin)
