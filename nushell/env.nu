let brew_prefix = "/opt/homebrew"
let prepend = [
  $"($brew_prefix)/bin"
  $"($brew_prefix)/sbin"
]

let extra = [
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "~/.local/bin"
  "~/.cargo/bin"
]

let current = (
  if (($env.PATH | describe) =~ 'list') {
    $env.PATH
  } else {
    $env.PATH | split row (char esep)
  }
)

$env.PATH = (
  ($prepend | each { |p| $p | path expand })
  | append ($current | each { |p| $p | path expand })
  | append ($extra | each { |p| $p | path expand })
  | uniq
)
