# dotfiles

Packages, apps, dotfiles and system defaults for my Macs. It works on Apple Silicon and Intel.

The Mac has two accounts. The admin account owns Homebrew and the apps and holds personal data such as the Apple ID, passwords and cards. A standard dev account is where code and agents run. From there they can use every installed tool but cannot replace it or read the admin's files.

## New Mac

1. In Setup Assistant, create the admin account and sign in to your Apple ID there.
2. As admin, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   It asks for the admin password, then for a name and password for the dev account, then the admin password again so the dev account can unlock FileVault. The rest runs unattended. It installs Homebrew and everything in the `Brewfile`, creates the dev account as a standard user, and applies `macos.sh`.

   To skip the name prompt, pass it in front of `bash`:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=<dev-name> bash
   ```

3. Log in to the dev account and run the same command. It opens GitHub in the browser to log in `gh`, and asks for a new SSH key passphrase, which Keychain remembers. Then it links the dotfiles, installs the Rust toolchain, and installs the tmux and Neovim plugins.
4. Restart.

Do not sign the dev account in to your personal Apple ID or Google account, because they sync saved passwords and cards.

## Agent host

One Mac can also run long-running agents in a third, standard account that has no GitHub access and no personal data. Other Macs reach it only over [Tailscale](https://tailscale.com), only by SSH key, and only as that account.

1. On the host, run the admin command with `AGENT_USER` as well:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=<dev-name> AGENT_USER=<agent-name> bash
   ```

   Besides the usual setup, it does the following:
   - creates the agent account and adds it to an `agents` group;
   - limits SSH to that group, with keys only.
2. Turn on Remote Login in System Settings > General > Sharing.
3. On the Mac you will connect from, create a key just for this host, and copy the public half:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/agent_host && cat ~/.ssh/agent_host.pub
   ```

4. On the host, log in to the agent account and run the setup command. Paste the public key when asked. It links only the shell, tmux and npm settings.
5. Open Tailscale on both Macs and sign in with the same account, protected by two-factor. In the Tailscale admin console, paste `tailscale.json` into Access controls. Then tag the host `tag:agent-host` and the other Mac `tag:laptop`. The policy allows SSH from `tag:laptop` to `tag:agent-host` and nothing else, so other devices on your tailnet lose access until you add rules for them.
6. Connect:

   ```bash
   ssh -i ~/.ssh/agent_host -t <agent-name>@<host> tmux new -A -s agents
   ```

   `<agent-name>` is the account from step 1 and `<host>` is the host's name on your tailnet. Never use `ssh -A`, which would let the host use your keys.

## Day to day

| Account | Command | What it does |
|---|---|---|
| admin | `cd ~/dotfiles && git pull && ./setup.sh` | Installs anything new in the `Brewfile` and upgrades every package and app. |
| dev | `./setup.sh` | Relinks dotfiles and updates the Rust toolchain and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed. |
| agent | `./setup.sh` | Relinks the shell, tmux and npm settings and updates the tmux plugins. |

On the agent host, pass `AGENT_USER` to the admin command again whenever the host settings change.

Edit and push the repo from the dev account. The admin copy only pulls. Neither command uninstalls anything, and once a standard account exists the admin run no longer asks for a name.

## Using it yourself

Fork the repo, then change these before running it:

| File | Change |
|---|---|
| `setup.sh` | `REPO_URL` on line 4, to your fork. |
| `README.md` | The `curl` URLs above. |
| `dotfiles/git/.config/git/config` | Your git name and email. |
| `Brewfile` | The tools and apps you want. |

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Every installed tool and app. Fonts install for all users. |
| `setup.sh` | The setup for whichever account runs it. |
| `macos.sh` | Per-user system preferences, including a home folder only its owner can open. |
| `tailscale.json` | The Tailscale access policy for the agent host, with tests that block edits opening more. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program, linked into the dev account's home. |

`dotfiles/npm/.npmrc` turns off npm install scripts, the usual entry point for supply-chain attacks. Allow them for one install with `npm install --ignore-scripts=false`.

Machine-local shell settings, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
