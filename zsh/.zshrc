# ~/.config/zsh/.zshrc — interactive zsh.
#
# nushell (via ghostty) is the day-to-day shell; this exists so the occasional
# bare `zsh` — Terminal.app, an IDE terminal, a script that drops to a shell —
# behaves consistently and leaves nothing in $HOME.

# Homebrew on Apple Silicon.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Nix (the Determinate installer only wires this into /etc/zshrc for the system
# zsh; re-doing it here is harmless and covers a non-standard $ZDOTDIR).
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# History out of $HOME, under XDG_STATE_HOME.
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
mkdir -p "${HISTFILE:h}"
setopt hist_ignore_dups share_history

# macOS's /etc/zshrc_Apple_Terminal writes ~/.zsh_sessions; opt out.
export SHELL_SESSIONS_DISABLE=1

command -v starship >/dev/null && eval "$(starship init zsh)"
command -v direnv   >/dev/null && eval "$(direnv hook zsh)"
