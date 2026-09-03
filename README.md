# dotfiles

[![check](https://github.com/biehenjia/dotfiles/actions/workflows/check.yml/badge.svg)](https://github.com/biehenjia/dotfiles/actions/workflows/check.yml)

Personal macOS (Apple Silicon) config. [nushell](https://www.nushell.sh/) under
[ghostty](https://ghostty.org/) is the day-to-day shell; zsh is kept in sync for
the occasional bare `zsh`.

Everything is XDG-clean: the only file that has to live in `$HOME` is
`~/.zshenv`, which establishes the XDG base dirs and `ZDOTDIR`. A launchd agent
(`launchd/com.biehenjia.xdg.plist`) mirrors that environment for GUI-launched
apps that never source a shell.

## Layout

| Path | |
|---|---|
| `nushell/` | config, env, `starship.nu` integration, `xin.nu` (per-project nix devshells) |
| `starship/` | prompt — earthy powerline palette, quiet right prompt |
| `zsh/` | `.zshenv` (XDG bootstrap) + interactive `.zshrc` |
| `direnv/` | `direnvrc` (nix-direnv) + `direnv.toml` |
| `templates/devshell/` | `nix flake init -t` template: `packages.nix` + direnv HOME sandbox |
| `launchd/` | XDG env agent for GUI apps |
| `ghostty/`, `micro/` | terminal + TUI editor config |
| `zed/` | GUI editor — `settings.json` + `keymap.json`, Gruvbox earthy theme |
| `broot/` | `broot` tree browser — `conf.hjson`, `verbs.hjson`, transparent `earthy` skin |

## Install

Clone to **`~/dotfiles`** — the path is hardcoded in a few places
(`nushell/config.nu` `use` lines, the devshell template's `.envrc`) — then
symlink individual config files into `~/.config/<tool>/`.

Zed is the one GUI tool: `brew install --cask zed`, then

```sh
mkdir -p ~/.config/zed
ln -sfn ~/dotfiles/zed/settings.json ~/.config/zed/settings.json
ln -sfn ~/dotfiles/zed/keymap.json   ~/.config/zed/keymap.json
```

Launch it once from the Dock (or run `zed` from outside a devshell) so a normal
instance is running — after that `zed .` opens folders in it. Starting the very
first Zed with `zed .` from inside an `xin` devshell would hand it the
`HOME=$PWD/.home` sandbox and an empty config.

## CI

`.github/workflows/check.yml`: `nu-check` every nushell script, `plutil -lint`
the launchd plists, and `nix flake check` the root flake and the devshell
template.
