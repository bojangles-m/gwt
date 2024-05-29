#!/bin/bash

GREEN='\033[0;32m'
NOFORMAT='\033[0m'

printNL() { echo >&2 -e "${1-}"; }

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

mkdir -p ~/.gwt && cp $DIR/src/* "$_"
sudo ln -sf ~/.gwt/src/gwt.sh /usr/local/bin/gwt

printNL "gwt script ready to use. ${GREEN}Done.${NOFORMAT}"
printNL "See 'gwt --help'."
