# dotfiles

One command sets up a Mac for coding: tools, apps, editor, terminal and system settings. Works on Apple Silicon and Intel.

Each Mac has one account, the administrator created in Setup Assistant, and one of two roles:

| Role | Mac | Runs | GitHub access | SSH |
|---|---|---|---|---|
| `main` | Your laptop | You, and your personal data | Your account's SSH key | Connects to the headless Mac, accepts nothing |
| `headless` | An iMac or Mac mini | Always-on AI agents | A fine-grained token, limited to the repos you choose | Accepts logins from the main Mac |

Agents on the headless Mac run as you, so treat it as the Mac that could be compromised. Nothing on it can sign in to the main Mac, reach it over Tailscale, or manage your GitHub account's keys. It still reaches the internet as normal.

The setup is safe to rerun. It updates its copy of this repo and skips whatever is already done. A yellow `warning:` line means one step failed and the rest still ran.

## New Macs

Follow these steps in order. Set up the main Mac first: you use it to make the headless Mac's GitHub token and to log in to the headless Mac afterwards.

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

### 2. GitHub token for the headless Mac

On the main Mac, open [Settings > Developer settings > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new) and create a token:

| Field | Value |
|---|---|
| Expiration | 90 days |
| Repository access | Only select repositories: the ones agents work in, plus `dotfiles` |
| Contents | Read and write |
| Pull requests | Read and write |
| Workflows | Read and write, only if agents edit `.github/workflows` |

Leave everything else at No access. Copy the token and leave the page open: once both Macs use the same Apple ID, you can paste it on the headless Mac with Universal Clipboard. Don't save it in a file.

In each of those repos, add a ruleset under Settings > Rules that requires a pull request before merging to `main`, so agents can't push to it directly.

### 3. Headless Mac

1. In Setup Assistant, create your account, sign in to your Apple ID and leave FileVault on.
2. In Terminal, run the same command:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   Answer its questions:

   | Prompt | Answer |
   |---|---|
   | `Password:` | Your account password |
   | `Is this Mac main or headless?` | `headless` |
   | `Token:` | Paste the token from step 2. It doesn't show as you paste. |

   It installs and configures the same things as on the main Mac, without SSH keys. `gh` and `git` use the token instead. It also installs Ghostty's terminfo for SSH sessions from the main Mac, keeps the Mac awake and turns it back on after a power failure.
3. Restart the Mac.
4. Open Ghostty and check:

   | Command | Expected |
   |---|---|
   | `gh auth status` | `Logged in to github.com` |
   | `git -C ~/dotfiles remote get-url origin` | Starts with `https://github.com/` |
   | `pmset -g \| grep -E '^ *(sleep\|autorestart)'` | `sleep 0` and `autorestart 1` |
   | `ls -ld ~/.ssh` | Starts with `drwx------`, not `l` |
   | `ls ~/.ssh` | No `id_ed25519` or `mac` |
   | `id -un` | Your account name, which is `<user>` below |

   Then run the [checks for both Macs](#checks-for-both-macs).

### 4. Tailscale

1. Install [Tailscale](https://tailscale.com/download/mac) on both Macs, and on your phone if you want to open dev servers from it. Sign in on each with the same login, protected by two-factor.
2. On the main Mac, run `pbcopy < ~/dotfiles/tailscale.json`. In the [admin console](https://login.tailscale.com/admin/acls), select everything under **Access controls**, paste over it and save. The console refuses to save if the policy's tests fail.
3. Under [**Machines**](https://login.tailscale.com/admin/machines), open each device's ⋯ menu, choose **Edit ACL tags** and add one tag: `tag:main` for the main Mac, `tag:headless` for the headless Mac and `tag:phone` for your phone. Untagged devices lose access.
4. The headless Mac's name in that list, such as `my-imac`, is `<headless-mac>` below.

The main Mac can reach the headless Mac. The phone reaches the headless Mac's web ports but not SSH. The headless Mac can't start a connection to any of them. Don't add a `funnel` attribute to the policy: without one, nothing on the headless Mac can share a port with the public internet.

### 5. SSH from the main Mac to the headless Mac

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

## Token renewal

When the token expires, `gh auth status` on the headless Mac fails. Create a new token as in [step 2](#2-github-token-for-the-headless-mac), rerun the setup on the headless Mac and paste it when asked.

## Updates

Run the setup again on each Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

It asks for your password and offers the saved role from `~/.config/dotfiles/role`; press Return to keep it. It installs new `Brewfile` entries, upgrades everything, relinks the dotfiles and updates Rust and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed.

Nothing is uninstalled. A file in the way of a link moves to `.bak`.

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
