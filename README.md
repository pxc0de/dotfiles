# dotfiles

One command sets up a Mac for coding: tools, apps, editor, terminal and system settings. Works on Apple Silicon and Intel.

Each Mac has one account, the administrator created in Setup Assistant, and one of two roles:

| Role | Mac | Runs | GitHub access | SSH |
|---|---|---|---|---|
| `dev` | iMac | Always-on AI agents | A fine-grained token, limited to the repos you choose | Accepts logins from the personal Mac |
| `personal` | Laptop | Your personal data | Your account's SSH key | Connects to the dev Mac, accepts nothing |

Agents on the dev Mac run as you, so treat it as the Mac that could be compromised. Nothing on it can sign in to the personal Mac, reach it over Tailscale, or manage your GitHub account's keys. It still reaches the internet as normal.

The setup is safe to rerun. It updates its copy of this repo and skips whatever is already done. A yellow `warning:` line means one step failed and the rest still ran.

## New Mac

### 1. GitHub token (dev Mac only)

On any device, open [Settings > Developer settings > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new) and create a token:

| Field | Value |
|---|---|
| Expiration | 90 days |
| Repository access | Only select repositories: the ones agents work in, plus `dotfiles` |
| Contents | Read and write |
| Pull requests | Read and write |
| Workflows | Read and write, only if agents edit `.github/workflows` |

Leave everything else at No access. Keep the token until the setup asks for it.

In each of those repos, add a ruleset under Settings > Rules that requires a pull request before merging to `main`, so agents can't push to it directly.

### 2. Setup

1. In Setup Assistant, create your account, sign in to your Apple ID and leave FileVault on.
2. In Terminal, run the command for this Mac's role:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | ROLE=dev bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | ROLE=personal bash
   ```

   It asks for `Password:` (your account password). Homebrew asks for it again before apps with an installer, such as Tailscale. Without `ROLE`, it asks for the role. The role is saved in `~/.config/dotfiles/role`, so later runs don't need it.

   On both Macs, it installs the Xcode Command Line Tools, Homebrew and the `Brewfile`, makes SSH keys-only and turns on the firewall. The firewall blocks other devices from reaching servers you run, such as `npm run dev`; share one with `tailscale serve` instead. If macOS asks whether to accept incoming connections, choose Deny. It then links the dotfiles, installs the Rust toolchain and the tmux and Neovim plugins, and applies `macos.sh`.

   On the dev Mac, it asks for the token, which `gh` and `git` both use. It keeps the Mac awake and turns it back on after a power failure.

   On the personal Mac, it signs in to GitHub with a one-time code in Safari, then asks for passphrases for two new SSH keys, one for GitHub and one for the dev Mac, which Keychain remembers.
3. Restart the Mac.

### 3. Check it

In Ghostty, on both Macs:

| Command | Expected |
|---|---|
| `which nvim node python cargo claude` | All under `/opt/homebrew`, or `/usr/local` on Intel |
| `npm config get ignore-scripts` | `true` |
| `ls -ld ~` | Starts with `drwx------` |
| `brew bundle check --file ~/dotfiles/Brewfile` | `The Brewfile's dependencies are satisfied.` |
| `sudo fdesetup list` | Your account |
| `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | `Firewall is enabled` |

On the dev Mac:

| Command | Expected |
|---|---|
| `gh auth status` | `Logged in to github.com` |
| `git -C ~/dotfiles remote get-url origin` | Starts with `https://github.com/` |
| `pmset -g \| grep -E '^ *(sleep\|autorestart)'` | `sleep 0` and `autorestart 1` |
| `ls ~/.ssh` | No `id_ed25519` or `mac` |

On the personal Mac:

| Command | Expected |
|---|---|
| `ssh -T git@github.com` | `Hi <github-user>! You've successfully authenticated` |
| `git -C ~/dotfiles remote get-url origin` | Starts with `git@github.com:` |

### Token renewal

When the token expires, `gh auth status` on the dev Mac fails. Create a new token as above and rerun the setup, which asks for it.

## SSH from the personal Mac to the dev Mac

