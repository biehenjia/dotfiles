# nushell utilities for obsidian.

export-env {
  $env.OBSIDIAN_VAULT = "~/obsidian/biehenjia"
  $env.OBSIDIAN_MDS = $"($env.OBSIDIAN_VAULT)/**/*.md"
}

def obs-vault-root [] { $env.OBSIDIAN_VAULT | path expand }
def obs-files [] {
  glob $env.OBSIDIAN_MDS
  | where { |p| not ($p =~ '(^|[/\\])\.trash([/\\]|$)') }
}

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



# Obsidian CLI utilities.
#
# Commands:
#   obs tasks        List all tasks in the vault
#   obs todo         Show upcoming unfinished tasks
#   obs task         Select a task interactively
#
# Examples:
#   obs
#   obs tasks priority
#   obs todo --count 5
export def main [] {
  help obs
}



export def toggle [] {
  let row = $in
  let file = (obs-vault-root | path join $row.path)
  let lines = (open --raw $file | lines)
  let idx = ($row.line - 1)
  let old = ($lines | get $idx)

  let obsidian_open = (
    ps | where { |p| $p.name =~ '(?i)obsidian' } | is-not-empty
  )

  let new = if $row.status == 0 {
    let checked = ($old | str replace -r '\[ \]' '[x]')
    if $obsidian_open {
      $checked
    } else {
      let date = (date now | format date '%Y-%m-%d')
      $checked | str replace -r '\s*$' $" [c::($date)]"
    }
  } else {
    $old
    | str replace -r '\[x\]|\[X\]' '[ ]'
    | str replace -r '\s*\[c::[^\]]+\]' ''
  }

  $lines | update $idx $new | str join "\n" | save --force $file
}

export def launch [] {
  let uri = $"obsidian://open?vault=($env.OBSIDIAN_VAULT | path basename | url encode)"
  ^open $uri
}


# ==== TRIAGE





def triage-wrap-text [text: string, width: int] {
  let words = ($text | split row ' ')
  mut lines = []
  mut current = ""
  for word in $words {
    let candidate = if ($current | str length) == 0 { $word } else { $"($current) ($word)" }
    if ($candidate | str length) > $width {
      if ($current | str length) > 0 { $lines = ($lines | append $current) }
      $current = $word
    } else {
      $current = $candidate
    }
  }
  if ($current | str length) > 0 { $lines = ($lines | append $current) }
  $lines
}

def triage-center [text: string, term_width: int] {
  let visible = ($text | ansi strip | str length)
  let lpad = (($term_width - $visible) / 2 | math floor)
  let p = if $lpad > 0 { " " | fill -w $lpad } else { "" }
  $"($p)($text)"
}

def triage-render-card [task: record, idx: int, total: int] {
  let term_width = (tput cols | into int)
  let card_width = 50
  let inner_width = ($card_width - 4)
  let left_pad = (($term_width - $card_width) / 2 | math floor)
  let pad = if $left_pad > 0 { " " | fill -w $left_pad } else { "" }

  let bar_width = $inner_width
  let filled = if $total > 0 { (($idx * $bar_width) / $total) | math floor } else { 0 }
  let bar = (
    (0..$filled | each { "#" } | str join "") +
    (0..($bar_width - $filled) | each { "-" } | str join "")
  )

  let hbar = (0..($card_width - 3) | each { "─" } | str join "")
  let border_top = $"($pad)(ansi attr_bold)╭($hbar)╮(ansi reset)"
  let border_bot = $"($pad)(ansi attr_bold)╰($hbar)╯(ansi reset)"

  def card-line [content: string] {
    let visible_len = ($content | ansi strip | str length)
    let pad_right = ($inner_width - $visible_len)
    let rpad = if $pad_right > 0 { " " | fill -w $pad_right } else { "" }
    $"($pad)│ ($content)($rpad) │"
  }

  let title_text = if ($task.title? | is-empty) { "task" } else { $task.title }
  let title_colored = $"(ansi yellow)($title_text)(ansi reset)"

  let wrapped_task = (triage-wrap-text $task.task $inner_width)

  let skip_cols = ["path" "line" "status" "title" "task"]
  let extra_fields = (
    $task
    | transpose key val
    | where { |r| $r.key not-in $skip_cols and ($r.val | is-not-empty) }
    | each { |r| $"(ansi cyan)($r.key)(ansi reset)=($r.val)" }
    | str join "  "
  )

  let path_text = $"(ansi dark_gray)($task.path):($task.line)(ansi reset)"
  let counter = $"  ($idx)/($total)"
  let progress_visible_len = $bar_width + ($counter | str length)
  let progress_lpad = (($term_width - $progress_visible_len) / 2 | math floor)
  let progress_pad = if $progress_lpad > 0 { " " | fill -w $progress_lpad } else { "" }
  let progress_colored = $"(ansi dark_gray)($bar)($counter)(ansi reset)"
  let hints = $"(ansi green)[x](ansi reset) done  (ansi blue)[d](ansi reset) delay  (ansi yellow)[p](ansi reset) pause  (ansi dark_gray)[s](ansi reset) skip  (ansi white)[b](ansi reset) back  (ansi magenta)[u](ansi reset) un-done  (ansi red)[q](ansi reset) quit"

  print ""
  print $border_top
  print (card-line $title_colored)
  print (card-line "")
  for line in $wrapped_task { print (card-line $line) }
  if ($extra_fields | str length) > 0 {
    print (card-line "")
    print (card-line $extra_fields)
  }
  print (card-line "")
  print (card-line $path_text)
  print $border_bot
  print ""
  print $"($progress_pad)($progress_colored)"
  print ""
  print (triage-center $hints $term_width)
  print ""
}

