#!/bin/bash

GRAY='\033[0;90m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NOFORMAT='\033[0m'

REMOVE_BRANCH=false
PROGRAM=$(basename "${BASH_SOURCE[0]}")

function spinner() {
  tput civis # cursor invisible

  # make sure we use non-unicode character type locale 
  # (that way it works for any locale as long as the font supports the characters)
  local LC_CTYPE=C

  local pid=$! # Process Id of the previous running command
  local spin='⣷⣯⣟⡿⢿⣻⣽⣾'
  local charwidth=3
  local i=0

  while kill -0 $pid 2>/dev/null; do
    local i=$(((i + charwidth) % ${#spin}))
    printf " \b${spin:$i:$charwidth}"
    printf >&2 "\b"
    sleep .1
  done

  tput cnorm # make cursor visible again

  wait $pid # capture exit code
  return $?
}

runCommand() {
  local message=$1
  shift
  print "$message "
  "$@" &>/dev/null &
  spinner

  [[ $? -eq 0 ]] && success "Done." || error "FAILED."
}

print() { echo >&2 -ne "${1-}"; }
printNL() { echo >&2 -e "${1-}"; }
msg() { printNL "${GRAY}${1-}${NOFORMAT}"; }
success() { msg "${GREEN}${1-}${NOFORMAT}"; }
error() { msg "${RED}${1-}${NOFORMAT}"; exit 1; }
die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  printNL "$msg"
  printNL "See '${PROGRAM} --help'."
  exit "$code"
}

usage() {
  cat <<EOF
Script adds/removes a git worktree and the branch associated with the tree.

Usage:  ${PROGRAM} [OPTIONS] COMMAND <worktree-path> 

Commands:
  add         Create and run a new container from an image
  remove      Remove one or more images

Available options:
  -h, --help                    Print this help and exit
  -b, --branch                  The branch to create
  -r, --remove                  Remove only worktree
  -rf, -fr                      Remove worktree and the branch

This script performs the following steps:
  1. Create a new worktree, based off the base branch (default: main)
  2. Install dependencies
EOF
  exit 0
}

restOfParams() {
  SOURCE='origin/main'
  WORKTREE=("$@")

  # check if worktree params exist
  [[ -z "${WORKTREE}" ]] && die "Missing worktree path";

  return 0
}

removeWorktree() {
  local BRANCH=("$@")
  local WORKTREE=$(git worktree list | grep "\[${BRANCH}\]" | awk '{print $1}')

  runCommand "Removing worktree: $WORKTREE" git worktree remove $WORKTREE

  [[ "${REMOVE_BRANCH}" = true ]] && runCommand "Removing branch: $BRANCH" git branch -D $BRANCH

  exit 0
}

parseParams() {
  BRANCH=''

  while :; do
    case "${1-}" in
      -h | --help) 
        usage
        ;;

      -b | --branch)
        BRANCH=$2
        shift
        ;;

      -rf | -fr)
        shift
        REMOVE_BRANCH=true
        removeWorktree $@ 
        ;;

      -r | --remove)
        shift
        removeWorktree $@
        ;;

      -?*)
        die "Unknown or missing command/option: $1"
        ;;

      *) 
        break
        ;;
    esac
    shift
  done

  # die if branch is missing
  [[ -z "$BRANCH" ]] && die "Missing branch name";

  restOfParams $@

  return 0
}

parseParams $@

# check if branch already exists
if [ -n "$(git branch --list "$BRANCH")" ]; then
  runCommand "Generating worktree ($WORKTREE) from existing branch: $BRANCH" git worktree add $WORKTREE $BRANCH
else 
  runCommand "Generating worktree: $WORKTREE" git worktree add -b $BRANCH $WORKTREE $SOURCE
fi

msg "Moving into worktree: $WORKTREE"
cd $WORKTREE
runCommand "Installing dependencies" pnpm --silent install
success "Success."
