# dotfiles

One command sets up a Mac for coding: tools, apps, editor, terminal and system settings. Works on Apple Silicon and Intel.

Each Mac gets two accounts, so code you run can't reach your personal data:

| Account | Kind | Apple ID | Holds |
|---|---|---|---|
| admin | Administrator | Personal | Passwords, cards, personal files. Owns Homebrew and the apps. |
| dev | Standard | A separate dev one with nothing personal in it | Code. Uses every installed tool but can't change them or read admin's files. |

`<admin-name>` and `<dev-name>` below are the account names you choose. Any further accounts, such as one for AI agents, are set up by hand. Running the setup in another standard account makes it a dev account with access to your GitHub.

The setup is safe to rerun. It updates its copy of this repo and skips whatever is already done. A yellow `warning:` line means one step failed and the rest still ran.

## New Mac

### 1. Admin account

1. In Setup Assistant, create the admin account, sign in to your personal Apple ID and leave FileVault on.
2. In Terminal, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=<dev-name> bash
   ```

   It asks for `Password:` (your admin password), then `User password:` (a new password for the dev account). Without `DEV_USER`, it asks for the name first. Homebrew asks for the admin password again before apps with an installer, such as Tailscale.

   It installs the Xcode Command Line Tools, Homebrew and the `Brewfile`, creates the dev account, makes SSH keys-only and applies `macos.sh`.
3. Log out.

### 2. Dev account

1. Log in to the dev account and sign in to the dev Apple ID. Never sign in to your personal Apple ID or Google account here, because they would sync your passwords, cards and history.
2. In Terminal, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   It signs in to GitHub with a one-time code in Safari, then asks for a passphrase for a new SSH key, which Keychain remembers. It links the dotfiles, installs the Rust toolchain and the tmux and Neovim plugins, and applies `macos.sh`.
3. Restart the Mac.

### 3. Check it

In the dev account, in Ghostty:

| Command | Expected |
|---|---|
| `ssh -T git@github.com` | `Hi <github-user>! You've successfully authenticated` |
| `git -C ~/dotfiles remote get-url origin` | Starts with `git@github.com:` |
| `which nvim node python cargo claude` | All under `/opt/homebrew`, or `/usr/local` on Intel |
| `npm config get ignore-scripts` | `true` |
| `ls /Users/<admin-name>` | `Permission denied` |
| `touch "$(brew --prefix)/bin/test"` | `Permission denied` |
| `sudo true` | Refused |

In the admin account:

| Command | Expected |
|---|---|
| `ls -ld ~` | Starts with `drwx------` |
| `brew bundle check --file ~/dotfiles/Brewfile` | `The Brewfile's dependencies are satisfied.` |
| `sudo fdesetup list` | Both accounts |

## SSH into the desktop

The laptop and phone reach the desktop's dev account over [Tailscale](https://tailscale.com), by key only. The admin account can't be reached over SSH.

### 1. Remote Login

On the desktop, as admin, open System Settings > General > Sharing and turn on **Remote Login**. Under ⓘ, set **Allow access for** to Only these users, remove Administrators and add the dev account. Leave full disk access off.

### 2. Keys

On the laptop, as dev:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/desktop
```

On the phone, create an ed25519 key in an SSH app such as Blink Shell or Termius.

AirDrop both public keys to the desktop's dev account. The phone has a different Apple ID, so first set AirDrop on the desktop to Everyone for 10 Minutes in Control Center. Send only the public key. Then, on the desktop as dev:

```bash
cat ~/Downloads/desktop.pub ~/Downloads/<phone-key>.pub >> ~/.ssh/authorized_keys
```

### 3. Tailscale

1. Sign in to Tailscale with one login, protected by two-factor, in every account on both Macs and on the phone. Each macOS account signs in separately.
2. In the [admin console](https://login.tailscale.com/admin), replace **Access controls** with `tailscale.json`. The console refuses to save if its tests fail.
3. Under **Machines**, tag each device `tag:desktop`, `tag:laptop` or `tag:phone`. Only the laptop and phone can reach the desktop, on port 22. Untagged devices lose access.

The desktop's machine name, such as `my-imac`, is `<host>` below.

### 4. Connect

On the laptop, as dev:

```bash
echo 'DESKTOP=<dev-name>@<host>' >> ~/.zshrc.local
```

In a new shell, `desk` opens or reattaches the tmux session `main` on the desktop. Detach with ctrl+a, d. `desk <command>` runs one command instead.

On the phone, add `<host>` with user `<dev-name>` and your key, and run `tmux new -A -s main` on connect.

Never use `ssh -A`. It would let the desktop use your laptop's keys.

### 5. Check it

From the laptop:

| Command | Expected |
|---|---|
| `desk whoami` | `<dev-name>` |
| `ssh <admin-name>@<host>` | `Permission denied (publickey)` |
| `ssh -o PubkeyAuthentication=no <dev-name>@<host>` | `Permission denied`, with no password prompt |

Log out of admin on the desktop and run `desk whoami` again. If it fails, Tailscale stopped with the admin session.

## Updates

Run the setup again in each account:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

Admin installs new `Brewfile` entries and upgrades everything. Dev relinks the dotfiles and updates Rust and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed.

Edit this repo from the dev account. Admin only pulls. Nothing is uninstalled. A file in the way of a link moves to `.bak`.

## Forking

Change `REPO_URL` in `setup.sh`, the `curl` URLs here, your name and email in `dotfiles/git/.config/git/config`, and the `Brewfile`.

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Tools and apps. Fonts install for all accounts. |
| `setup.sh` | Setup for whichever account runs it. |
| `macos.sh` | Per-account system settings, including a private home folder. |
| `tailscale.json` | Tailscale policy for SSH into the desktop, with tests. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program. |

`dotfiles/npm/.npmrc` turns off npm install scripts. Allow them for one install with `npm install --ignore-scripts=false`.

Per-Mac settings, such as private aliases, go in `~/.zshrc.local`, which isn't in the repo.
