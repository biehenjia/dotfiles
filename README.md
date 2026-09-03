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
| `ghostty/`, `micro/` | terminal + editor config |

## Install

Clone to **`~/dotfiles`** — the path is hardcoded in a few places
(`nushell/config.nu` `use` lines, the devshell template's `.envrc`) — then
symlink individual config files into `~/.config/<tool>/`.

## CI

`.github/workflows/check.yml`: `nu-check` every nushell script, `plutil -lint`
the launchd plists, and `nix flake check` the root flake and the devshell
template.
