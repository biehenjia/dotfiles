
use ~/dotfiles/nushell/obs.nu

$env.config = {
    show_banner: false
}

def box [row: record] {
  let width   = ((term size).columns / 2 | into int)
  let inner   = ($width - 2)
  let top     = $"╭((0..($inner - 1) | each { '─' } | str join ''))╮"
  let bottom  = $"╰((0..($inner - 1) | each { '─' } | str join ''))╯"
  let divider = $"├((0..($inner - 1) | each { '─' } | str join ''))┤"

  let pad = { |text|
    let t      = ($text | into string)
    let len    = ($t | str length)
    let fill   = ($inner - $len - 1)
    let spaces = if $fill > 0 { 0..($fill - 1) | each { ' ' } | str join '' } else { '' }
    $"│ ($t)($spaces)│"
  }

  let wrap = { |text|
    let words = ($text | split row ' ')
    let wrapped = ($words | reduce -f {lines: [], current: ''} { |word, acc|
      let candidate = if ($acc.current | is-empty) { $word } else { $"($acc.current) ($word)" }
      if ($candidate | str length) > ($inner - 1) {
        {lines: ($acc.lines | append $acc.current), current: $word}
      } else {
        {lines: $acc.lines, current: $candidate}
      }
    })
    $wrapped.lines | append $wrapped.current | where { ($in | str length) > 0 }
  }

  let skip = [path line status title task]

  let field_lines = (
    $row
    | items { |k, v| {key: $k, val: $v} }
    | where { |f| $f.key not-in $skip and $f.val != null }
    | each { |f| do $pad $"($f.key | fill -a l -w 10): ($f.val)" }
  )

  let task_lines = (do $wrap $row.task | each { |line| do $pad $line })

  let title_section = if $row.title != null {
    [ (do $pad ($row.title | str upcase)), $divider ]
  } else { [] }

  [ $top ]
  | append $title_section
  | append $task_lines
  | append (if ($field_lines | is-empty) { [] } else { [ $divider ] | append $field_lines })
  | append $bottom
  | str join "\n"
}

def boxify [] {
  let rows = $in
  $rows | each { |row| box $row } | str join "\n"
}

def drop [] {
  let tbl = $in
  let empty_cols = ($tbl | columns | where { |c| $tbl | all { |r| ($r | get $c) == null } })
  if ($empty_cols | is-empty) { $tbl } else { $tbl | reject ...$empty_cols }
}

def today [offset?: int] {
  let d = (date now) + (if $offset != null { $offset * 1day } else { 0day })
  $d | format date '%Y-%m-%d'
}