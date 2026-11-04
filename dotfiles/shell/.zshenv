for prefix in /opt/homebrew /usr/local; do
  [[ -x $prefix/bin/brew ]] && eval "$($prefix/bin/brew shellenv)" && break
done

export TERMINFO_DIRS=/Applications/Ghostty.app/Contents/Resources/terminfo:
