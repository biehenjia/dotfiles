

$env.config = {
    show_banner: false
}


def tree [dir: path = ., --level (-L): int = 2] {
  ^eza --tree -L $level $dir
}

# open some file with specified path
def obs [file: path] {
  let p = ($file | path expand)
  ^open $"obsidian://open?path=($p)"
}

$env.OBSIDIAN_VAULT = "~/obsidian/biehenjia"

# open THE vault
def vbs [rel: string@vbs-complete] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)
  let full = ($vault | path join $rel)
  ^open $"obsidian://open?path=($full)"
}

def vbs-complete [] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)

  # recursively match markdown files inside the vault
  glob $"($vault)/**/*.md"
  | each {|p| $p | path relative-to $vault }
  | sort
}


