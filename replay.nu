# Updates `$env` to match the environment resulting from running the given
# command in `bash`.
#
# Example:
#   > replay (ssh-agent)
export def --env main [
  ...command: string  # The bash command or script to execute
] {
  let new_env = play-internal ($command | str join ' ')

  # We can't call `load-env` in `if` or `else` and `return` must be the last
  # command we execute so we must make sure to execute everything at the top
  # level of the function.
  let exit_code = if ($new_env | describe) == 'int' { $new_env } else { 0 }
  let new_env = if ($new_env | describe) == 'int' { {} } else { $new_env }

  $new_env | load-env

  return $exit_code
}

# Executes the given command in `bash` and returns a record similar to `$env`
# corresponding to the environment in `bash` at the end of its execution.
export def play [
  ...command: string  # The bash command or script to execute
] {
  let new_env = play-internal ($command | str join ' ')

  if ($new_env | describe) == 'int' {
    return $new_env
  } else {
    $new_env
  }
}

# Returns a subset of `new_env` where entries already in `$env` are filtered
# out.
export def diff [
  new_env: any,  # An `$env`-like record
] {
  let raw_env = (env | select name raw | transpose -r | first)

  $new_env
  | transpose key value
  | where key not-in $raw_env or value != ($raw_env | get $it.key)
  | transpose -r
  | first
  | reject _ SHLVL
}

# Actual implementation of `play` which returns the exit code of the command
# in case of failure, or the described record otherwise.
def play-internal [$command: string] {
  let pipe_name = (^mktemp --tmpdir --dry-run 'replay-nu-XXXXXXXXXX' | str trim)

  ^bash -c $"
    ($command)

    env > ($pipe_name)
  "

  let exit_code = $env.LAST_EXIT_CODE

  if $exit_code == 0 {
    open --raw $pipe_name | lines | parse '{key}={value}' | transpose -r | first
  } else {
    $exit_code
  }
}

# Returns from the given function with the given exit code. Due to how Nushell
# works, must be called as the last command in a function.
def return [exit_code: int] {
  ^bash -c $"exit ($exit_code)"
}
