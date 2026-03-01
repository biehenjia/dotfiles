

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

def "nu-complete-obsidian-task-paths" [] {
  let rows = (obsidian tasks format=csv | from csv)

  $rows
  | each {|r|
      let v = ($r | values)

      # need at least: col0, col1(task name), ..., colN-2(path), colN-1(line)
      if (($v | length) < 3) { return null }

      let task_name = ($v | get 1 | into string)
      let task_path = ($v | get (($v | length) - 2) | into string)

      if (($task_path | str length) == 0) { return null }

      { value: $task_path, description: $task_name }
    }
  | compact
  | uniq-by value
}

def "obs task" [
  task_path: string@nu-complete-obsidian-task-paths
] {
  $task_path
}