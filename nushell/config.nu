use ~/dotfiles/nushell/starship.nu
use ~/dotfiles/nushell/proj.nu *

# Packages declared in a devshell's packages.nix — for the enter/exit
# mini-print. Mirrors proj.nu's read-packages but takes an explicit dir: the
# hook learns the devshell root from DIRENV_DIR, which isn't necessarily $PWD.
def devshell-packages [dir: string]: nothing -> list<string> {
    let path = ($dir | path join "packages.nix")
    if not ($path | path exists) { return [] }
    open --raw $path
    | split row '[' | last | split row ']' | first
    | lines
    | each { str trim }
    | where {|l| ($l | is-not-empty) and (not ($l | str starts-with '#')) }
}

# Merge, don't reassign: `use starship.nu` (line 1) has already run its
# export-env, which merges `render_right_prompt_on_last_line: true` into
# $env.config. A bare `$env.config = {...}` here would wipe that, and the
# right prompt would render on the first line (behind the powerline) instead
# of trailing the command on the last line.
$env.config = ($env.config | merge {
    show_banner: false
    hooks: {
        env_change: {
            PWD: [{ ||
                if (which direnv | is-empty) {
                    return
                }

                # Diff IN_NIX_SHELL (set by nix-direnv's `use flake`, the same
                # var the starship [nix_shell] module keys off) across the env
                # reload, so entering/leaving a devshell gets an explicit
                # mini-print — it matters here because devshells override HOME,
                # which silently breaks git until you `cd` back out. DIRENV_DIR
                # carries the devshell root ("-" marker + abs path); read it
                # before the reload so it's still there on the way out.
                let was_in = ($env.IN_NIX_SHELL? | is-not-empty)
                let prev_root = ($env.DIRENV_DIR? | default "" | str replace --regex '^-' '')
                direnv export json | from json | default {} | load-env
                let now_in = ($env.IN_NIX_SHELL? | is-not-empty)
                let now_root = ($env.DIRENV_DIR? | default "" | str replace --regex '^-' '')

                if $was_in and (not $now_in) {
                    print $"(ansi green_dimmed)  exited devshell · ($prev_root | path basename)(ansi reset)"
                } else if (not $was_in) and $now_in {
                    let pkgs = (devshell-packages $now_root)
                    let summary = (if ($pkgs | is-empty) { "no extra packages" } else { $pkgs | str join ', ' })
                    print $"(ansi green_dimmed)  entered devshell · ($now_root | path basename) · ($summary)(ansi reset)"
                }
            }]
        }
    }
})

# `cd +` itself isn't possible — nushell's builtin `cd` can't be overridden
# (a platform limitation, not a choice; PWD can only be changed by the real
# `cd`). This is the closest equivalent: bare `+` jumps to ~/+, same as `~`
# jumps home.
def --env "+" [] {
    cd ~/+
}