The personal Mac reaches the dev Mac over [Tailscale](https://tailscale.com), by key only, from anywhere. Nothing reaches the personal Mac.

### 1. Tailscale

1. Sign in to Tailscale with one login, protected by two-factor, on both Macs.
2. In the [admin console](https://login.tailscale.com/admin), replace **Access controls** with `tailscale.json`. The console refuses to save if its tests fail.
3. Under **Machines**, tag the iMac `tag:dev`, the laptop `tag:personal` and your phone `tag:phone`. Untagged devices lose access. The phone reaches the dev Mac's web ports but not SSH. The dev Mac can't start a connection to any of them.

Don't add a `funnel` attribute to the policy. Without one, nothing on the dev Mac can share a port with the public internet.

To open a dev server from the other devices, keep it on localhost and share it over the tailnet, on the dev Mac:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg 3000   # https://<dev-mac>.<tailnet>.ts.net
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve reset       # stop sharing
```

The dev Mac's name under **Machines**, such as `my-imac`, is `<dev-mac>` below.

### 2. Remote Login

On the dev Mac, open System Settings > General > Sharing and turn on **Remote Login**. Under ⓘ, set **Allow access for** to Only these users, remove Administrators and add your account. Leave full disk access off.

On the personal Mac, leave Remote Login off.

### 3. Key

The setup made `~/.ssh/mac` on the personal Mac. There:

```bash
pbcopy < ~/.ssh/mac.pub
```

On the dev Mac:

```bash
pbpaste >> ~/.ssh/authorized_keys
```

If both Macs use the same Apple ID, the clipboard is shared. If pasting doesn't work, turn on Handoff and Bluetooth on both, or AirDrop `mac.pub` and run `cat ~/Downloads/mac.pub >> ~/.ssh/authorized_keys` on the dev Mac. Copy only the `.pub` file, and never add a key from the dev Mac to the personal Mac.

### 4. Connect

On the personal Mac:

```bash
echo 'MAC=<user>@<dev-mac>' >> ~/.zshrc.local
```

In a new shell, `mac` opens a shell on the dev Mac and `mac <command>` runs one command there.

```bash
mac                          # open a shell
mac whoami                   # run one command
mac -t tmux new -A -s main   # attach to the main session, creating it if needed
mac -t tmux attach           # attach to the most recent session
mac -t tmux attach -t work   # attach to a named session
mac tmux ls                  # list sessions
```

tmux needs `-t`, which gives the command a terminal. Detach with `prefix d` and the session keeps running. Run agents inside tmux so they keep running after you disconnect.

### 5. Check it

From the personal Mac:

| Command | Expected |
|---|---|
| `mac whoami` | `<user>`, after you accept the host key the first time |
| `ssh -o PubkeyAuthentication=no <user>@<dev-mac>` | `Permission denied`, with no password prompt |

Never use `ssh -A`. It would let the dev Mac use your keys.

### After a restart

FileVault waits for your password at the login screen, and Tailscale may not run until you log in. Test a restart once: if you can't connect afterwards, the dev Mac needs someone at its keyboard each time it restarts.

## Updates

Run the setup again on each Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
```

It installs new `Brewfile` entries, upgrades everything, relinks the dotfiles and updates Rust and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed.

Nothing is uninstalled. A file in the way of a link moves to `.bak`.

## Forking

Change `REPO_URL` in `setup.sh`, the `curl` URLs here, your name and email in `dotfiles/git/.config/git/config`, and the `Brewfile`.

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Tools and apps. |
| `setup.sh` | The whole setup, for either role. |
| `macos.sh` | System settings, including a private home folder. |
| `tailscale.json` | Tailscale policy letting the personal Mac reach the dev Mac, with tests. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program. |

`dotfiles/npm/.npmrc` turns off npm install scripts. Allow them for one install with `npm install --ignore-scripts=false`.

To try a tool without adding it to the `Brewfile`, install it in your home folder: `uv tool install`, `cargo install`, `go install`, `npm install -g` or a binary in `~/.local/bin`, which come after Homebrew on the `PATH`, and apps in `~/Applications`. Add keepers to the `Brewfile`.

Per-Mac settings, such as private aliases, go in `~/.zshrc.local`, which isn't in the repo.
