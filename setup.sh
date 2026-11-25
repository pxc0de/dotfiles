#!/usr/bin/env bash
set -euo pipefail

readonly REPO_URL=https://github.com/pxc0de/dotfiles.git

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
    if [[ -d "$HOME/dotfiles/.git" ]]; then
        try git -C "$HOME/dotfiles" pull --ff-only
    else
        git clone "$REPO_URL" "$HOME/dotfiles"
    fi
    exec bash "$HOME/dotfiles/setup.sh" </dev/tty
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROLE_FILE="$HOME/.config/dotfiles/role"
SAVED_ROLE="$(cat "$ROLE_FILE" 2>/dev/null || true)"
ROLE=
until [[ "$ROLE" == main || "$ROLE" == headless ]]; do
    read -r -p "Is this Mac main or headless? [${SAVED_ROLE:-main/headless}] " ROLE
    ROLE="${ROLE:-$SAVED_ROLE}"
done
mkdir -p "$(dirname "$ROLE_FILE")"
echo "$ROLE" >"$ROLE_FILE"

setup_ssh_server() {
    local conf=/etc/ssh/sshd_config.d/000-keys-only.conf
    log "Allowing SSH logins with keys only"
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' | sudo tee "$conf" >/dev/null
    sudo ssh-keygen -A >/dev/null
    if ! sudo sshd -t; then
        sudo rm -f "$conf"
        echo "The SSH settings failed validation and were not applied" >&2
        exit 1
    fi
}

setup_firewall() {
    local fw=/usr/libexec/ApplicationFirewall/socketfilterfw
    log "Turning on the firewall and stealth mode"
    sudo "$fw" --setglobalstate on >/dev/null
    sudo "$fw" --setstealthmode on >/dev/null
}

setup_brew() {
    log "Installing and upgrading everything in the Brewfile"
    try brew update
    try brew bundle install --file "$REPO/Brewfile"
    try brew upgrade --greedy
}

create_ssh_key() {
    local key="$1" purpose="$2"
    mkdir -p -m 700 "$HOME/.ssh"
    [[ -f "$key" ]] && return
    log "Creating an SSH key for $purpose. Keychain remembers its passphrase"
    ssh-keygen -t ed25519 -C "$(id -un)@$(scutil --get LocalHostName)" -f "$key"
    ssh-add --apple-use-keychain "$key"
}

setup_github_ssh() {
    local key="$HOME/.ssh/id_ed25519"

    if ! gh auth status >/dev/null 2>&1; then
        gh auth login -h github.com -p ssh -s admin:public_key --skip-ssh-key -w
    elif [[ "$(gh auth status 2>&1)" != *admin:public_key* ]]; then
        gh auth refresh -h github.com -s admin:public_key
    fi

    create_ssh_key "$key" GitHub

    if [[ "$(gh ssh-key list 2>/dev/null)" != *"$(cut -d' ' -f2 "$key.pub")"* ]]; then
        gh ssh-key add "$key.pub" --title "$(scutil --get ComputerName)"
    fi

    if ! grep -qs '^github.com ' "$HOME/.ssh/known_hosts"; then
        gh api meta --jq '.ssh_keys[] | "github.com " + .' >>"$HOME/.ssh/known_hosts"
    fi

    local origin
    origin="$(git -C "$REPO" remote get-url origin)"
    if [[ "$origin" =~ ^https://github\.com/(.+)$ ]]; then
        git -C "$REPO" remote set-url origin "git@github.com:${BASH_REMATCH[1]%.git}.git"
    fi
}

setup_github_token() {
    local token
    while ! gh auth status >/dev/null 2>&1; do
        log "Paste a fine-grained GitHub token, made as the README describes"
        read -r -s -p "Token: " token
        echo
        [[ -n "$token" ]] && printf '%s\n' "$token" | gh auth login -h github.com --with-token
    done
    gh config set -h github.com git_protocol https
    GIT_CONFIG_GLOBAL="$HOME/.gitconfig" gh auth setup-git -h github.com
}

link_dotfiles() {
    local dir rel target
    log "Linking dotfiles"
    mkdir -p "$HOME/.config"
    mkdir -p -m 700 "$HOME/.ssh"
    for dir in "$REPO"/dotfiles/*/; do
        while IFS= read -r rel; do
            target="$HOME/$rel"
            if [[ -e "$target" || -L "$target" ]] && [[ "$(realpath "$target" 2>/dev/null)" != "$(realpath "$dir$rel")" ]]; then
                log "Moving $target to $target.bak"
                mv "$target" "$target.bak"
            fi
        done < <(cd "$dir" && find . -type f | sed 's|^\./||')
        stow -R -t "$HOME" -d "$REPO/dotfiles" "$(basename "$dir")"
    done
}

install_ghostty_terminfo() {
    TERMINFO=/Applications/Ghostty.app/Contents/Resources/terminfo infocmp -x xterm-ghostty |
        tic -x -o "$HOME/.terminfo" - 2>/dev/null
}

setup_headless() {
    log "Setting up GitHub access with a fine-grained token"
    setup_github_token

    log "Installing Ghostty's terminfo for SSH sessions from the main Mac"
    try install_ghostty_terminfo

    log "Keeping the Mac awake and restarting it after a power failure"
    try sudo pmset -a sleep 0 disksleep 0 autorestart 1
}

setup_main() {
    log "Setting up GitHub access over SSH"
    setup_github_ssh

    create_ssh_key "$HOME/.ssh/mac" "SSH into the headless Mac"
}

setup_user() {
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

setup_ssh_server
try setup_firewall
setup_brew
if [[ "$ROLE" == headless ]]; then
    setup_headless
else
    setup_main
fi
setup_user

log "Applying macOS defaults"
try bash "$REPO/macos.sh"

log "Done. Log out and back in so every setting takes effect. Commit lazy-lock.json if it changed"
