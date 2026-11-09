# dotfiles

One command sets up a Mac for coding, with tools, apps, editor, terminal and system settings. It works on Apple Silicon and Intel Macs.

The Mac gets two accounts, so that code you run can't reach your personal data:

| Account | Kind | Apple ID | What it holds |
|---|---|---|---|
| admin | Administrator | Your personal one | Your saved passwords, cards and personal files. Owns Homebrew and the apps. |
| dev | Standard | A separate dev one with nothing personal in it | Your code. Uses every installed tool, but can't change them or read the admin's files. |

You pick the account names. This README writes them as `<admin-name>` and `<dev-name>`.

One Mac can be a desktop that you reach over SSH from your laptop and phone. See [SSH into the desktop](#ssh-into-the-desktop).

If you add more accounts later, such as one for AI agents, set them up by hand. Running the setup in another standard account sets it up as a dev account, with access to your GitHub.

## Before you start

- **Running the command again is always safe.** It updates its own copy of this repo, then skips whatever is already done. If a step fails, fix the cause and run the same command again.
- **Read every password prompt before typing.** Several look alike, and each one names the account it wants. The steps below list them in order.
- **To share Terminal output, save it to a file** rather than taking a screenshot. Add `2>&1 | tee ~/Desktop/output.txt` to the end of any command. You still see everything and can still type passwords.
- **To move a file between devices, use AirDrop.** Between two dev accounts it just works, because they share the dev Apple ID. That Apple ID also gives them a shared clipboard. From a device with a different Apple ID, such as your phone, the receiving account first opens Control Center > AirDrop and chooses Everyone for 10 Minutes. The file lands in the receiver's Downloads folder.

## New Mac

### 1. Admin account

1. Erase the Mac, or start from a new one. In Setup Assistant, create the admin account and sign in to your Apple ID. Leave FileVault on.

   Safari may already show your history. It came back from iCloud, not from before the erase. If you don't want it on this Mac, turn Safari off under System Settings > your name > iCloud.

2. Open Terminal (press ⌘Space, type Terminal, press Enter) and run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=<dev-name> bash
   ```

   It asks for these, in order:
   1. `Password:` is your admin password.
   2. `User password:` is a new password for the dev account. You type it at login and at the FileVault screen after a restart.

   If you leave out `DEV_USER=<dev-name>`, it asks for the name first.

   The rest takes a while the first time. It installs the Xcode Command Line Tools, Homebrew and everything in the `Brewfile`, creates the dev account, and applies the system settings in `macos.sh`. Along the way:
   - Homebrew asks for your admin password again before apps that use an installer, such as Tailscale and NordVPN. That's normal.
   - Approve any macOS permission dialog that appears.

   It's finished when it prints `Done. Log out and back in so every setting takes effect, then run the same setup command in the dev account`. A yellow `warning:` line means one step failed and the rest still ran. Run the command again.

### 2. Dev account

1. Choose Apple menu > Log Out, and log in to the dev account. Its first login runs a short Setup Assistant. When it asks for an Apple ID, sign in with the dev Apple ID. Never sign this account in to your personal Apple ID or Google account, because they would sync your saved passwords, cards and history into it.

2. Open Terminal and run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   It asks for these:
   1. **GitHub login.** It shows a one-time code. Press Enter to open GitHub in Safari. Sign in, using a passkey from your phone if you have one, and enter the code. If Safari offers to save your password, choose Never.
   2. **A passphrase for a new SSH key,** twice. Then once more, so Keychain remembers it and you won't be asked again.

   Then it links the dotfiles, installs the Rust toolchain and the tmux and Neovim plugins, and applies the same system settings as the admin account. It's finished when it prints `Done. Log out and back in so every setting takes effect. Commit lazy-lock.json if it changed`.

3. Restart the Mac.

### 3. Check it

In the dev account, open Ghostty from Applications. The first time, macOS asks whether to open an app downloaded from the internet. Click Open. The prompt should show a rocket and the current folder, with no empty boxes. Then run each command:

| Command | Expected |
|---|---|
| `ssh -T git@github.com` | `Hi <github-user>! You've successfully authenticated` |
| `git -C ~/dotfiles remote get-url origin` | Starts with `git@github.com:` |
| `git config user.email` | The email in `dotfiles/git/.config/git/config` |
| `which nvim node python cargo claude` | All under `/opt/homebrew` on Apple Silicon, or `/usr/local` on Intel |
| `npm config get ignore-scripts` | `true` |
| `ls /Users/<admin-name>` | `Permission denied` |
| `touch "$(brew --prefix)/bin/test"` | `Permission denied` |
| `sudo true` | Refused, because the dev account is not an administrator |
| `nvim ~/dotfiles/setup.sh` | Opens in colour with no errors. The first launch installs language servers in the background. Quit with `:q`. |
| `tmux` | A coloured status bar at the bottom. Leave with `exit`. |

Safari in the dev account should have none of your personal history.

Then in the admin account:

| Command | Expected |
|---|---|
| `ls -ld ~` | Starts with `drwx------` |
| `brew bundle check --file ~/dotfiles/Brewfile` | `The Brewfile's dependencies are satisfied.` |
| `ls /Library/Fonts \| grep -c JetBrains` | A number above 0 |
| `sudo fdesetup list` | Both the admin and the dev account |

After a restart, the FileVault screen shows both accounts, and either one unlocks the Mac.

## SSH into the desktop

Do this to reach the desktop's dev account from your laptop and phone, from anywhere. They connect over [Tailscale](https://tailscale.com), a private network between your own devices, by SSH key only. Nothing can log in to the admin account over SSH.

### 1. Desktop admin account

Set up the desktop as in [New Mac](#new-mac). The admin setup already made SSH accept keys only. Turn SSH on yourself, because a script can't:

1. Open System Settings > General > Sharing and turn on **Remote Login**.
2. Click ⓘ next to it.
3. Set **Allow access for** to Only these users. Select Administrators and click −. Click + and add the dev account.
4. Leave **Allow full disk access for remote users** off.

The `ssh <admin-name>@…` hint in that window won't work. That's intended.

### 2. Keys

In the laptop's dev account, create a key used only for the desktop, then show its public half in Finder:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/desktop
open -R ~/.ssh/desktop.pub
```

On the phone, install an SSH app such as Blink Shell or Termius, create an ed25519 key in it, and export the public key.

AirDrop both public keys to the desktop's dev account. Only ever send the public key. On a Mac it's the file ending in `.pub`. The private half stays on the device that made it. Then, in the desktop's dev account, add each one:

```bash
cat ~/Downloads/desktop.pub >> ~/.ssh/authorized_keys
```

Do the same with the file from the phone.

Try it from the laptop over your home network first. Find the desktop's address under System Settings > General > Sharing > Remote Login on the desktop.

```bash
ssh -i ~/.ssh/desktop <dev-name>@<desktop-address> whoami
```

The first time, type `yes` to trust the desktop. It should print `<dev-name>`.

### 3. Tailscale

1. On each Mac, log in to the admin account and open Tailscale from Applications. Allow the system extension and VPN configuration when macOS asks. Then sign in with one Tailscale login protected by two-factor.
2. Tailscale keeps a separate sign-in for each account. Sign in again with the same login in each dev account.
3. Install Tailscale on the phone from the App Store and sign in with the same login.
4. Open the [Tailscale admin console](https://login.tailscale.com/admin). Go to **Access controls**, replace everything with the contents of `tailscale.json`, and save. The console runs the tests in the file and refuses to save if one fails.
5. Go to **Machines**. For each device, open the ⋯ menu, choose Edit ACL tags, and add `tag:desktop`, `tag:laptop` or `tag:phone`. The policy allows SSH from the laptop and the phone to the desktop and nothing else. Any other device on your tailnet loses access until you add rules for it.
6. The **Machines** page shows the desktop's name, for example `my-imac`. That's `<host>` from here on.

### 4. Connect

In the laptop's dev account, tell the shell where the desktop is, then open a new Ghostty window:

```bash
echo 'DESKTOP=<dev-name>@<host>' >> ~/.zshrc.local
```

Now `desk` opens a tmux session called `main` on the desktop. If one is already running, it reattaches to it. Detach with ctrl+a, then d, and whatever runs there keeps running. `desk <command>` runs one command there instead, as in `desk whoami`.

On the phone, add a host in the SSH app with `<host>` as the address, `<dev-name>` as the user and the key you made. Set it to run `tmux new -A -s main` on connect to share the same session.

Never add `-A` to `ssh`. It would let the desktop use your laptop's keys.

### 5. Check it

From the laptop:

| Command | Expected |
|---|---|
| `desk whoami` | `<dev-name>` |
| `ssh <admin-name>@<host>` | `Permission denied (publickey)` |
| `ssh -o PubkeyAuthentication=no <dev-name>@<host>` | `Permission denied`, with no password prompt |

Then log out of the admin account on the desktop, leaving only the dev account logged in, and run `desk whoami` again. If it fails, Tailscale stopped when the admin account logged out.

## Day to day

Run the same command in each account whenever you want updates:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

| Account | What it does |
|---|---|
| admin | Installs anything new in the `Brewfile` and upgrades every tool and app. |
| dev | Relinks the dotfiles and updates the Rust toolchain and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed. |

Make changes to this repo from the dev account, then push them. The admin account only pulls. Nothing is ever uninstalled. If a dotfile was in the way of a link, it's moved aside to a `.bak` file, never deleted.

## Using it yourself

Fork the repo, then change these before you run it:

| File | Change |
|---|---|
| `setup.sh` | `REPO_URL` on line 4, to your fork. |
| `README.md` | The `curl` URLs, to your fork. |
| `dotfiles/git/.config/git/config` | Your git name and email. |
| `Brewfile` | The tools and apps you want. |

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Every installed tool and app. Fonts install for all accounts. |
| `setup.sh` | The setup for whichever account runs it. |
| `macos.sh` | Per-account system settings, including a home folder only its owner can open. |
| `tailscale.json` | The Tailscale access policy for SSH into the desktop, with tests that block edits that would open more. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program, linked into the account's home folder. |

`dotfiles/npm/.npmrc` turns off npm install scripts, the usual way supply-chain attacks get in. Allow them for one install with `npm install --ignore-scripts=false`.

Settings for one Mac only, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
