#!/usr/bin/env bash
set -euo pipefail

readonly DEV_USER=pxc0de
readonly REPO_URL=https://github.com/pxc0de/dotfiles.git

[[ "$(uname -s)" == Darwin ]] || { echo "setup.sh only supports macOS" >&2; exit 1; }

log() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
try() { "$@" || printf '\033[1;33mwarning:\033[0m %s failed, continuing\n' "$*" >&2; }
is_admin() { [[ " $(id -Gn) " == *" admin "* ]]; }

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

if is_admin; then
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    if ! load_brew; then
        log "Installing Homebrew and the Xcode Command Line Tools"
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        load_brew
    fi
elif ! load_brew; then
    echo "Homebrew is missing. Run setup.sh from the admin account first." >&2
    exit 1
fi

if [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    [[ -d "$HOME/dotfiles/.git" ]] || git clone "$REPO_URL" "$HOME/dotfiles"
    exec bash "$HOME/dotfiles/setup.sh" </dev/tty
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

setup_admin() {
    if ! id "$DEV_USER" >/dev/null 2>&1; then
        log "Creating the standard user $DEV_USER. Enter a password for $DEV_USER, then your own"
        sudo sysadminctl -addUser "$DEV_USER" -fullName "$DEV_USER" -password - -adminUser "$(id -un)" -adminPassword -
    fi

    log "Installing and upgrading everything in the Brewfile"
    try brew update
    try brew bundle install --file "$REPO/Brewfile"
    try brew upgrade --greedy
}

setup_github_ssh() {
    local key="$HOME/.ssh/id_ed25519"
    mkdir -p -m 700 "$HOME/.ssh"

    gh auth status >/dev/null 2>&1 || gh auth login -h github.com -p ssh -s admin:public_key --skip-ssh-key -w

    if [[ ! -f "$key" ]]; then
        log "Creating an SSH key for GitHub. Keychain remembers its passphrase"
        ssh-keygen -t ed25519 -C "$(id -un)@$(scutil --get LocalHostName)" -f "$key"
        ssh-add --apple-use-keychain "$key"
    fi

    if [[ "$(gh ssh-key list 2>/dev/null)" != *"$(cut -d' ' -f2 "$key.pub")"* ]]; then
        gh ssh-key add "$key.pub" --title "$(scutil --get ComputerName)"
    fi

    if ! grep -qs '^github.com ' "$HOME/.ssh/known_hosts"; then
        gh api meta --jq '.ssh_keys[] | "github.com " + .' >>"$HOME/.ssh/known_hosts"
    fi

    git -C "$REPO" remote set-url origin git@github.com:pxc0de/dotfiles.git
}

link_dotfiles() {
    local package rel target
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
}

setup_dev() {
    log "Setting up GitHub access over SSH"
    setup_github_ssh

    link_dotfiles

    log "Installing and updating the Rust toolchain"
    try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" default stable
    try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" update

    log "Installing and updating tmux plugins"
    try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/install_plugins"
    try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/update_plugins" all

    log "Installing and updating Neovim plugins"
    try nvim --headless "+Lazy! sync" +qa
}

if is_admin; then
    setup_admin
else
    setup_dev
fi

log "Applying macOS defaults"
try bash "$REPO/macos.sh"

if is_admin; then
    log "Done. Log in as $DEV_USER and run the same setup command there"
else
    log "Done. Commit lazy-lock.json if it changed"
fi
