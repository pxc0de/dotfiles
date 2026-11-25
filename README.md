# dotfiles

One command sets up a Mac for coding: tools, apps, editor, terminal and system settings. Works on Apple Silicon and Intel.

Each Mac has one account, the administrator created in Setup Assistant, and one of two roles:

| Role | Mac | Runs | GitHub access | SSH |
|---|---|---|---|---|
| `main` | Your laptop | You, and your personal data | Your account, with an SSH key | Connects to the headless Mac, accepts nothing |
| `headless` | An iMac or Mac mini | Always-on AI agents | Your account, with an SSH key | Accepts logins from the main Mac |

Agents run as you and have full access to your GitHub account. On the headless Mac, nothing can sign in to the main Mac or reach it over Tailscale, so a misbehaving agent there stays on that Mac. It still reaches the internet as normal.

The setup doesn't cover fine-grained personal access tokens. Use one on the headless Mac instead of your account's SSH key if you want agents to:

- reach only the repos you choose, not every repo you own
- have only the permissions you choose, such as Contents and Pull requests, and never delete repos, change their settings or add SSH keys and tokens to your account
- lose access on a set date, when the token expires

To switch after the setup, create the token at [Settings > Developer settings > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new), then on the headless Mac:

```bash
gh auth logout -h github.com
gh auth login -h github.com --with-token   # paste the token, press Return, then Control-D
gh config set -h github.com git_protocol https
GIT_CONFIG_GLOBAL=~/.gitconfig gh auth setup-git -h github.com
git -C ~/dotfiles remote set-url origin https://github.com/pxc0de/dotfiles.git
```

Then delete the headless Mac's key under [Settings > SSH and GPG keys](https://github.com/settings/keys), and `~/.ssh/id_ed25519` on that Mac. `GIT_CONFIG_GLOBAL` keeps git's credential setting out of this repo's tracked git config. Rerunning the setup undoes the switch: it signs `gh` in to your account again and adds a new SSH key.

The setup is safe to rerun. It updates its copy of this repo and skips whatever is already done. A yellow `warning:` line means one step failed and the rest still ran.

## New Macs

Set up the two Macs in either order, then Tailscale and SSH, which need both.

### 1. Main Mac

1. In Setup Assistant, create your account, sign in to your Apple ID and leave FileVault on.
2. In Safari, sign in to GitHub.
3. In Terminal, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   Answer its questions:

   | Prompt | Answer |
   |---|---|
   | `Password:` | Your account password |
   | `Is this Mac main or headless?` | `main` |
   | GitHub one-time code | Press Return, then enter the code in Safari and authorize |
   | Two passphrases, one per SSH key | New passphrases. Keychain remembers them. |

   It installs the Xcode Command Line Tools, Homebrew and the `Brewfile`, makes SSH keys-only and turns on the firewall. It makes an SSH key for GitHub and adds it to your account, and `~/.ssh/mac` for logging in to the headless Mac. It then links the dotfiles, installs the Rust toolchain and the tmux and Neovim plugins, and applies `macos.sh`. If macOS later asks whether an app may accept incoming connections, choose Deny.
