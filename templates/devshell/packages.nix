# Devshell packages — plain nixpkgs attribute names, one per line.
# Edited by `proj add` / `proj remove`; readable by `proj list`.
#
# `git` is seeded by default: the devshell rewrites PATH, so without it `git`
# is "command not found" inside the shell. `proj remove git` to drop it.
{ pkgs }:

with pkgs; [
  git
]
