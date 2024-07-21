#!/bin/bash

getSourceDir() {
  local source=${BASH_SOURCE[0]}
  while [ -L "$source" ]; do # resolve $source until the file is no longer a symlink
    DIR=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    [[ $source != /* ]] && source=$DIR/$source # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  echo $( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
}

getCurentDirName() {
  local pathIn=$(pwd)
  local folders=(${pathIn//\// })
  local lastElementIndex=${#folders[@]}-1
  local currentFolderName=${folders[$lastElementIndex]}  
  echo $currentFolderName
}

GRAY='\033[0;90m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NOFORMAT='\033[0m'

CURRENT_DIR_NAME=$(getCurentDirName)
WORKTREE_DIR=~/.gwt/worktree
REMOVE_BRANCH=false
PROGRAM=$(basename "${BASH_SOURCE[0]}")
SOURCE_DIR=$(getSourceDir)

source $SOURCE_DIR/spinner.sh

version() {
  local VERSION=$(cat $SOURCE_DIR/VERSION)

  cat <<EOF
gwt version $VERSION
EOF

  exit 0
}

usage() {
  cat <<EOF
Script adds/removes a git worktree and the branch associated with the tree.

Usage:    $PROGRAM [OPTIONS]
          $PROGRAM COMMAND [OPTIONS] <worktree-path> 

Commands:
  add         Create and run a new container from an image
  remove      Remove one or more images

Available options:
  -h, --help                    Print this help
  -v, --version                 Print the version of the app
  -a                            Remove worktree with the branch
  -i                            Installation of dependencies of the newly created worktree

This script performs the following steps:
  1. Create a new worktree, based off the base branch (default: main)
  2. Install dependencies
EOF

  exit 0
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
  exit "$code"
}
diePrinthHelp() {
  local msg=$1
  local code=${2-1} # default exit status 1
  printNL "$msg"
  printNL "See '${PROGRAM} --help'."
  exit "$code"
}

runCommand() {
  local message=$1
  shift
  print "$message "
  "$@" &>/dev/null &
  spinner

  [[ $? -eq 0 ]] && success "Done." || error "FAILED."
}

removeWorktree() {
  local removeBranch=false

  case $1 in
    -a)
      removeBranch=true
      shift
      ;;
  esac
  
  local branch=$1

  local worktree=$(git worktree list | grep "\[${branch}\]" | awk '{print $1}')

  runCommand "Removing worktree: $worktree" git worktree remove $worktree

  [[ $removeBranch = true ]] && runCommand "Removing branch: $branch" git branch -D $branch

  exit 0
}

addWorktree() {
  local installDependencies=false

  case $1 in
    -i)
      installDependencies=true
      shift
      ;;
  esac

  local source=$1
  local branch=$2
  local worktree=$WORKTREE_DIR/$(getCurentDirName)_${source//[^A-Za-z0-9]/-}

  [[ -z $source ]] && die "Missing source brnach name";

  if [ ! -z $branch ]; then
    runCommand "Generating worktree: $worktree" git worktree add -b $branch $worktree $source
  else
    runCommand "Generating worktree ($worktree) from branch: $source" git worktree add $worktree $source
  fi

  if [ $installDependencies = true ]; then
    # msg "Moving into worktree: $worktree"
    cd $worktree
    runCommand "Installing dependencies" pnpm --silent install
  fi

  exit 0
}

parseParams() {
  while :; do
    case "${1-}" in
      list)
        msg "Existing worktrees with branches:"
        git worktree list
        exit 0
        ;;
      
      add)
        shift
        addWorktree $@
        ;;

      remove)
        shift
        removeWorktree $@
        ;;

      -h | --help) 
        usage
        ;;

      -v | --version)
        version
        ;;

      -?*)
        diePrinthHelp "Unknown or missing command/option: $1"
        ;;
  
      *) 
        diePrinthHelp "Missing command."
        ;;
    esac
    shift
  done

  return 0
}

parseParams $@

success "Success."
