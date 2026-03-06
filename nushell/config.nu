
use ~/dotfiles/nushell/obs.nu

$env.config = {
    show_banner: false
}



# obs.nu (rg --json based)

export-env {
  if ($env.OBS_TASK_ROOT? | is-empty) {
    $env.OBS_TASK_ROOT = $env.PWD
  }
}

def obs-clean-task-text [s: string] {
  $s
  | str replace "- [ ] " ""
  | str replace "- [x] " ""
  | str replace "- [X] " ""
  | str replace -r '\s*\[[^\]]+::[^\]]+\]' ''
  | str replace -r '\s+' ' '
  | str trim
}

def obs-rg-tasks [] {
  ^rg --json --color never --glob "*.md" '^\s*-\s*\[[ xX]\]\s+' $env.OBSIDIAN_MDS
  | lines
  | each {|l| ($l | from json) }
  | where type == "match"
  | each {|m|
      let file = $m.data.path.text
      let line = ($m.data.line_number | into int)
      let raw = ($m.data.lines.text | str trim --right)


      let status = ($raw | str substring 3..4)

      {
        value: $"($file):($line)"
        description: (obs-clean-task-text $raw)
        status: $status
        file: $file
        line: $line
      }
    }
}

def obs-open-tasks-table [] {
  obs-rg-tasks
  | where {|t| ($t.status != "x") and ($t.status != "X") }
  | sort-by value
}

def "nu-complete obs task open" [] {
  obs-open-tasks-table | select value description
}

export def "obs task open" [
  loc?: string@"nu-complete obs task open"
] {
  if $loc == null {
    obs-open-tasks-table | select value description status
  } else {
    obs-open-tasks-table | where value == $loc | first
  }
}