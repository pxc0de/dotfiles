# dotfiles

Packages, apps, dotfiles and system defaults for my Macs. It works on Apple Silicon and Intel.

The Mac has two accounts. The admin account owns Homebrew and the apps and holds personal data such as the Apple ID, passwords and cards. A standard dev account, mine is `pxc0de`, is where code and agents run. From there they can use every installed tool but cannot replace it or read the admin's files.

## New Mac

1. In Setup Assistant, create the admin account and sign in to your Apple ID there.
2. As admin, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | bash
   ```

   It asks for the admin password, then for a name and password for the dev account, then the admin password again so the dev account can unlock FileVault. The rest runs unattended. It installs Homebrew and everything in the `Brewfile`, creates the dev account as a standard user, and applies `macos.sh`.

   To skip the name prompt, pass it in front of `bash`:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/dotfiles/main/setup.sh | DEV_USER=alice bash
   ```

3. Log in to the dev account and run the same command. It opens GitHub in the browser to log in `gh`, and asks for a new SSH key passphrase, which Keychain remembers. Then it links the dotfiles, installs the Rust toolchain, and installs the tmux and Neovim plugins.
4. Restart.

Do not sign the dev account in to your personal Apple ID or Google account, because they sync saved passwords and cards.

## Day to day

| Account | Command | What it does |
|---|---|---|
| admin | `cd ~/dotfiles && git pull && ./setup.sh` | Installs anything new in the `Brewfile` and upgrades every package and app. |
| dev | `./setup.sh` | Relinks dotfiles and updates the Rust toolchain and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed. |

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
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program, linked into the dev account's home. |

`dotfiles/npm/.npmrc` turns off npm install scripts, the usual entry point for supply-chain attacks. Allow them for one install with `npm install --ignore-scripts=false`.

Machine-local shell settings, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
