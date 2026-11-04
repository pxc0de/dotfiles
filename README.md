# dotfiles

One command sets up a Mac for coding, with tools, apps, editor, terminal and system settings. It works on Apple Silicon and Intel Macs.

The Mac gets separate accounts, so that code you run can't reach your personal data:

| Account | Kind | What it holds |
|---|---|---|
| admin | Administrator | Your Apple ID, saved passwords, cards and personal files. Owns Homebrew and the apps. |
| dev | Standard | Your code. Uses every installed tool, but can't change them or read the admin's files. |
| agent | Standard, optional | Long-running AI agents on one Mac, reached from your other Mac over SSH. No GitHub access and no personal data. |

You pick the account names. This README writes them as `<admin-name>`, `<dev-name>` and `<agent-name>`.

## Before you start

- **Running the command again is always safe.** It updates its own copy of this repo, then skips whatever is already done. If a step fails, fix the cause and run the same command again.
- **Read every password prompt before typing.** Several look alike, and each one names the account it wants. The steps below list them in order.
- **To share Terminal output, save it to a file** rather than taking a screenshot. Add `2>&1 | tee ~/Desktop/output.txt` to the end of any command. You still see everything and can still type passwords.
- **To move a file between your Macs, use AirDrop.** Universal Control and the shared clipboard need the same Apple ID on both Macs, and the dev and agent accounts have none. On the receiving account, open Control Center > AirDrop and choose Everyone for 10 Minutes. On the sending Mac, right-click the file and choose Share > AirDrop. The file lands in the receiver's Downloads folder.

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

   It's finished when it prints `Done. Log in to each standard account and run the same setup command there`. A yellow `warning:` line means one step failed and the rest still ran. Run the command again.

### 2. Dev account

1. Choose Apple menu > Log Out, and log in to the dev account. Its first login runs a short Setup Assistant. When it asks for an Apple ID, choose **Set Up Later**. Never sign this account in to iCloud or Google, because they would sync your saved passwords, cards and history into it.

2. Open Terminal and run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   It asks for these:
   1. **GitHub login.** It shows a one-time code. Press Enter to open GitHub in Safari. Sign in, using a passkey from your phone if you have one, and enter the code. If Safari offers to save your password, choose Never.
   2. **A passphrase for a new SSH key,** twice. Then once more, so Keychain remembers it and you won't be asked again.

   Then it links the dotfiles and installs the Rust toolchain and the tmux and Neovim plugins. It's finished when it prints `Done. Commit lazy-lock.json if it changed`.

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

Safari in the dev account should have no history.

Then in the admin account:

| Command | Expected |
|---|---|
| `ls -ld ~` | Starts with `drwx------` |
| `brew bundle check --file ~/dotfiles/Brewfile` | `The Brewfile's dependencies are satisfied.` |
| `ls /Library/Fonts \| grep -c JetBrains` | A number above 0 |
| `sudo fdesetup list` | Both the admin and the dev account |

After a restart, the FileVault screen shows both accounts, and either one unlocks the Mac.

## Agent host

