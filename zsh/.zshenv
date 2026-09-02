# ~/.zshenv — the one dotfile that has to live at $HOME.
#
# zsh always reads $HOME/.zshenv first (ZDOTDIR isn't consulted for this file),
# so this is where the XDG base dirs and ZDOTDIR get established. Everything
# after this — .zprofile, .zshrc, .zlogin — is loaded from $ZDOTDIR instead of
# $HOME, which is how the rest of zsh's config stays out of the home directory.
#
# This duplicates what the launchd agent (launchd/com.biehenjia.xdg.plist) sets
# for GUI apps. Both are needed: the agent covers Dock-launched processes that
# never source a shell; this covers every zsh, including the non-interactive and
# pre-first-login ones the agent hasn't reached yet.

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
