#!/usr/bin/env bash
set -euo pipefail

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

has_standard_user() {
    local user
    for user in $(dscl . -list /Users UniqueID | awk '$2 >= 501 { print $1 }'); do
        dseditgroup -o checkmember -m "$user" admin >/dev/null 2>&1 || return 0
    done
    return 1
}

is_agent() { dseditgroup -o checkmember -m "$(id -un)" agents >/dev/null 2>&1; }

create_standard_user() {
    if ! id "$1" >/dev/null 2>&1; then
        log "Creating the standard user $1. Enter a new password for $1"
        sudo sysadminctl -addUser "$1" -fullName "$1" -password -
    fi
    if sysadminctl -secureTokenStatus "$1" 2>&1 | grep -q DISABLED; then
        log "Letting $1 unlock FileVault. Enter your own password, then the password of $1"
        sudo sysadminctl -secureTokenOn "$1" -password - -adminUser "$(id -un)" -adminPassword -
    fi
}

create_dev_user() {
    local name="${DEV_USER:-}"
    if [[ -z "$name" ]]; then
        has_standard_user && return
        read -r -p "Name for the standard dev account: " name
        [[ -n "$name" ]] || { echo "No account name given" >&2; exit 1; }
    fi
    create_standard_user "$name"
}

setup_agent_host() {
    local conf=/etc/ssh/sshd_config.d/000-agents.conf
    create_standard_user "$AGENT_USER"

    log "Allowing only the agents group to log in over SSH, with keys only"
    dscl . -read /Groups/agents >/dev/null 2>&1 || sudo dseditgroup -o create agents
    dseditgroup -o checkmember -m "$AGENT_USER" agents >/dev/null 2>&1 || sudo dseditgroup -o edit -a "$AGENT_USER" -t user agents
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nAllowGroups agents\n' | sudo tee "$conf" >/dev/null
    sudo ssh-keygen -A >/dev/null
    if ! sudo sshd -t; then
        sudo rm -f "$conf"
        echo "The SSH settings failed validation and were not applied" >&2
        exit 1
    fi

    nc -z 127.0.0.1 22 2>/dev/null || log "Remote Login is off. Turn it on in System Settings > General > Sharing so other Macs can reach $AGENT_USER over SSH"
}

setup_admin() {
    create_dev_user
    [[ -z "${AGENT_USER:-}" ]] || setup_agent_host

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

    local origin
    origin="$(git -C "$REPO" remote get-url origin)"
    if [[ "$origin" =~ ^https://github\.com/(.+)$ ]]; then
        git -C "$REPO" remote set-url origin "git@github.com:${BASH_REMATCH[1]%.git}.git"
    fi
}

link_dotfiles() {
    local package dir rel target
    log "Linking dotfiles"
    mkdir -p "$HOME/.config"
    for package in ${@:-$(ls "$REPO/dotfiles")}; do
        dir="$REPO/dotfiles/$package/"
        while IFS= read -r rel; do
            target="$HOME/$rel"
            if [[ -e "$target" || -L "$target" ]] && [[ "$(realpath "$target" 2>/dev/null)" != "$(realpath "$dir$rel")" ]]; then
                log "Moving $target to $target.bak"
                mv "$target" "$target.bak"
            fi
        done < <(cd "$dir" && find . -type f | sed 's|^\./||')
        stow -R -t "$HOME" -d "$REPO/dotfiles" "$package"
    done
}

update_tmux_plugins() {
    log "Installing and updating tmux plugins"
    try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/install_plugins"
    try "$HOMEBREW_PREFIX/opt/tpm/share/tpm/bin/update_plugins" all
}

setup_dev() {
    log "Setting up GitHub access over SSH"
    setup_github_ssh

    link_dotfiles

    log "Installing and updating the Rust toolchain"
    try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" default stable
    try "$HOMEBREW_PREFIX/opt/rustup/bin/rustup" update

    update_tmux_plugins

    log "Installing and updating Neovim plugins"
    try nvim --headless "+Lazy! sync" +qa
}

setup_agent() {
    local key
    mkdir -p -m 700 "$HOME/.ssh"
    if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
        read -r -p "Public SSH key allowed to log in as $(id -un): " key
        printf '%s\n' "$key" | ssh-keygen -lf - >/dev/null 2>&1 || { echo "That is not a valid public SSH key" >&2; exit 1; }
        printf '%s\n' "$key" >"$HOME/.ssh/authorized_keys"
        chmod 600 "$HOME/.ssh/authorized_keys"
    fi

    link_dotfiles shell tmux npm
    update_tmux_plugins
}

if is_admin; then
    setup_admin
elif is_agent; then
    setup_agent
else
    setup_dev
fi

log "Applying macOS defaults"
try bash "$REPO/macos.sh"

if is_admin; then
    log "Done. Log in to each standard account and run the same setup command there"
elif is_agent; then
    log "Done. Sign in to Tailscale if this Mac is not on your tailnet yet"
else
    log "Done. Commit lazy-lock.json if it changed"
fi
