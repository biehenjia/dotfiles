
export-env { 
    $env.OBSIDIAN_MDS = "~/obsidian/biehenjia/**/*.md"
}



export def tasks [
  --closed
  --only-closed
] {
  if ($closed and $only_closed) {
    error make { msg: "Use at most one of --closed or --only-closed" }
  }

  let files = (glob $env.OBSIDIAN_MDS)
  let prefix = '^\s*(?:[-*]|\d+\.)\s+'
let open_re = $'($prefix)\[\s\]'
let closed_re = $'($prefix)\[[xX]\]'

def parse_rg [status: string] {
  | to text
  | lines
  | where ($it | str length) > 0
  | parse "{path}:{line}:{task}"
  | update line { into int }
  | insert status $status
  | update task { str replace -r '^\s*(?:[-*]|\d+\.)\s+\[(?: |x|X)\]\s*' '' }
  | insert priority { |row|
      if ($row.task | str contains '[priority::') {
        ($row.task | str replace -r '^.*\[priority::(\d+)\].*$' '$1' | into int)
      } else { null }
    }
  | insert time { |row|
      if ($row.task | str contains '[time::') {
        ($row.task | str replace -r '^.*\[time::(\d+)\].*$' '$1' | into int)
      } else { null }
    }
  | update task { str replace -r '\s*\[priority::\d+\]' '' }
  | update task { str replace -r '\s*\[time::\d+\]' '' }
  | sort-by priority time
  | select path line status priority time task
}

  if $only_closed {
    ^rg --line-number --no-heading $closed_re ...$files | parse_rg "closed"
  } else if $closed {
    let open_tbl = (^rg --line-number --no-heading $open_re ...$files | parse_rg "open")
    let closed_tbl = (^rg --line-number --no-heading $closed_re ...$files | parse_rg "closed")
    $open_tbl | append $closed_tbl | sort-by path line
  } else {
    ^rg --line-number --no-heading $open_re ...$files | parse_rg "open"
  }
}


export def task_completions [] {
  tasks
  | each { |row|
      {
        value: $"($row.path):($row.line)"
        description: $row.task
      }
    }
}

export def task [
  sel: string@task_completions
] {
  let row = (
    tasks
    | where { |r| $"($r.path):($r.line)" == $sel }
    | first
  )

  $row.task
}