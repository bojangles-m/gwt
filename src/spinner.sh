function spinner() {
  tput civis # cursor invisible

  # make sure we use non-unicode character type locale 
  # (that way it works for any locale as long as the font supports the characters)
  local LC_CTYPE=C

  local pid=$! # Process Id of the previous running command
  local spin='⣷⣯⣟⡿⢿⣻⣽⣾'
  local charwidth=3
  local i=0
  local delay=.1

  while kill -0 $pid 2>/dev/null; do
    local i=$(((i + charwidth) % ${#spin}))
    printf " \b${spin:$i:$charwidth}"
    printf >&2 "\b"
    sleep $delay
  done

  tput cnorm # make cursor visible again

  wait $pid # capture exit code
  return $?
}