def triage-mark-undone [task: record] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)
  let file = ($vault | path join $task.path)
  let lines = (open --raw $file | lines)
  let idx = ($task.line - 1)
  let old = ($lines | get $idx)
  let new = (
    $old
    | str replace -r '\[x\]|\[X\]' '[ ]'
    | str replace -ra '\s*\[c::[^\]]+\]' ''
  )
  $lines | update $idx $new | str join "\n" | save --force $file
}

def triage-mark-done [task: record] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)
  let file = ($vault | path join $task.path)
  let lines = (open --raw $file | lines)
  let idx = ($task.line - 1)
  let old = ($lines | get $idx)
  let date = (date now | format date '%Y-%m-%d')
  let new = (
    $old
    | str replace -r '\[ \]' '[x]'
    | str replace -r '\s*$' $" [c::($date)]"
  )
  $lines | update $idx $new | str join "\n" | save --force $file
}

def triage-set-due [task: record, days: int] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)
  let file = ($vault | path join $task.path)
  let lines = (open --raw $file | lines)
  let idx = ($task.line - 1)
  let old = ($lines | get $idx)
  let due_date = ((date now) + ($days * 1day) | format date '%Y-%m-%d')
  let new = if ($old =~ '\[due::[^\]]+\]') {
    $old | str replace -r '\[due::[^\]]+\]' $"[due::($due_date)]"
  } else {
    $old | str replace -r '\s*$' $" [due::($due_date)]"
  }
  $lines | update $idx $new | str join "\n" | save --force $file
}

def triage-remove-due [task: record] {
  let vault = ($env.OBSIDIAN_VAULT | path expand)
  let file = ($vault | path join $task.path)
  let lines = (open --raw $file | lines)
  let idx = ($task.line - 1)
  let old = ($lines | get $idx)
  let new = ($old | str replace -ra '\s*\[due::[^\]]+\]' '')
  $lines | update $idx $new | str join "\n" | save --force $file
}

def triage-prompt-key [] {
  input --numchar 1 --suppress-output ""
}

def triage-prompt-days [term_width: int] {
  let prompt = $"(ansi blue)delay how many days?(ansi reset) "
  print -n (triage-center $prompt $term_width)
  let raw = (input "")
  $raw | str trim | into int
}

export def triage [] {
  let tasks = ($in | collect)
  let total = ($tasks | length)

  if $total == 0 {
    print $"(ansi yellow)no tasks to triage(ansi reset)"
    return
  }

  mut log = []
  mut i = 0

  while $i < $total {
    let task = ($tasks | get $i)
    let term_width = (tput cols | into int)
    clear
    triage-render-card $task ($i + 1) $total

    let key = (triage-prompt-key)

    match $key {
      "x" => {
        triage-mark-done $task
        $log = ($log | append {task: $task.task, action: "done", detail: ""})
        $i = $i + 1
      }
      "d" => {
        let days = (triage-prompt-days $term_width)
        if $days > 0 {
          triage-set-due $task $days
          $log = ($log | append {task: $task.task, action: "delay", detail: $"+($days)d"})
          $i = $i + 1
        }
      }
      "p" => {
        triage-remove-due $task
        $log = ($log | append {task: $task.task, action: "pause", detail: "due removed"})
        $i = $i + 1
      }
      "s" | " " => {
        $log = ($log | append {task: $task.task, action: "skip", detail: ""})
        $i = $i + 1
      }
      "b" => {
        if $i > 0 { $i = $i - 1 }
      }
      "u" => {
        triage-mark-undone $task
        $log = ($log | append {task: $task.task, action: "un-done", detail: ""})
      }
      "q" => {
        $i = $total
      }
      _ => {}
    }
  }

  clear
  print $"(ansi attr_bold)triage complete — ($log | length) actions(ansi reset)\n"

  if ($log | is-not-empty) {
    $log | table
  }

  print ""
}