Do this on the Mac that will run long-running agents. The other Mac connects to it, by SSH key only, as the agent account only, over [Tailscale](https://tailscale.com). Tailscale is a private network between your own devices that works from anywhere. These steps call the two Macs the host and the laptop.

### 1. Host admin account

Follow [New Mac](#new-mac) step 1, adding `AGENT_USER` to the command:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=<dev-name> AGENT_USER=<agent-name> bash
```

After the dev account, it creates the agent account, with one more `User password:` prompt for it. Then it limits SSH to that account, with keys only.

It prints `Remote Login is off`, because a script can't turn it on. Do it yourself:

1. Open System Settings > General > Sharing and turn on **Remote Login**.
2. Click ⓘ next to it.
3. Set **Allow access for** to Only these users. Select Administrators and click −. Click + and add the **agents** group.
4. Leave **Allow full disk access for remote users** off.

The `ssh <admin-name>@…` hint in that window won't work. That's intended.

Then set up the host's dev account as in [New Mac](#new-mac) step 2.

### 2. Key on the laptop

In the laptop's dev account, create a key used only for the host:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/agent_host
```

Press Enter at the passphrase prompt to leave it empty, or set one. Then show the public half in Finder, ready to AirDrop:

```bash
open -R ~/.ssh/agent_host.pub
```

Only ever send `agent_host.pub`. The file without `.pub` is the private key and stays on the laptop.

### 3. Host agent account

1. Log in to the agent account on the host. Choose Set Up Later for the Apple ID.
2. Open Control Center > AirDrop > Everyone for 10 Minutes. On the laptop, right-click `agent_host.pub` and choose Share > AirDrop, then pick the host. Accept it on the host.
3. In Terminal, copy the key, then run the setup:

   ```bash
   pbcopy < ~/Downloads/agent_host.pub
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   At `Public SSH key allowed to log in as <agent-name>:`, press ⌘V, then Enter. It links the shell, tmux and npm settings, and ends with `Done. Sign in to Tailscale if this Mac is not on your tailnet yet`.

4. Try it from the laptop over your home network first. Find the host's address under System Settings > General > Sharing > Remote Login on the host.

   ```bash
   ssh -i ~/.ssh/agent_host <agent-name>@<host-address> whoami
   ```

   The first time, type `yes` to trust the host. It should print `<agent-name>`.

### 4. Tailscale

1. On each Mac, log in to the admin account and open Tailscale from Applications. Allow the system extension and VPN configuration when macOS asks. Then sign in with the same Tailscale login on both Macs, using one protected by two-factor.
2. Tailscale keeps a separate sign-in for each account. Open it and sign in again in the laptop's dev account and in the host's agent account.
3. Open the [Tailscale admin console](https://login.tailscale.com/admin). Go to **Access controls**, replace everything with the contents of `tailscale.json`, and save. The console runs the tests in the file and refuses to save if one fails.
4. Go to **Machines**. For each Mac, open the ⋯ menu, choose Edit ACL tags, and add `tag:agent-host` to the host and `tag:laptop` to the laptop. The policy allows SSH from the laptop to the host and nothing else. Any other device on your tailnet loses access until you add rules for it.
5. The **Machines** page shows the host's name, for example `my-imac`. That's `<host>` from here on.

### 5. Connect

From the laptop's dev account:

```bash
ssh -i ~/.ssh/agent_host -t <agent-name>@<host> tmux new -A -s agents
```

This opens a tmux session called `agents` on the host. If one is already running, it reattaches to it. Detach with ctrl+a, then d. The agents keep running.

Never add `-A` to `ssh`. It would let the host use your laptop's keys.

### 6. Check it

From the laptop:

| Command | Expected |
|---|---|
| `ssh -i ~/.ssh/agent_host <agent-name>@<host> whoami` | `<agent-name>` |
| `ssh <dev-name>@<host>` | `Permission denied (publickey)` |
| `ssh -o PubkeyAuthentication=no <agent-name>@<host>` | `Permission denied`, with no password prompt |

Then log out of every account on the host except the agent account, and run the first command again. If it fails, Tailscale stopped when its account logged out.

## Day to day

Run the same command in each account whenever you want updates:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

| Account | What it does |
|---|---|
| admin | Installs anything new in the `Brewfile` and upgrades every tool and app. On the agent host, add `AGENT_USER=<agent-name>` before `bash`. |
| dev | Relinks the dotfiles and updates the Rust toolchain and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed. |
| agent | Relinks the shell, tmux and npm settings and updates the tmux plugins. |

Make changes to this repo from the dev account, then push them. The other accounts only pull. Nothing is ever uninstalled. If a dotfile was in the way of a link, it's moved aside to a `.bak` file, never deleted.

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
| `tailscale.json` | The Tailscale access policy for the agent host, with tests that block edits that would open more. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program, linked into the account's home folder. |

`dotfiles/npm/.npmrc` turns off npm install scripts, the usual way supply-chain attacks get in. Allow them for one install with `npm install --ignore-scripts=false`.

Settings for one Mac only, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
