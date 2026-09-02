# proj.nu — brew-like ergonomics for per-project nix devshells.
#
# `proj init [...packages]`  like `git init` — scaffolds a devshell into the
#                            *current* directory from the template at
#                            ~/dotfiles/templates/devshell (flake.nix,
#                            packages.nix, .envrc, .gitignore), seeds it with
#                            any packages given, and runs `direnv allow`.
# `proj list`                show the current devshell's packages.
# `proj add <pkg>`           append a package and `direnv reload`.
# `proj remove <pkg>`        remove a package and `direnv reload`.
#
# add/remove/list only ever touch packages.nix — a flat Nix list this command
# owns end to end. flake.nix is copied once by the template and never edited
# again, so there is no fragile flake parsing to break.

def template-ref [] {
    $"($env.HOME)/dotfiles#devshell"
}

def packages-path [] {
    let path = ($env.PWD | path join "packages.nix")
    if not ($path | path exists) {
        error make { msg: "no packages.nix in the current directory (run `proj init`)" }
    }
    $path
}

# Lines between the `[` and `]` of packages.nix, comments and blanks dropped.
def read-packages [] {
    let content = (open --raw (packages-path))
    let inner = ($content | split row '[' | last | split row ']' | first)
    $inner
    | lines
    | each { str trim }
    | where { |l| ($l | is-not-empty) and (not ($l | str starts-with '#')) }
}

# Edit packages.nix only — no reload. Returns true if it changed the file.
def add-package [pkg: string]: nothing -> bool {
    let path = (packages-path)
    if $pkg in (read-packages) {
        return false
    }
    let content = (open --raw $path)
    # Sole `]` in the file is the list's closing bracket.
    $content | str replace ']' $"  ($pkg)\n]" | save -f $path
    true
}

def remove-package [pkg: string]: nothing -> bool {
    let path = (packages-path)
    let content = (open --raw $path)
    let line = $"  ($pkg)\n"
    if not ($content | str contains $line) {
        return false
    }
    $content | str replace $line '' | save -f $path
    true
}

def reload-or-note [msg: string] {
    if (which direnv | is-not-empty) {
        print $"($msg) — reloading"
        ^direnv reload
    } else {
        print $msg
    }
}

export def "proj init" [...packages: string] {
    let dir = $env.PWD

    for f in ["flake.nix" ".envrc"] {
        if (($dir | path join $f) | path exists) {
            error make { msg: $"($dir) already has a ($f)" }
        }
    }

    ^nix flake init -t (template-ref)

    for pkg in $packages {
        add-package $pkg | ignore
    }

    if (which direnv | is-not-empty) {
        ^direnv allow
    }

    print $"Initialized devshell in ($dir)"
    if ($packages | is-not-empty) {
        print $"  packages: ($packages | str join ', ')"
    }
}

export def "proj list" [] {
    read-packages
}

export def "proj add" [pkg: string] {
    if (add-package $pkg) {
        reload-or-note $"Added ($pkg)"
    } else {
        print $"($pkg) is already in this devshell"
    }
}

export def "proj remove" [pkg: string] {
    if (remove-package $pkg) {
        reload-or-note $"Removed ($pkg)"
    } else {
        print $"($pkg) is not in this devshell"
    }
}
