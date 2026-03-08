# nushell utilities for obsidian.

export-env {
  $env.OBSIDIAN_VAULT = "~/obsidian/biehenjia"
  $env.OBSIDIAN_MDS = $"($env.OBSIDIAN_VAULT)/**/*.md"
}

def obs-vault-root [] { $env.OBSIDIAN_VAULT | path expand }
def obs-files []     { glob $env.OBSIDIAN_MDS }


def extract-inline-fields [text: string] {
  let pairs = (
    $text
    | parse -r '\[(?<key>[a-zA-Z0-9_-]+)::(?<val>[^\]]+)\]'
    | update val { str trim }
    | update val { |r| if ($r.val =~ '^[0-9]+$') { $r.val | into int } else { $r.val } }
  )
  if ($pairs | is-empty) { {} } else { $pairs | transpose -r -d }
}

def strip-inline-fields [text: string] {
  $text | str replace -ra '\s*\[[a-zA-Z0-9_-]+::[^\]]+\]' '' | str trim
}

def strip-task-marker [text: string] {
  $text | str replace -r '^\s*(?:[-*]|\d+\.)\s+\[(?: |x|X)\]\s*' ''
}


def "nu-complete obs-task-fields" [] {
  let files = (obs-files)
  if ($files | is-empty) { return [] }
  ^rg --no-heading --only-matching '\[[a-zA-Z0-9_-]+::[^\]]+\]' ...$files
  | lines
  | parse -r '\[(?<key>[a-zA-Z0-9_-]+)::'
  | get key | uniq | sort
}


export def tasks [
  sort_by?: string@"nu-complete obs-task-fields"
] {
  let files = (obs-files)
  if ($files | is-empty) { return [] }

  let vault = (obs-vault-root)

  let rows = (
    ^rg --line-number --no-heading '^\s*(?:[-*]|\d+\.)\s+\[[x X]\]' ...$files
    | lines
    | where { |ln| $ln | str trim | is-not-empty }
    | parse -r '^(?P<path>.*?):(?P<line>\d+):(?P<task>.+)$'
    | update path { |r| $r.path | path expand | path relative-to $vault }
    | update line { into int }
    | insert status { |row| if ($row.task =~ '\[x\]|\[X\]') { 1 } else { 0 } }
    | update task { strip-task-marker $in }
    | insert fields { |row| extract-inline-fields $row.task }
    | update task   { |row| strip-inline-fields $row.task }
    | insert title  { |row|
        let m = ($row.task | parse -r '^(?P<title>\w+):\s+(?P<rest>.+)$')
        if ($m | is-empty) { null } else { $m | first | get title }
      }
    | update task   { |row|
        let m = ($row.task | parse -r '^\w+:\s+(?P<rest>.+)$')
        if ($m | is-empty) { $row.task } else { $m | first | get rest }
      }
  )

  if ($rows | is-empty) { return [] }

  let field_keys = ($rows | get fields | each { columns } | flatten | uniq)

  let tbl = if ($field_keys | is-empty) {
    $rows | reject fields | select path line status title task
  } else {
    let pre  = ($field_keys | reduce -f $rows { |key, acc| $acc | default null $key })
    let flat = ($pre | each { |row| $row | reject fields | merge ($row.fields) })
    $flat | select path line status title task ...$field_keys
  }

  if ($sort_by | is-empty) {
    $tbl | sort-by path line
  } else {
    let has        = ($tbl | where { ($in | get $sort_by) != null })
    let missing    = ($tbl | where { ($in | get $sort_by) == null })
    let other_cols = ($tbl | columns | where { $in != $sort_by })
    ($has | sort-by { |r| $r | get $sort_by } | append $missing) | select $sort_by ...$other_cols
  }
}

def "nu-complete task-cols" [] {
  tasks | columns | each { |c| {value: $c} }
}


def "nu-complete task-completions" [context: string] {
  let parts = ($context | str trim | split row ' ')
  let col   = if ($parts | length) > 2 { $parts | get 1 } else { null }
  let tbl   = if $col != null and ($col in (tasks | columns)) {
    tasks
    | where { |r| ($r | get $col) != null }
    | sort-by { |r| $r | get $col }
  } else {
    tasks | sort-by path line
  }
  $tbl | each { |r| {
    value: $"($r.path):($r.line)",
    description: $r.task
  }}
}

export def task [
  col?: string@"nu-complete task-cols"  
  sel?: string@"nu-complete task-completions"
] {
  if ($sel | is-empty) { return null }
  tasks | where { |r| $"($r.path):($r.line)" == $sel } | first
}

export def todo [
  col?: string@"nu-complete task-cols"
  --count: int = 3
] {
  let tbl = if $col != null {
    tasks $col | where { |r| ($r | get $col) != null }
  } else {
    tasks
  }
  $tbl | where status == 0 | first $count | drop 
}