4. Restart the Mac.
5. Open Ghostty and check:

   | Command | Expected |
   |---|---|
   | `ssh -T git@github.com` | `Hi <github-user>! You've successfully authenticated` |
   | `git -C ~/dotfiles remote get-url origin` | Starts with `git@github.com:` |
   | `ls ~/.ssh` | Includes `id_ed25519` and `mac` |

   Then run the [checks for both Macs](#checks-for-both-macs).

### 2. Headless Mac

1. In Setup Assistant, create your account, sign in to your Apple ID and leave FileVault on.
2. In Safari, sign in to GitHub.
3. In Terminal, run the same command:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   Answer its questions:

   | Prompt | Answer |
   |---|---|
   | `Password:` | Your account password |
   | `Is this Mac main or headless?` | `headless` |
   | GitHub one-time code | Press Return, then enter the code in Safari and authorize |
   | One passphrase, for the GitHub SSH key | A new passphrase. Keychain remembers it. |

   It installs and configures the same things as on the main Mac, without the `~/.ssh/mac` key, since the headless Mac never logs in to the main Mac. It also installs Ghostty's terminfo for SSH sessions from the main Mac, keeps the Mac awake and turns it back on after a power failure.
4. Restart the Mac.
5. Open Ghostty and check:

   | Command | Expected |
   |---|---|
   | `ssh -T git@github.com` | `Hi <github-user>! You've successfully authenticated` |
   | `git -C ~/dotfiles remote get-url origin` | Starts with `git@github.com:` |
   | `pmset -g \| grep -E '^ *(sleep\|autorestart)'` | `sleep 0` and `autorestart 1` |
   | `ls -ld ~/.ssh` | Starts with `drwx------`, not `l` |
   | `ls ~/.ssh` | Includes `id_ed25519`, but no `mac` |
   | `id -un` | Your account name, which is `<user>` below |

   Then run the [checks for both Macs](#checks-for-both-macs).

### 3. Tailscale

1. Install [Tailscale](https://tailscale.com/download/mac) on both Macs, and on your phone if you want to open dev servers from it. Sign in on each with the same login, protected by two-factor.
2. On the main Mac, run `pbcopy < ~/dotfiles/tailscale.json`. In the [admin console](https://login.tailscale.com/admin/acls), select everything under **Access controls**, paste over it and save. The console refuses to save if the policy's tests fail.
3. Under [**Machines**](https://login.tailscale.com/admin/machines), open each device's ⋯ menu, choose **Edit ACL tags** and add one tag: `tag:main` for the main Mac, `tag:headless` for the headless Mac and `tag:phone` for your phone. Untagged devices lose access.
4. The headless Mac's name in that list, such as `my-imac`, is `<headless-mac>` below.

The main Mac can reach the headless Mac. The phone reaches the headless Mac's web ports but not SSH. The headless Mac can't start a connection to any of them. Don't add a `funnel` attribute to the policy: without one, nothing on the headless Mac can share a port with the public internet.

### 4. SSH from the main Mac to the headless Mac

1. On the headless Mac, open System Settings > General > Sharing and turn on **Remote Login**. Under ⓘ, set **Allow access for** to Only these users, remove Administrators and add your account. Leave full disk access off. On the main Mac, leave Remote Login off.
2. On the main Mac, copy its public key:

   ```bash
   pbcopy < ~/.ssh/mac.pub
   ```
3. On the headless Mac, add it:

   ```bash
   pbpaste >> ~/.ssh/authorized_keys
   ```

   If pasting doesn't work, turn on Handoff and Bluetooth on both Macs, or AirDrop `mac.pub` and run `cat ~/Downloads/mac.pub >> ~/.ssh/authorized_keys` instead. Copy only the `.pub` file, and never add a key from the headless Mac to the main Mac.
4. On the main Mac, point `mac` at the headless Mac, then open a new Ghostty tab:

   ```bash
   echo 'MAC=<user>@<headless-mac>' >> ~/.zshrc.local
   ```
5. From the main Mac, check:

   | Command | Expected |
   |---|---|
   | `mac whoami` | `<user>`, after you type `yes` to accept the host key the first time |
   | `ssh -o PubkeyAuthentication=no <user>@<headless-mac>` | `Permission denied`, with no password prompt |
6. Restart the headless Mac and run `mac whoami` again once it's back. FileVault waits for your password at the login screen, and Tailscale may not run until you log in. If it doesn't connect, log in at the headless Mac's keyboard; it will need that after every restart.

### Checks for both Macs

In Ghostty:

| Command | Expected |
|---|---|
| `which nvim node python cargo` | All under `/opt/homebrew`, or `/usr/local` on Intel |
| `npm config get ignore-scripts` | `true` |
| `ls -ld ~` | Starts with `drwx------` |
| `brew bundle check --file ~/dotfiles/Brewfile` | `The Brewfile's dependencies are satisfied.` |
| `sudo fdesetup list` | Your account |
| `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | `Firewall is enabled` |

## Daily use

`mac` opens a shell on the headless Mac and `mac <command>` runs one command there:

```bash
mac                          # open a shell
mac whoami                   # run one command
mac -t tmux new -A -s main   # attach to the main session, creating it if needed
mac -t tmux attach           # attach to the most recent session
mac -t tmux attach -t work   # attach to a named session
mac tmux ls                  # list sessions
```

tmux needs `-t`, which gives the command a terminal. Detach with `prefix d` and the session keeps running. Run agents inside tmux so they keep running after you disconnect. Never use `ssh -A`. It would let the headless Mac use your keys.

The firewall blocks other devices from reaching servers you run, such as `npm run dev`. To open one from the main Mac or your phone, keep it on localhost and share it over the tailnet, on the headless Mac:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg 3000   # https://<headless-mac>.<tailnet>.ts.net
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve reset       # stop sharing
```

## Updates

Run the setup again on each Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

It asks for your password and offers the saved role from `~/.config/dotfiles/role`; press Return to keep it. It installs new `Brewfile` entries, upgrades everything, relinks the dotfiles and updates Rust and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed.

A file in the way of a link moves to `.bak`.

Nothing is uninstalled, even after you remove it from the `Brewfile`. To remove one app or tool, run `brew uninstall --cask <app>` or `brew uninstall <tool>` on each Mac. To remove everything that isn't in the `Brewfile`, preview the list first:

```bash
brew bundle cleanup --file ~/dotfiles/Brewfile          # lists what would be removed
brew bundle cleanup --file ~/dotfiles/Brewfile --force  # removes it
```

`cleanup` also removes anything you installed with `brew install` but never added to the `Brewfile`. It leaves apps from the App Store or a downloaded installer alone, because Homebrew doesn't manage them.

## Forking

Change `REPO_URL` in `setup.sh`, the `curl` URLs here, your name and email in `dotfiles/git/.config/git/config`, and the `Brewfile`.

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Tools and apps. |
| `setup.sh` | The whole setup, for either role. |
| `macos.sh` | System settings, including a private home folder. |
| `tailscale.json` | Tailscale policy letting the main Mac reach the headless Mac, with tests. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program. |

`dotfiles/npm/.npmrc` turns off npm install scripts. Allow them for one install with `npm install --ignore-scripts=false`.

To try a tool without adding it to the `Brewfile`, install it in your home folder: `uv tool install`, `cargo install`, `go install`, `npm install -g` or a binary in `~/.local/bin`, which come after Homebrew on the `PATH`, and apps in `~/Applications`. Add keepers to the `Brewfile`.

Per-Mac settings, such as private aliases, go in `~/.zshrc.local`, which isn't in the repo.
