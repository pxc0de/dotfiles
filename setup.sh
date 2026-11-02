#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo "setup.sh only supports macOS" >&2; exit 1; }

log() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
try() { "$@" || printf '\033[1;33mwarning:\033[0m %s failed, continuing\n' "$*" >&2; }

load_brew() {
    local prefix
    for prefix in /opt/homebrew /usr/local; do
        if [[ -x "$prefix/bin/brew" ]]; then
            eval "$("$prefix/bin/brew" shellenv)"
            return
        fi
    done
    return 1
}

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if ! load_brew; then
    log "Installing Homebrew and the Xcode Command Line Tools"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew
fi

if [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    [[ -d "$HOME/config/.git" ]] || git clone https://github.com/pxc0de/config.git "$HOME/config"
    exec bash "$HOME/config/setup.sh" </dev/tty
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "Installing and upgrading everything in the Brewfile"
try brew update
try brew bundle install --file "$REPO/Brewfile"
try brew upgrade --greedy

log "Linking dotfiles"
mkdir -p "$HOME/.config"
for package in "$REPO"/dotfiles/*/; do
    while IFS= read -r rel; do
        target="$HOME/$rel"
        if [[ -e "$target" || -L "$target" ]] && [[ "$(realpath "$target" 2>/dev/null)" != "$(realpath "$package$rel")" ]]; then
            log "Moving $target to $target.bak"
            mv "$target" "$target.bak"
        fi
    done < <(cd "$package" && find . -type f | sed 's|^\./||')
    stow -R -t "$HOME" -d "$REPO/dotfiles" "$(basename "$package")"
done

log "Installing and updating the Rust toolchain"
try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" default stable
try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" update

log "Installing and updating tmux plugins"
try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/install_plugins"
try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/update_plugins" all

log "Installing and updating Neovim plugins"
try nvim --headless "+Lazy! sync" +qa

log "Applying macOS defaults"
try bash "$REPO/macos.sh"

log "Done. Commit lazy-lock.json if it changed, and restart after the first run"
