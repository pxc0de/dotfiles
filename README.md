# config

Packages, apps, dotfiles and system defaults for my Macs. It works on Apple Silicon and Intel.

## Setup

On a new Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/pxc0de/config/main/setup.sh | bash
```

This installs Homebrew and the Xcode Command Line Tools, clones the repo into `~/config`, and runs `./setup.sh`. Restart when it finishes.

After that, run `./setup.sh` whenever you pull changes or want upgrades. Each run does the following:

1. Installs anything new in the `Brewfile` and upgrades every package and app.
2. Links the dotfiles into `$HOME`, moving any conflicting file to `<file>.bak`.
3. Installs and updates the Rust toolchain, tmux plugins and Neovim plugins.
4. Applies the macOS defaults in `macos.sh`.

Commit `lazy-lock.json` afterwards if the Neovim plugins changed. The script never uninstalls anything.

## Layout

| Path | Contents |
|---|---|
| `Brewfile` | Every installed tool and app. Add a line and run `./setup.sh` to install it. |
| `setup.sh` | The setup and upgrade run described above. |
| `macos.sh` | System preferences. Some take effect only after a restart. |
| `dotfiles/` | One [GNU Stow](https://www.gnu.org/software/stow/) package per program. Each mirrors `$HOME` and is symlinked into it. |

To add a program's config, create `dotfiles/<program>/` with the same paths it has under `$HOME`, such as `dotfiles/myapp/.config/myapp/config.yml`. Then run `./setup.sh`.

Machine-local shell settings, such as private aliases and SSH hosts, go in `~/.zshrc.local`. That file is not in the repo.
