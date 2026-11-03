# config

Packages, apps, dotfiles and system defaults for my Macs. It works on Apple Silicon and Intel.

The Mac has two accounts. `admin` owns Homebrew and the apps and holds personal data such as the Apple ID, passwords and cards. `pxc0de` is a standard account for development, so code and agents running there cannot change installed software or read the admin's files.

## New Mac

1. In Setup Assistant, create an account named `admin` and sign in to your Apple ID there.
2. As `admin`, run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/pxc0de/config/main/setup.sh | bash
   ```

   It asks for the admin password, then a password for the new `pxc0de` account, then the admin password again so `pxc0de` can unlock FileVault. The rest runs unattended. It installs Homebrew and everything in the `Brewfile`, creates `pxc0de` as a standard user, and applies `macos.sh`.
3. Log in as `pxc0de` and run the same command. It opens GitHub in the browser to log in `gh`, and asks for a new SSH key passphrase, which Keychain remembers. Then it links the dotfiles, installs the Rust toolchain, and installs the tmux and Neovim plugins.
4. Restart.

Do not sign `pxc0de` in to your personal Apple ID or Google account, because they sync saved passwords and cards.

## Day to day

| Account | Command | What it does |
|---|---|---|
| `admin` | `cd ~/config && git pull && ./setup.sh` | Installs anything new in the `Brewfile` and upgrades every package and app. |
| `pxc0de` | `./setup.sh` | Relinks dotfiles and updates the Rust toolchain and the tmux and Neovim plugins. Commit `lazy-lock.json` if it changed. |

Edit and push the repo from `pxc0de`. The `admin` copy only pulls. Neither command uninstalls anything.

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Every installed tool and app. Fonts install for all users. |
| `setup.sh` | The setup for whichever account runs it. |
| `macos.sh` | Per-user system preferences, including a home folder only its owner can open. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program, linked into `pxc0de`'s home. |

`dotfiles/npm/.npmrc` turns off npm install scripts, the usual entry point for supply-chain attacks. Allow them for one install with `npm install --ignore-scripts=false`.

Machine-local shell settings, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
