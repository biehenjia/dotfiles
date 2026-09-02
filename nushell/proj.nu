# proj.nu — brew-like ergonomics for per-project nix devshells under ~/+.
#
# `proj init <name> [...packages]`  scaffold ~/+/<name>: .envrc, flake.nix,
#                                    .gitignore. Packages are plain nixpkgs
#                                    attribute names, or none for a bare
#                                    devshell to edit by hand later.
# `proj list`                       show the current directory's devshell
#                                    packages.
# `proj add <pkg>`                  append a package to flake.nix and
#                                    `direnv reload`.
# `proj remove <pkg>`                remove a package and `direnv reload`.
#
# add/remove/list all just text-edit the current directory's flake.nix —
# nix does the real work, this only saves hand-editing the packages list.
# They only understand the exact shape `proj init` generates, not arbitrary
# hand-written flakes.

def flake-path [] {
    let path = ($env.PWD | path join "flake.nix")
    if not ($path | path exists) {
        error make { msg: "no flake.nix in the current directory" }
    }
    $path
}

def read-packages [] {
    let content = (open (flake-path))
    let after_start = ($content | split row 'packages = with nixpkgs.legacyPackages.${system}; [' | get 1)
    let block = ($after_start | split row '        ];' | get 0)
    $block | lines | each { |l| $l | str trim } | where { |l| ($l | is-not-empty) }
}

export def "proj init" [name: string, ...packages: string] {
    let dir = $"($env.HOME)/+/($name)"

    if ($dir | path exists) {
        error make { msg: $"($dir) already exists" }
    }

    mkdir $dir

    let envrc = r#'export HOME="$PWD/.home"
mkdir -p "$HOME"
use flake
'#
    $envrc | save $"($dir)/.envrc"

    let flake_prefix = r#'{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let system = "aarch64-darwin"; in
    {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
'#
    let flake_suffix = r#'        ];

        # Optional, per-project: a plain Homebrew Brewfile for anything not
        # worth pinning through nix. Fully opt-in — no-ops if it's absent.
        shellHook = ''
          if [ -f "$PWD/Brewfile" ]; then
            brew bundle install --file="$PWD/Brewfile" --no-upgrade
          fi
        '';
      };
    };
}
'#
    let pkg_block = ($packages | each { |p| $"          ($p)\n" } | str join "")
    ($flake_prefix + $pkg_block + $flake_suffix) | save $"($dir)/flake.nix"

    let gitignore = r#'.direnv/
.home/
'#
    $gitignore | save $"($dir)/.gitignore"

    print $"Created ($dir)"
}

export def "proj list" [] {
    print (read-packages)
}

export def "proj add" [pkg: string] {
    let path = (flake-path)
    let content = (open $path)
    let existing = (read-packages)

    if $pkg in $existing {
        print $"($pkg) is already in this devshell"
        return
    }

    let anchor = "        ];"
    let new_content = ($content | str replace $anchor $"          ($pkg)\n($anchor)")
    $new_content | save -f $path
    if (which direnv | is-not-empty) {
        print $"Added ($pkg) — reloading"
        ^direnv reload
    } else {
        print $"Added ($pkg)"
    }
}

export def "proj remove" [pkg: string] {
    let path = (flake-path)
    let content = (open $path)
    let line = $"          ($pkg)\n"

    if not ($content | str contains $line) {
        print $"($pkg) is not in this devshell"
        return
    }

    ($content | str replace $line "") | save -f $path
    if (which direnv | is-not-empty) {
        print $"Removed ($pkg) — reloading"
        ^direnv reload
    } else {
        print $"Removed ($pkg)"
    }
}
