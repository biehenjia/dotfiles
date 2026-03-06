# obs.nu

export-env {
  $env.OBSIDIAN_VAULT = "~/obsidian/biehenjia"
  $env.OBSIDIAN_MDS = $"($env.OBSIDIAN_VAULT)/**/*.md"
}

def obs-vault-root [] {
  $env.OBSIDIAN_VAULT | path expand
}

def obs-files [] {
  glob $env.OBSIDIAN_MDS
}

def extract-inline-fields [text: string] {
  $text
  | parse -r '\[(?<key>[a-zA-Z0-9_-]+)::(?<val>[^\]]+)\]'
  | reduce -f {} { |it, acc|
      let raw = ($it.val | str trim)
      let value = (
        if ($raw =~ '^[0-9]+$') {
          $raw | into int
        } else {
          $raw
        }
      )
      $acc | upsert $it.key $value
    }
}

def strip-inline-fields [text: string] {
  $text
  | str replace -r '\s*\[[a-zA-Z0-9_-]+::[^\]]+\]' ''
  | str trim
}

def strip-task-marker [text: string] {
  $text
  | str replace -r '^\s*(?:[-*]|\d+\.)\s+\[(?: |x|X)\]\s*' ''
}

def parse-rg-lines [status: string, vault: string] {
  to text
  | lines
  | where ($it | str trim | is-not-empty)
  | parse "{path}:{line}:{task}"
  | update path { |row|
      $row.path
      | path expand
      | path relative-to $vault
    }
  | update line { into int }
  | insert status $status
  | update task { |row| strip-task-marker $row.task }
  | insert fields { |row| extract-inline-fields $row.task }
  | each { |row| $row | merge $row.fields }
  | reject fields
  | update task { |row| strip-inline-fields $row.task }
}

def sort-task-table [tbl: table, sort_by?: string] {
  if ($sort_by | is-empty) {
    $tbl | sort-by path line
  } else {
    $tbl
    | each { |row|
        let val = (
          if ($row | columns | any {|c| $c == $sort_by }) {
            $row | get $sort_by
          } else {
            null
          }
        )

        $row
        | upsert __sort_missing ($val == null)
        | upsert __sort_value $val
      }
    | sort-by __sort_missing __sort_value path line
    | reject __sort_missing __sort_value
  }
}

def "nu-complete obs-task-fields" [] {
  let files = (obs-files)
  let field_re = '\[(?<key>[a-zA-Z0-9_-]+)::(?<val>[^\]]+)\]'

  if ($files | is-empty) {
    []
  } else {
    ^rg --no-heading --only-matching $field_re ...$files
    | lines
    | parse -r $field_re
    | get key
    | uniq
    | sort
  }
}

export def tasks [
  sort_by?: string@"nu-complete obs-task-fields"
  --closed
  --only_closed
] {
  if ($closed and $only_closed) {
    error make { msg: "Use at most one of --closed or --only_closed" }
  }

  let files = (obs-files)
  let vault = (obs-vault-root)

  if ($files | is-empty) {
    []
  } else {
    let prefix = '^\s*(?:[-*]|\d+\.)\s+'
    let open_re = $'($prefix)\[\s\]'
    let closed_re = $'($prefix)\[[xX]\]'

    let tbl = (
      if $only_closed {
        ^rg --line-number --no-heading $closed_re ...$files | parse-rg-lines "closed" $vault
      } else if $closed {
        let open_tbl = (^rg --line-number --no-heading $open_re ...$files | parse-rg-lines "open" $vault)
        let closed_tbl = (^rg --line-number --no-heading $closed_re ...$files | parse-rg-lines "closed" $vault)
        $open_tbl | append $closed_tbl
      } else {
        ^rg --line-number --no-heading $open_re ...$files | parse-rg-lines "open" $vault
      }
    )

    sort-task-table $tbl $sort_by | place-column-after-line $sort_by
  }
}

export def task-completions [] {
  tasks
  | each { |row|
      {
        value: $"($row.path):($row.line)"
        description: $row.task
      }
    }
}

export def task [sel: string@task-completions] {
  let row = (
    tasks
    | where { |r| $"($r.path):($r.line)" == $sel }
    | first
  )

  $row.task
}

def place-column-after-line [col?] {
  let tbl = $in

  if ($col | is-empty) {
    $tbl
  } else {
    $tbl | each { |row|
      let cols = ($row | columns)

      if not ($cols | any {|c| $c == $col }) {
        $row
      } else {
        let rest_cols = (
          $cols | where {|c|
            $c != "path" and $c != "line" and $c != $col
          }
        )

        ($row | select path line)
        | merge ($row | select $col)
        | merge ($row | select ...$rest_cols)
      }
    }
  }
}