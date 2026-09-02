use ~/dotfiles/nushell/starship.nu
use ~/dotfiles/nushell/proj.nu *

$env.config = {
    show_banner: false
    hooks: {
        env_change: {
            PWD: [{ ||
                if (which direnv | is-empty) {
                    return
                }

                direnv export json | from json | default {} | load-env
            }]
        }
    }
}

# `cd +` itself isn't possible — nushell's builtin `cd` can't be overridden
# (a platform limitation, not a choice; PWD can only be changed by the real
# `cd`). This is the closest equivalent: bare `+` jumps to ~/+, same as `~`
# jumps home.
def --env "+" [] {
    cd ~/+
}
