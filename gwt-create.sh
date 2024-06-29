#!/bin/bash

printNL() { echo >&2 -e "${1-}"; }

getSourceDir() {
  local source=${BASH_SOURCE[0]}
  while [ -L "$source" ]; do # resolve $source until the file is no longer a symlink
    DIR=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    [[ $source != /* ]] && source=$DIR/$source # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  echo $( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
}

GREEN='\033[0;32m'
NOFORMAT='\033[0m'

GWT_DIR=`getSourceDir`

VERSION=$(cat $GWT_DIR/package.json | grep version | awk '{print $2}' | sed 's/[ ",]//g')
echo $VERSION > $GWT_DIR/src/VERSION

mkdir -p ~/.gwt && cp $GWT_DIR/src/* "$_"
sudo ln -sf ~/.gwt/gwt.sh /usr/local/bin/gwt

printNL "gwt script ready to use. ${GREEN}Done.${NOFORMAT}"
printNL "See 'gwt --help'."
